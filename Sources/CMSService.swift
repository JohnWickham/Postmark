import Foundation
import ArgumentParser
import FileMonitor

@main
struct CMSService: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "A lightweight CMS for publishing Markdown-based hypertext.", subcommands: [Regenerate.self, Watch.self])
}

struct Watch: ParsableCommand {
    
    @Option(help: "The directory to monitor for changes in. Defaults to the current directory.")
    var contentDirectory: String = FileManager.default.currentDirectoryPath
    
    private var contentDirectoryURL: URL {
        return URL(fileURLWithPath: contentDirectory, isDirectory: true)
    }
    
    @Option(help: "The path to the database file. Defaults to `./store.sqlite`.")
    var databaseFilePath: String = "store.sqlite"
  
    public func run() {
        let databaseFileURL = URL(fileURLWithPath: databaseFilePath, relativeTo: URL(string: FileManager().currentDirectoryPath))
      
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
        let staticGenerator = StaticContentGenerator(contentDirectory: contentDirectoryURL)
        
        do {
            switch event {
            case .added(let file):
                
                guard let isPostFolder = try? filesHelper.isPostFolder(file),
                let isPostMetaFile = try? filesHelper.isPostMetaFile(fileURL: file) else {
                    Log.shared.warning("A file was added, but an error was thrown evalutating whether it was a post folder or post meta file. Nothing will be done about this change.")
                    return
                }
                
                if file.isDirectory || isPostFolder || isPostMetaFile {
                    let newPost = try Post(describing: file)
                    try DataStore.shared.addOrUpdate(newPost)
                    staticGenerator.generateStaticContent(for: newPost)
                    Log.shared.debug("New post folder or post meta file was added.")
                }
                
            case .changed(let file):
                
                // TODO: If a post's directory changes, can we tell what the old and new slugs were to update its database entry?
                
                guard let isPostMetaFile = try? filesHelper.isPostMetaFile(fileURL: file),
                      let isPostSourceContentFile = try? filesHelper.isPostSourceContentFile(fileURL: file) else {
                    Log.shared.warning("A file was changed, but an error was thrown when evalutaing whether it was a post meta file or post source content file. Nothing will be done about this change.")
                    return
                }

                if isPostMetaFile || isPostSourceContentFile {
                    let updatedPost = try Post(describing: file)
                    try DataStore.shared.addOrUpdate(updatedPost)
                    staticGenerator.generateStaticContent(for: updatedPost)
                    Log.shared.debug("Post meta file or source content file was changed.")
                }
                
            case .deleted(let file):
                
                guard let isPostFolder = try? filesHelper.isPostFolder(file),
                let isPostSourceContentFile = try? filesHelper.isPostSourceContentFile(fileURL: file),
                      let isPostMetaFile = try? filesHelper.isPostMetaFile(fileURL: file) else {
                    // TODO: Log this error
                    return
                }
                
                if isPostFolder || isPostSourceContentFile {
                    // If the deleted file is a post's folder or its Markdown source file, remove its manifest entry. If the deleted file is a post's meta file, regenerate its manifest entry.
                    Log.shared.debug("Post folder or source content file was deleted.")
                    
                    do {
                        let postSlug = try filesHelper.postSlug(for: file)
                        if let post = try DataStore.shared.getPost(by: postSlug) {
                            try DataStore.shared.delete(post)
                        }
                    }
                    catch {
                        // TODO: Test whether this works haha
                        Log.shared.error("Couldn't delete database entry for a post. Regenerating database.")
                        Regenerate(contentDirectory: contentDirectory).run()
                    }
                }
                else if isPostMetaFile {
                    Log.shared.debug("Post meta file was deleted.")
                    let post = try Post(describing: file)
                    try DataStore.shared.addOrUpdate(post)
                }
            }
        }
        catch {
            Log.shared.debug("Error handling file changes: \(error.localizedDescription)")
        }
    }
    
}

struct Regenerate: ParsableCommand {
        
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
        
        let databaseFileURL = URL(fileURLWithPath: databaseFilePath, relativeTo: URL(string: FileManager().currentDirectoryPath))
        
        do {
            try DataStore.shared.open(databaseFile: databaseFileURL.standardized)
            try DataStore.shared.deleteAllPosts()
            
            let allPostDirectories = fileHelper.postDirectories
            Log.shared.debug("Found post directories: \(allPostDirectories)")
            for directory in allPostDirectories {
                guard let post = try? Post(describing: directory) else {
                    Log.shared.error("A Post could not be derived from a post directory: \(directory.path)")
                    continue
                }
                
                Log.shared.debug("Adding post to database: \(post.slug)")
                try DataStore.shared.addOrUpdate(post)
                StaticContentGenerator(contentDirectory: contentDirectoryURL.standardized).generateStaticContent(for: post)
            }

        }
        catch {
            Log.shared.error("Error trying to regenerate content: \(error)")
            Regenerate.exit(withError: error)
        }
    }
  
}
