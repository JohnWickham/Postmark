//
//  StaticContentGenerator.swift
//
//
//  Created by John Wickham on 4/14/24.
//

import Foundation

enum StaticContentGenerationError: Error {
    case noContentSourceFile(inDirectory: URL)
}

public struct StaticContentGenerator {
    
    public let contentDirectory: URL
    
    public func generateStaticContent(for post: Post, with markdownDocument: MarkdownFile, overwriteExisting: Bool = true) throws {
        Log.shared.trace("Starting static content generation for post: \(post)")
        
        let duration = try SuspendingClock().measure {
            let postFilesHelper = PostFilesHelper(contentDirectoryURL: contentDirectory)
            let staticContentFilePath = postFilesHelper.makeStaticContentFileURL(forPostWith: post.slug)
            
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
