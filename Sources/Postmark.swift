import Foundation
import ArgumentParser
import FileMonitor
import Logging

@main
struct Postmark: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "A lightweight CMS for publishing Markdown-based hypertext.", subcommands: [Regenerate.self, Watch.self])
}

struct Watch: ParsableCommand {
    
    static var configuration = CommandConfiguration(abstract: "Watch a given directory for changes and automatically generate static content and update database entries as appropriate.")
    
    @Argument(help: "The content directory in which to detect and generate files. Default: `./content/`.", transform: { string in
        return URL.currentDirectory().relativeURLForPath(string, directoryHint: .isDirectory)
    })
    var contentDirectoryURL: URL = URL(filePath: "content", directoryHint: .isDirectory, relativeTo: .currentDirectory())

    @Option(name: [.customLong("db", withSingleDash: true), .customLong("database-file")], help: "The path to the database file. Default: `./store.sqlite`.", transform: { string in
        return URL.currentDirectory().relativeURLForPath(string, directoryHint: .notDirectory)
    })
    var databaseFileURL: URL = URL(filePath: "store.sqlite", directoryHint: .notDirectory, relativeTo: .currentDirectory())
    
    @Option(name: [.customShort("l"), .long], help: "Level of log output to display (trace, debug, info, notice, warning, error, critical). Default: info.")
    var logLevel: Logger.Level = .info
    
    @Flag(name: [.customShort("f"), .customLong("fragments")], help: "Generate HTML fragments for posts, instead of fully-formed HTML documents.")
    var generateFragments: Bool = false
    
    public func run() {
        Log.shared.logLevel = logLevel
        
        do {
            try DataStore.shared.open(databaseFile: databaseFileURL)
            let changeHandler = FileEventResponder(contentDirectoryURL: contentDirectoryURL, shouldGenerateFragments: generateFragments)
            let monitor = try FileMonitor(directory: contentDirectoryURL, delegate: changeHandler, options: nil)
            try monitor.start()
            Log.shared.info("Postmark is watching for changes in \(contentDirectoryURL.absoluteURL.path())")
        }
        catch {
            Postmark.exit(withError: error)
        }
        
        RunLoop.main.run()
    }
    
}

struct Regenerate: ParsableCommand {
    
    static var configuration = CommandConfiguration(abstract: "Regenerate all static content and/or database records for content in a given dirctory.")
    
    @Argument(help: "The content directory in which to detect and generate files. Default: `./content/`.", transform: { string in
        return URL.currentDirectory().relativeURLForPath(string, directoryHint: .isDirectory)
    })
    var contentDirectoryURL: URL = URL(filePath: "content", directoryHint: .isDirectory, relativeTo: .currentDirectory())

    @Option(name: [.customLong("db", withSingleDash: true), .customLong("database-file")], help: "The path to the database file. Default: `./store.sqlite`.", transform: { string in
        return URL.currentDirectory().relativeURLForPath(string, directoryHint: .notDirectory)
    })
    var databaseFileURL: URL = URL(filePath: "store.sqlite", directoryHint: .notDirectory, relativeTo: .currentDirectory())
    
    @Option(name: [.customShort("l"), .long], help: "Level of log output to display (trace, debug, info, notice, warning, error, critical). Default: info.")
    var logLevel: Logger.Level = .info
    
    @Option(name: [.customLong("db-only"), .customLong("database-only")], help: "Regenerate database entries without altering static content files.")
    var processDatabaseOnly: Bool = false
    
    @Flag(name: [.customShort("f"), .customLong("fragments")], help: "Generate HTML fragments for posts, instead of fully-formed HTML documents.")
    var generateFragments: Bool = false
    
    @Flag(help: "Output a summary of all changes to be made, without actaully committing them.")
    var dryRun: Bool = false

    public func run() {
        Log.shared.logLevel = logLevel
        
        let fileHelper = PostFilesHelper(contentDirectoryURL: contentDirectoryURL)
        
        if dryRun {
            Log.shared.info("Dry run: the following changes won't be committed.")
        }
        
        do {
            if !dryRun {
                try DataStore.shared.open(databaseFile: databaseFileURL)
                try DataStore.shared.deleteAllPosts()
            }
            
            let allPostDirectories = fileHelper.postDirectories
            Log.shared.info("Found \(allPostDirectories.count) post\(allPostDirectories.count == 1 ? "" : "s") in \(contentDirectoryURL.absoluteURL.path())")
            var processingOptions: PostProcessingQueue.ProcessingOptions = []
            if dryRun {
                processingOptions.insert(.dryRun)
            }
            if generateFragments {
                processingOptions.insert(.generateFragments)
            }
            let processingQueue = try PostProcessingQueue(postDirectories: allPostDirectories, in: contentDirectoryURL, options: processingOptions)
            try processingQueue.process()

        }
        catch {
            Log.shared.error("Error trying to regenerate content: \(error)")
            Regenerate.exit(withError: error)
        }
    }
  
}
