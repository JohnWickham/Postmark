//
//  PostProcessor.swift
//
//
//  Created by John Wickham on 4/16/24.
//

import Foundation

// Manages the pipeline of generating content and database entries for a post.
struct PostProcessor {
    
    private var contentDirectory: URL
    private var filesHelper: PostFilesHelper
    
    private var post: Post
    private var markdownDocument: MarkdownFile
    
    // Initialize given a post directory URL and begin processing.
    init(postDirectory: URL, in contentDirectory: URL) throws {
        self.contentDirectory = contentDirectory
        self.filesHelper = PostFilesHelper(contentDirectoryURL: contentDirectory)
        
        guard let sourceContentFileURL = filesHelper.getContentSourceFile(forPostAt: postDirectory) else {
            throw PostFileAnalysisError.noContentSourceFile(inDirectory: postDirectory)
        }
        
        self.markdownDocument = MarkdownFile(fileURL: sourceContentFileURL)
        self.post = try Post(describing: postDirectory, markdownFile: markdownDocument)
    }
    
    public func process() throws {
        try addDatabaseEntries(for: post)
        try generateStaticContent(for: post)
    }
    
    // Method for creating/updating database entries
    private func addDatabaseEntries(for post: Post) throws {
        try DataStore.shared.addOrUpdate(post)
    }
    
    // Method for generating static content files
    private func generateStaticContent(for post: Post) throws {
        let staticContentGenerator = StaticContentGenerator(contentDirectory: contentDirectory)
        staticContentGenerator.generateStaticContent(for: post, overwriteExisting: true)
    }
    
}
