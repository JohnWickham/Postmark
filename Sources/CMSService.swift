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
        case .added(let file):
            
            guard let isPostFolder = try? filesHelper.isPostFolder(file),
            let isPostSourceFile = try? filesHelper.isPostSourceContentFile(fileURL: file) else {
                Log.shared.warning("A file was added, but an error was thrown evalutating whether it was a post folder or post meta file. Nothing will be done about this change.")
                return
            }
            
            guard isPostFolder || isPostSourceFile else {
                return
            }
            
            Log.shared.debug("New post folder or post source content file was added.")
            
            if let postDirectory = isPostFolder ? file : filesHelper.getContainingDirectory(for: file) {
                do {
                    let postProcessor = try PostProcessor(postDirectory: postDirectory, in: contentDirectoryURL)
                    try postProcessor.process()
                }
                catch {
                    Log.shared.error("Error processing post: \(error.localizedDescription). Post: \(file)")
                }
            }
            
        case .changed(let file):
                            
            guard let isPostSourceContentFile = try? filesHelper.isPostSourceContentFile(fileURL: file) else {
                Log.shared.warning("A file was changed, but an error was thrown when evalutaing whether it was a post source content file. Nothing will be done about this change.")
                return
            }

            guard isPostSourceContentFile else {
                return
            }
            
            Log.shared.debug("Post source content file was changed.")
            
            if let postDirectory = filesHelper.getContainingDirectory(for: file) {
                do {
                    let postProcessor = try PostProcessor(postDirectory: postDirectory, in: contentDirectoryURL)
                    try postProcessor.process()
                }
                catch {
                    Log.shared.error("Error processing post: \(error.localizedDescription). Post: \(file)")
                }
            }
            
        case .deleted(let file):
            
            // If the deleted file is a post's folder or its Markdown source file, remove it from the database.
            
            guard let isPostFolder = try? filesHelper.isPostFolder(file),
            let isPostSourceContentFile = try? filesHelper.isPostSourceContentFile(fileURL: file) else {
                Log.shared.warning("A file was changed, but an error was thrown evaluating whether it was a post folder or source content file. Nothing will be done about this change.")
                return
            }
            
            guard isPostFolder || isPostSourceContentFile else {
                return
            }
            
            Log.shared.debug("Post folder or source content file was deleted.")
            
            do {
                let postSlug = try filesHelper.postSlug(for: file)
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
    private var databaseFilePath: String = "store.sqlite"
  
    @Flag(help: "Output a summary of all changes to be made, without actaully writing any files.")
    var dryRun = false

    public func run() {
        let fileHelper = PostFilesHelper(contentDirectoryURL: contentDirectoryURL)
        
        // TODO: Implement the dryRun option
        
        let databaseFileURL = URL(fileURLWithPath: databaseFilePath, relativeTo: URL(string: FileManager.default.currentDirectoryPath))
        
        do {
            try DataStore.shared.open(databaseFile: databaseFileURL.standardized)
            try DataStore.shared.deleteAllPosts()
            
            let allPostDirectories = fileHelper.postDirectories
            Log.shared.debug("Found post directories: \(allPostDirectories)")
            for directory in allPostDirectories {
                do {
                    let postProcessor = try PostProcessor(postDirectory: directory, in: contentDirectoryURL)
                    try postProcessor.process()
                }
                catch {
                    Log.shared.error("Error processing post: \(error.localizedDescription). Post: \(directory)")
                }
            }

        }
        catch {
            Log.shared.error("Error trying to regenerate content: \(error)")
            Regenerate.exit(withError: error)
        }
    }
  
}
