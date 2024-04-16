import Foundation
import ArgumentParser
import FileMonitor

@main
struct CMSService: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "A lightweight CMS for publishing Markdown-based hypertext.", subcommands: [Regenerate.self, Watch.self])
}

struct Watch: ParsableCommand {
    
    static var configuration = CommandConfiguration(abstract: "Watch a given directory for changes and automatically generate static content and update database entries as appropriate.")
    
    @Option(help: "The directory to monitor for changes in. Defaults to the current directory.")
    var contentDirectory: String = FileManager.default.currentDirectoryPath
    
    private var contentDirectoryURL: URL {
        return URL(fileURLWithPath: contentDirectory, isDirectory: true)
    }
    
    @Option(help: "The path to the database file. Defaults to `./store.sqlite`.")
    var databaseFilePath: String = "store.sqlite"
  
    public func run() {
        let databaseFileURL = URL(fileURLWithPath: databaseFilePath, relativeTo: URL(string: FileManager.default.currentDirectoryPath))
      
        do {
            try DataStore.shared.open(databaseFile: databaseFileURL)
            
            // FIXME: File system watching isn't working.
            let monitor = try FileMonitor(directory: contentDirectoryURL.standardizedFileURL, delegate: self)
            try monitor.start()
            Log.shared.info("Monitoring for changes in \(contentDirectory)")
        }
        catch {
            CMSService.exit(withError: error)
        }
        
        RunLoop.main.run()
    }
    
}

extension Watch: FileDidChangeDelegate {
    
    func fileDidChanged(event: FileChange) {
        let filesHelper = PostFilesHelper(contentDirectoryURL: contentDirectoryURL)
        
        switch event {
        case .added(let file), .changed(let file):
            
            guard let isPostFolder = try? filesHelper.isPostFolder(file),
            let isPostSourceFile = try? filesHelper.isPostSourceContentFile(fileURL: file) else {
                Log.shared.error("A file was added or changed, but an error occurred evalutating whether it was a post folder or post source content file. Nothing will be done about this change.")
                return
            }
            
            guard isPostFolder || isPostSourceFile else {
                return
            }
            
            Log.shared.debug("Post folder or post source content file was added or changed.")
            
            if let postDirectory = isPostFolder ? file : filesHelper.getContainingDirectory(for: file) {
                do {
                    let processingQueue = try PostProcessingQueue(postDirectory: postDirectory, in: contentDirectoryURL, commitChanges: true)
                    try processingQueue.process()
                }
                catch {
                    Log.shared.error("Error processing post: \(error.localizedDescription). Post: \(file)")
                }
            }
            
        case .deleted(let file):
            
            // If the deleted file is a post's folder or its Markdown source file, remove it from the database.
            
            guard let isPostFolder = try? filesHelper.isPostFolder(file),
            let isPostSourceContentFile = try? filesHelper.isPostSourceContentFile(fileURL: file) else {
                Log.shared.error("A file was deleted, but an error occurred evaluating whether it was a post folder or source content file. Nothing will be done about this change.")
                return
            }
            
            guard isPostFolder || isPostSourceContentFile else {
                return
            }
            
            Log.shared.debug("Post folder or source content file was deleted.")
            
            do {
                let postSlug = try filesHelper.makePostSlug(for: file)
                if let post = DataStore.shared.getPost(by: postSlug) {
                    try DataStore.shared.delete(post)
                }
            }
            catch {
                // TODO: Test whether this works haha
                Log.shared.error("Couldn't delete database entry for a post. Regenerating database.")
                Regenerate(contentDirectory: contentDirectory).run()
            }
        }
    }
    
}

struct Regenerate: ParsableCommand {
    
    static var configuration = CommandConfiguration(abstract: "Regenerate all static content and database records for content in a given dirctory.")
        
    @Option(help: "The directory to monitor for changes in. Defaults to the current directory.")
    var contentDirectory: String = FileManager.default.currentDirectoryPath
    
    private var contentDirectoryURL: URL {
        return URL(fileURLWithPath: contentDirectory, isDirectory: true)
    }
    
    @Option(help: "The path to the database file.")
    private var databaseFile: String = "store.sqlite"
  
    @Flag(help: "Output a summary of all changes to be made, without actaully committing them.")
    var dryRun = false

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
            let processingQueue = try PostProcessingQueue(postDirectories: allPostDirectories, in: contentDirectoryURL.standardizedFileURL, commitChanges: !dryRun)
            try processingQueue.process()

        }
        catch {
            Log.shared.error("Error trying to regenerate content: \(error)")
            Regenerate.exit(withError: error)
        }
    }
  
}
