//
//  PostProcessor.swift
//
//
//  Created by John Wickham on 4/16/24.
//

import Foundation

struct PostProcessingTask: CustomDebugStringConvertible {
    let post: Post
    let markdownDocument: MarkdownFile
    
    var debugDescription: String {
        return "Post: \(post). Source content file: \(markdownDocument.fileURL)"
    }
}

// Manages the pipeline of generating content and database entries for a post.
struct PostProcessingQueue {
    
    private var contentDirectory: URL
    private var filesHelper: PostFilesHelper
    private var staticContentGenerator: StaticContentGenerator
    
    private var tasks: [PostProcessingTask]
    
    private var shouldCommitChanges: Bool
    
    public init(postDirectory: URL, in contentDirectory: URL, commitChanges: Bool) throws {
        self.contentDirectory = contentDirectory
        self.filesHelper = PostFilesHelper(contentDirectoryURL: contentDirectory)
        self.staticContentGenerator = StaticContentGenerator(contentDirectory: contentDirectory)
        self.shouldCommitChanges = commitChanges
        
        guard let sourceContentFileURL = filesHelper.getContentSourceFile(forPostAt: contentDirectory) else {
            throw PostFileAnalysisError.noContentSourceFile(inDirectory: contentDirectory)
        }
        let task = try PostProcessingQueue.makeProcessingTask(for: sourceContentFileURL, in: contentDirectory)
        self.tasks = [task]
    }
    
    public init(postDirectories: [URL], in contentDirectory: URL, commitChanges: Bool) throws {
        self.contentDirectory = contentDirectory
        self.filesHelper = PostFilesHelper(contentDirectoryURL: contentDirectory)
        self.staticContentGenerator = StaticContentGenerator(contentDirectory: contentDirectory)
        self.shouldCommitChanges = commitChanges
        
        self.tasks = []
        // FIXME: Mapping postDirectories to makeProcessingTask(for: in:) captured self.tasks before it was initialized somehow?
        for postDirectory in postDirectories {
            guard let sourceContentFileURL = filesHelper.getContentSourceFile(forPostAt: postDirectory) else {
                throw PostFileAnalysisError.noContentSourceFile(inDirectory: postDirectory)
            }
            let task = try PostProcessingQueue.makeProcessingTask(for: sourceContentFileURL, in: postDirectory)
            Log.shared.trace("Queueing processing task: \(task)")
            self.tasks.append(task)
        }
    }
    
    private static func makeProcessingTask(for sourceContentFileURL: URL, in directoryURL: URL) throws -> PostProcessingTask {
        let markdownDocument = try MarkdownFile(fileURL: sourceContentFileURL)
        let post = try Post(describing: directoryURL, markdownFile: markdownDocument)
        return PostProcessingTask(post: post, markdownDocument: markdownDocument)
    }
    
    public func process() throws {
        Log.shared.trace("Processing \(tasks.count) post\(tasks.count == 1 ? "" : "s")")
        let duration = SuspendingClock().measure {
            // TODO: Dequeue tasks
            for task in tasks {
                do {
                    try generateStaticContent(for: task.post, with: task.markdownDocument)
                    try addDatabaseEntries(for: task.post)
                }
                catch {
                    Log.shared.error("Failed to process post: \(error.localizedDescription)")
                }
            }
        }
        Log.shared.trace("Finished processing \(tasks.count) post\(tasks.count == 1 ? "" : "s") in \(duration.description)")
    }
    
    // Method for generating static content files
    private func generateStaticContent(for post: Post, with markdownDocument: MarkdownFile) throws {
        if shouldCommitChanges {
            try staticContentGenerator.generateStaticContent(for: post, with: markdownDocument, overwriteExisting: true)
        }
        else {
            Log.shared.info("Generate static content file for: \(post.slug)")
        }
    }
    
    // Method for creating/updating database entries
    private func addDatabaseEntries(for post: Post) throws {
        if shouldCommitChanges {
            try DataStore.shared.addOrUpdate(post)
        }
        else {
            Log.shared.info("Add post to database: \(post)")
        }
    }
    
}
