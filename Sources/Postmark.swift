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
        // https://github.com/JohnWickham/Postmark/issues/1
        #if os(macOS)
        return URL(filePath: string, directoryHint: .inferFromPath, relativeTo: .currentDirectory())
        #elseif os(Linux)
        return URL(fileURLWithPath: string, isDirectory: true)
        #endif
    })
    private var contentDirectoryURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    
    @Option(name: [.customLong("db"), .long], help: "The path to the database file.")
    var databaseFile: String = "store.sqlite"
    
    @Flag(name: [.customShort("f"), .customLong("fragments")], help: "Generate HTML fragments for posts, instead of fully-formed HTML documents.")
    var generateFragments: Bool = false
    
    public func run() {
        let databaseFileURL = URL(fileURLWithPath: databaseFile, relativeTo: URL(string: FileManager.default.currentDirectoryPath))
      
        do {
            try DataStore.shared.open(databaseFile: databaseFileURL)
            let changeHandler = FileEventResponder(contentDirectoryURL: contentDirectoryURL, shouldGenerateFragments: generateFragments)
            let monitor = try FileMonitor(directory: contentDirectoryURL, delegate: changeHandler, options: nil)
            try monitor.start()
            Log.shared.info("Postmark is watching for changes in \(contentDirectoryURL)")
        }
        catch {
            Postmark.exit(withError: error)
        }
        
        RunLoop.main.run()
    }
    
}

struct Regenerate: ParsableCommand {
    
    static var configuration = CommandConfiguration(abstract: "Regenerate all static content and/or database records for content in a given dirctory.")
    
    @Argument(help: "The content directory in which to detect and generate files. Defaults to the current directory.", transform: { string in
        // https://github.com/JohnWickham/Postmark/issues/1
        #if os(macOS)
        return URL(filePath: string, directoryHint: .inferFromPath, relativeTo: .currentDirectory())
        #elseif os(Linux)
        return URL(fileURLWithPath: string, isDirectory: true)
        #endif
    })
    private var contentDirectoryURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)

    @Option(name: [.customLong("db"), .long], help: "The path to the database file.")
    private var databaseFile: String = "store.sqlite"
    
    @Option(name: [.customLong("db-only"), .customLong("database-only")], help: "Regenerate database entries without altering static content files.")
    private var processDatabaseOnly: Bool = false
    
    @Flag(name: [.customShort("f"), .customLong("fragments")], help: "Generate HTML fragments for posts, instead of fully-formed HTML documents.")
    var generateFragments: Bool = false
    
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
            var processingOptions: PostProcessingQueue.ProcessingOptions = []
            if dryRun {
                processingOptions.insert(.dryRun)
            }
            if generateFragments {
                processingOptions.insert(.generateFragments)
            }
            let processingQueue = try PostProcessingQueue(postDirectories: allPostDirectories, in: contentDirectoryURL.standardizedFileURL, options: processingOptions)
            try processingQueue.process()

        }
        catch {
            Log.shared.error("Error trying to regenerate content: \(error)")
            Regenerate.exit(withError: error)
        }
    }
  
}
