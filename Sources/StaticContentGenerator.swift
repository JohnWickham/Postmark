//
//  StaticContentGenerator.swift
//
//
//  Created by John Wickham on 4/14/24.
//

import Foundation

public struct StaticContentGenerator {
    
    public let contentDirectory: URL
    
    public func generateStaticContent(for post: Post, overwriteExisting: Bool = true) {
        Log.shared.trace("Generating static content for post: \(post.slug)")
        
        let postFilesHelper = PostFilesHelper(contentDirectoryURL: contentDirectory)
        let staticContentFilePath = fileURLForIndexHTMLFile(for: post)
        let contentSourceFilePath = postFilesHelper.getContentSourceFile(forPostWith: post.slug)
        let markdownFile = MarkdownFile(fileURL: contentSourceFilePath)
        
        do {
            if overwriteExisting,
               FileManager.default.fileExists(atPath: staticContentFilePath.path),
               FileManager.default.isDeletableFile(atPath: staticContentFilePath.path) {
                Log.shared.trace("Deleting static content file: \(staticContentFilePath.path())")
                try FileManager.default.removeItem(at: staticContentFilePath)
            }
            
            Log.shared.trace("Writing markup to file: \(staticContentFilePath)")
            try markdownFile.markupRepresentation?.write(to: staticContentFilePath, atomically: true, encoding: .utf8)
            
            post.hasGeneratedContent = true
            try DataStore.shared.addOrUpdate(post)
        }
        catch {
            // TODO: Propagate this error somehow?
            Log.shared.error("Error while generating static content for post: \(error.localizedDescription)")
        }
    }
    
    private func fileURLForIndexHTMLFile(for post: Post) -> URL {
        return contentDirectory.appending(path: post.slug, directoryHint: .isDirectory).appendingPathComponent("\(post.slug).html", isDirectory: false)
    }
    
    // Get the template HTML file
    // Parse Markdown source file
    // Generate HTML from Markdown source
    // Perform syntax highlighting on parsed Markdown content
    // Substitute resulting markup into the template file
    // if overwritingExisting, delete existing index.html file
    // Write the resulting HTML file to index.html
    // Update the database entry for the post to indicate that static content has been generated
    
}
