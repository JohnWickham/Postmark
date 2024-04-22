import Foundation
import ArgumentParser
import FileMonitor

@main
struct Postmark: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "A lightweight CMS for publishing Markdown-based hypertext.", subcommands: [Regenerate.self, Watch.self])
}

struct Watch: ParsableCommand {
    
    static var configuration = CommandConfiguration(abstract: "Watch a given directory for changes and automatically generate static content and update database entries as appropriate.")
    
    @Argument(help: "The directory to monitor for changes in. Defaults to the current directory.", transform: { string in
        return URL(filePath: string, directoryHint: .inferFromPath, relativeTo: .currentDirectory())
    })
    private var contentDirectoryURL: URL = URL(filePath: FileManager.default.currentDirectoryPath)
    
    @Option(name: [.customLong("db"), .long], help: "The path to the database file.")
    var databaseFile: String = "store.sqlite"
    
    @Option(name: [.short, .customLong("fragments")], help: "Generate HTML fragments for posts, instead of fully-formed HTML documents.")
    var generateFragments: Bool = false
  
    public func run() {
        let databaseFileURL = URL(fileURLWithPath: databaseFile, relativeTo: URL(string: FileManager.default.currentDirectoryPath))
      
        do {
            try DataStore.shared.open(databaseFile: databaseFileURL)
            let monitor = try FileMonitor(directory: contentDirectoryURL, delegate: self, options: nil)
            try monitor.start()
            Log.shared.info("Postmark is watching for changes in \(contentDirectoryURL)")
        }
        catch {
            Postmark.exit(withError: error)
        }
        
        RunLoop.main.run()
    }
    
}

extension Watch: FileDidChangeDelegate {
    
    func fileDidChange(event: FileChange) {
        let fileHelper = PostFilesHelper(contentDirectoryURL: contentDirectoryURL)
        
        Log.shared.trace("File event: \(event.description)")
        
        // TODO: If an added or modified Markdown file is an "orphan" (direct child of the content directory without a containing post folder), create a post folder and move the file into it.
        
        switch event {
        case .created(file: let file, isDirectory: let isDirectory),
             .modified(file: let file, isDirectory: let isDirectory):
            
            return;
            
            let fileURL = URL(fileURLWithPath: file.absoluteString).standardizedFileURL
            
            do {
                let isPostFolder = try fileHelper.isPostFolder(fileURL)
                let isPostSourceFile = try fileHelper.isPostSourceContentFile(fileURL: fileURL)
                
                guard isPostFolder || isPostSourceFile else {
                    Log.shared.trace("A file was added or changed, but it wasn't a post folder or post source file.")
                    return
                }
                
                Log.shared.trace("Post folder or post source content file was added or changed.")
                
                if let postDirectory = isPostFolder ? fileURL : fileHelper.getContainingDirectory(for: fileURL) {
                    let options: PostProcessingQueue.ProcessingOptions = generateFragments ? [.generateFragments] : []
                    let processingQueue = try PostProcessingQueue(postDirectory: postDirectory, in: contentDirectoryURL, options: options)
                    try processingQueue.process()
                }
            }
            catch {
                Log.shared.error("A file was added or changed, but an error occurred evalutating whether it was a post folder or post source content file: \(error.localizedDescription). Nothing will be done about this change.")
                return
            }
            
        case .removed(file: let file, isDirectory: let isDirectory):
            
            let fileURL = URL(fileURLWithPath: file.absoluteString).standardizedFileURL
            
            Log.shared.trace("\(isDirectory ? "Directory" : "File") was deleted: \(file)")
            
            return;
            
            do {
                
                // If a post file is deleted, check and see if its parent still exists.
                // If it does, do nothing.
                // If it doesn't, delete the post.
                
                let isPostSourceContentFile = try fileHelper.isPostSourceContentFile(fileURL: fileURL)
                let postSourceContentFileParent = fileHelper.getContainingDirectory(for: fileURL)
                if isPostSourceContentFile && postSourceContentFileParent == nil {
                    Log.shared.trace("A post source content file was deleted, but the post's folder was, too. Nothing will be done about the deleted file; the deleted post folder will be handled instead.")
                    return
                }
                
                let isPostFolder = try fileHelper.isPostFolder(fileURL)
                guard isPostFolder else {
                    return
                }
                
                Log.shared.debug("Post folder or source content file was deleted.")
                
                guard let postDirectory = fileHelper.getContainingDirectory(for: fileURL) else {
                    Log.shared.error("Post source content file was deleted, but couldn't determine the post directory. The state of the system may now be undefined. You may want to `postmark regenerate`")
                    return
                }
                
                let slug = try fileHelper.makePostSlug(for: postDirectory)
                try DataStore.shared.delete(postWith: slug)
            }
            catch {
                Log.shared.error("A file was deleted, but an error occurred evaluating whether it was a post folder or source content file: \(error.localizedDescription). Nothing will be done about this change, but the state of the system may now be undefined. You may want to `postmark regenerate`.")
            }
            
        }
    }
    
}

struct Regenerate: ParsableCommand {
    
    static var configuration = CommandConfiguration(abstract: "Regenerate all static content and/or database records for content in a given dirctory.")
    
    @Argument(help: "The content directory in which to detect and generate files. Defaults to the current directory.", transform: { string in
        return URL(filePath: string, directoryHint: .inferFromPath, relativeTo: .currentDirectory())
    })
    private var contentDirectoryURL: URL = URL(filePath: FileManager.default.currentDirectoryPath)
    
    @Option(name: [.customLong("db"), .long], help: "The path to the database file.")
    private var databaseFile: String = "store.sqlite"
    
    @Option(name: [.short, .customLong("fragments")], help: "Generate HTML fragments for posts, instead of fully-formed HTML documents.")
    var generateFragments: Bool = false
    
    @Option(name: [.customLong("db-only"), .customLong("database-only")], help: "Regenerate database entries without altering static content files.")
    private var processDatabaseOnly: Bool = false
    
    @Flag(help: "Output a summary of all changes to be made, without actaully committing them.")
    var dryRun: Bool = false

    public func run() {
        let fileHelper = PostFilesHelper(contentDirectoryURL: contentDirectoryURL)
        
        if dryRun {
            Log.shared.info("Dry run: the following changes won't be committed.")
        }
        
        let databaseFileURL = URL(fileURLWithPath: databaseFile, relativeTo: URL(string: FileManager.default.currentDirectoryPath))
        
        do {
            if !dryRun {
                try DataStore.shared.open(databaseFile: databaseFileURL.standardized)
                try DataStore.shared.deleteAllPosts()
            }
            
            let allPostDirectories = fileHelper.postDirectories
            Log.shared.debug("Found post \(allPostDirectories.count) in \(contentDirectoryURL.standardizedFileURL)")
            let processingOptions: PostProcessingQueue.ProcessingOptions = dryRun ? [.dryRun] : []
            let processingQueue = try PostProcessingQueue(postDirectories: allPostDirectories, in: contentDirectoryURL.standardizedFileURL, options: processingOptions)
            try processingQueue.process()

        }
        catch {
            Log.shared.error("Error trying to regenerate content: \(error)")
            Regenerate.exit(withError: error)
        }
    }
  
}
