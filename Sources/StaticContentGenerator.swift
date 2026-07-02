//
//  StaticContentGenerator.swift
//
//
//  Created by John Wickham on 4/14/24.
//

import Foundation

enum StaticContentGenerationError: Error {
    case unexpectedFileHierarchy
    case existingStaticContentFileNotDeletable(URL)
}

struct GeneratedStaticContent {
    let post: Post
    let fileURL: URL
    let markup: String
}

// TODO: Support generating fully-formed HTML or fragments
public struct StaticContentGenerator {

    public let contentDirectory: URL

    public init(contentDirectory: URL) {
        self.contentDirectory = contentDirectory
    }

    public func generateStaticContent(for post: Post, with markdownDocument: MarkdownFile, fragment: Bool = false, overwriteExisting: Bool = true) throws {
        let postFilesHelper = PostFilesHelper(contentDirectoryURL: contentDirectory)
        guard let containingDirectoryURL = postFilesHelper.getContainingDirectory(for: markdownDocument.fileURL) else {
            Log.shared.error("Failed to generate static content for post: \(post.slug). Couldn't find post directory.")
            throw StaticContentGenerationError.unexpectedFileHierarchy
        }

        let fileSet: PostFileSet
        do {
            fileSet = try postFilesHelper.makePostFileSet(forPostAt: containingDirectoryURL)
        }
        catch {
            fileSet = PostFileSet(
                contentDirectoryURL: contentDirectory,
                postDirectoryURL: containingDirectoryURL,
                sourceMarkdownFileURL: markdownDocument.fileURL,
                staticContentFileURL: containingDirectoryURL.appendingPathComponent("index.html"),
                slug: post.slug,
                publishStatus: post.publishStatus
            )
        }
        _ = try generateStaticContent(for: post, with: markdownDocument, fileSet: fileSet, fragment: fragment, overwriteExisting: overwriteExisting)
    }

    func generateStaticContent(for post: Post, with markdownDocument: MarkdownFile, fileSet: PostFileSet, fragment: Bool = false, overwriteExisting: Bool = true) throws -> GeneratedStaticContent {
        Log.shared.trace("Starting static content generation for post: \(post)")

        var generatedContent: GeneratedStaticContent?
        let duration = try SuspendingClock().measure {
            if overwriteExisting {
                try deleteExistingStaticContentFile(at: fileSet.staticContentFileURL)
            }

            let markup = try markdownDocument.renderMarkup(fragment: fragment)
            Log.shared.trace("Writing markup to file: \(fileSet.staticContentFileURL)")
            try markup.write(to: fileSet.staticContentFileURL, atomically: true, encoding: .utf8)

            post.hasGeneratedContent = true
            generatedContent = GeneratedStaticContent(post: post, fileURL: fileSet.staticContentFileURL, markup: markup)
        }

        Log.shared.trace("Finished generating static content for post in \(duration.description)")
        if let generatedContent {
            return generatedContent
        }

        throw MarkdownDocumentError.failedToRenderMarkup(fileAtURL: markdownDocument.fileURL)
    }

    private func deleteExistingStaticContentFile(at fileURL: URL) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        guard FileManager.default.isDeletableFile(atPath: fileURL.path) else {
            Log.shared.error("Existing static content file could not be deleted. Nothing will be generated.")
            throw StaticContentGenerationError.existingStaticContentFileNotDeletable(fileURL)
        }

        try FileManager.default.removeItem(at: fileURL)
    }
}
