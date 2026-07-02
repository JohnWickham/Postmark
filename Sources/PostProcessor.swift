//
//  PostProcessor.swift
//
//
//  Created by John Wickham on 4/16/24.
//

import Foundation
import Progress

struct PostProcessingTask: CustomDebugStringConvertible {
    let fileSet: PostFileSet
    let post: Post
    let markdownDocument: MarkdownFile

    var debugDescription: String {
        return "Post: \(post.slug). Source content file: \(markdownDocument.fileURL)"
    }
}

struct PostProcessingFailure {
    let task: PostProcessingTask
    let error: Error
}

struct PostProcessingResult {
    let succeeded: [PostProcessingTask]
    let failed: [PostProcessingFailure]

    var processedSlugs: [String] {
        return succeeded.map { $0.post.slug }
    }
}

enum PostProcessingError: Error {
    case failedTasks([PostProcessingFailure])
}

public enum contentGeneratingMode {
    case fullyFormed, fragments
}

// Manages the pipeline of generating content and database entries for a post.
class PostProcessingQueue {

    public struct ProcessingOptions: OptionSet {
        public var rawValue: Int

        static var dryRun = ProcessingOptions(rawValue: 1)
        static var generateFragments = ProcessingOptions(rawValue: 2)
        static var databaseOnly = ProcessingOptions(rawValue: 4)
    }

    private var contentDirectory: URL
    private var filesHelper: PostFilesHelper
    private var staticContentGenerator: StaticContentGenerator

    private var tasks: [PostProcessingTask]

    private var shouldCommitChanges: Bool
    private var shouldGenerateFragments: Bool
    private var shouldProcessDatabaseOnly: Bool

    public init(postDirectory: URL, in contentDirectory: URL, options: ProcessingOptions = []) throws {
        self.contentDirectory = contentDirectory
        self.filesHelper = PostFilesHelper(contentDirectoryURL: contentDirectory)
        self.staticContentGenerator = StaticContentGenerator(contentDirectory: contentDirectory)
        self.shouldCommitChanges = !options.contains(.dryRun)
        self.shouldGenerateFragments = options.contains(.generateFragments)
        self.shouldProcessDatabaseOnly = options.contains(.databaseOnly)

        let fileSet = try filesHelper.makePostFileSet(forPostAt: postDirectory)
        let task = try PostProcessingQueue.makeProcessingTask(for: fileSet)
        self.tasks = [task]
    }

    public init(postDirectories: [URL], in contentDirectory: URL, options: ProcessingOptions = []) throws {
        self.contentDirectory = contentDirectory
        self.filesHelper = PostFilesHelper(contentDirectoryURL: contentDirectory)
        self.staticContentGenerator = StaticContentGenerator(contentDirectory: contentDirectory)
        self.shouldCommitChanges = !options.contains(.dryRun)
        self.shouldGenerateFragments = options.contains(.generateFragments)
        self.shouldProcessDatabaseOnly = options.contains(.databaseOnly)

        self.tasks = []
        // FIXME: Mapping postDirectories to makeProcessingTask(for: in:) captured self.tasks before it was initialized somehow?
        for postDirectory in postDirectories {
            let fileSet = try filesHelper.makePostFileSet(forPostAt: postDirectory)
            let task = try PostProcessingQueue.makeProcessingTask(for: fileSet)
            Log.shared.trace("Queueing processing task: \(task)")
            self.tasks.append(task)
        }
    }

    private static func makeProcessingTask(for fileSet: PostFileSet) throws -> PostProcessingTask {
        let markdownDocument = try MarkdownFile(fileURL: fileSet.sourceMarkdownFileURL)
        let post = try Post(fileSet: fileSet, markdownFile: markdownDocument)
        return PostProcessingTask(fileSet: fileSet, post: post, markdownDocument: markdownDocument)
    }

    @discardableResult
    public func process(throwOnFailure: Bool = true) throws -> PostProcessingResult {
        let initialTasksCount = tasks.count
        Log.shared.trace("Processing \(initialTasksCount) post\(initialTasksCount == 1 ? "" : "s")")

        var succeededTasks: [PostProcessingTask] = []
        var failedTasks: [PostProcessingFailure] = []
        let duration = SuspendingClock().measure {

            // Dequeue and process tasks
            while tasks.count > 0 {
                let task = tasks.removeFirst()

                do {
                    try generateStaticContent(for: task)
                    try addDatabaseEntries(for: task.post)
                    succeededTasks.append(task)
                }
                catch {
                    Log.shared.error("Failed to process post: \(error)")
                    failedTasks.append(PostProcessingFailure(task: task, error: error))
                }
            }

        }

        let successfulTaskCount = initialTasksCount - failedTasks.count
        Log.shared.trace("Finished processing \(successfulTaskCount) post\(successfulTaskCount == 1 ? "" : "s") in \(duration.description). \(failedTasks.count) posts failed to process.")

        let result = PostProcessingResult(succeeded: succeededTasks, failed: failedTasks)
        if throwOnFailure && !failedTasks.isEmpty {
            throw PostProcessingError.failedTasks(failedTasks)
        }

        return result
    }

    // Method for generating static content files
    private func generateStaticContent(for task: PostProcessingTask) throws {
        if shouldProcessDatabaseOnly {
            Log.shared.debug("Skip static content generation for database-only processing: \(task.post.slug)")
            return
        }

        if shouldCommitChanges {
            _ = try staticContentGenerator.generateStaticContent(for: task.post, with: task.markdownDocument, fileSet: task.fileSet, fragment: shouldGenerateFragments, overwriteExisting: true)
        }
        else {
            Log.shared.debug("Generate static \(shouldGenerateFragments ? "fragment" : "markup") file for: \(task.post.slug)")
        }
    }

    // Method for creating/updating database entries
    private func addDatabaseEntries(for post: Post) throws {
        if shouldCommitChanges {
            try DataStore.shared.addOrUpdate(post)
        }
        else {
            Log.shared.debug("Add post to database: \(post)")
        }
    }

}
