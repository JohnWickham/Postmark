//
//  StaticContentGenerator.swift
//
//
//  Created by John Wickham on 4/14/24.
//

import Foundation

enum StaticContentGenerationError: Error {
    case unexpectedFileHierarchy
}

public struct StaticContentGenerator {
    
    public let contentDirectory: URL
    
    public init(contentDirectory: URL) {
        self.contentDirectory = contentDirectory
    }
    
    public func generateStaticContent(for post: Post, with markdownDocument: MarkdownFile, overwriteExisting: Bool = true) throws {
        Log.shared.trace("Starting static content generation for post: \(post)")
        
        let duration = try SuspendingClock().measure {
            let postFilesHelper = PostFilesHelper(contentDirectoryURL: contentDirectory)
            guard let containingDirectoryURL = postFilesHelper.getContainingDirectory(for: markdownDocument.fileURL),
                  let staticContentFilePath = postFilesHelper.makeStaticContentFileURL(forPostAt: containingDirectoryURL) else {
                Log.shared.error("Failed to generate static content for post: \(post.slug). Couldn't find post directory.")
                throw StaticContentGenerationError.unexpectedFileHierarchy
            }
            
            if overwriteExisting {
                try deleteExistingStaticContentFile(at: staticContentFilePath)
            }
            
            Log.shared.trace("Writing markup to file: \(staticContentFilePath)")
            try markdownDocument.markupRepresentation()?.write(to: staticContentFilePath, atomically: true, encoding: .utf8)
            
            post.hasGeneratedContent = true
        }
        
        Log.shared.trace("Finished generating static content for post in \(duration.description)")
    }
    
    private func deleteExistingStaticContentFile(at fileURL: URL) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              FileManager.default.isDeletableFile(atPath: fileURL.path) else {
            Log.shared.error("Existing static content file could not be deleted. Nothing will be generated.")
            return
        }
    }
}
