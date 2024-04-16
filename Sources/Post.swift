//
//  Post.swift
//
//
//  Created by John Wickham on 4/14/24.
//

import Foundation

enum PostFileAnalysisError: Error {
    case notADirectory(path: String)
    case noCreationDate(path: String)
    case noContentSourceFile(inDirectory: URL)
    case noSuitableSlug(forDirectory: URL)
}

public class Post: Codable {
    var slug: String
    var title: String
    var createdDate: Date
    var updatedDate: Date?
    var previewContent: String?
    var hasGeneratedContent: Bool?
        
    init(slug: String, title: String, createdDate: Date, updatedDate: Date? = nil, previewContent: String? = nil, hasGeneratedContent: Bool? = nil) {
        self.slug = slug
        self.title = title
        self.createdDate = createdDate
        self.updatedDate = updatedDate
        self.previewContent = previewContent
        self.hasGeneratedContent = hasGeneratedContent
    }
    
    /* Initializes a Post describing the given content directory. */
    init(describing directory: URL, markdownFile: MarkdownFile?) throws {
        // TODO: Validate that the directory is a proper post directory
        
        let parentDirectory = directory.deletingLastPathComponent()
        let filesHelper = PostFilesHelper(contentDirectoryURL: parentDirectory)
        guard let contentSourceFileURL = filesHelper.getContentSourceFile(forPostAt: directory) else {
            throw PostFileAnalysisError.noContentSourceFile(inDirectory: directory)
        }
        
        let sourceFileAttributes = try FileManager.default.attributesOfItem(atPath: contentSourceFileURL.path)
        guard let sourceFileCreationDate = sourceFileAttributes[FileAttributeKey.creationDate] as? Date else {
            throw PostFileAnalysisError.noCreationDate(path: directory.path)
        }
        
        if let staticContentFile = filesHelper.makeStaticContentFileURL(forPostAt: directory),
           FileManager.default.fileExists(atPath: staticContentFile.path) {
            self.hasGeneratedContent = true
        }
        
        let sourceFileUpdatedDate = sourceFileAttributes[FileAttributeKey.modificationDate] as? Date
                
        guard let slug = try? filesHelper.postSlug(for: directory) else {
            throw PostFileAnalysisError.noSuitableSlug(forDirectory: directory)
        }
        
        self.slug = slug
        self.title = markdownFile?.parsedContent?.title ?? "Untitled"
        self.createdDate = sourceFileCreationDate
        self.updatedDate = sourceFileUpdatedDate
        self.previewContent = markdownFile?.truncatedBodyContent
        Log.shared.debug("Initialized Post with preview content: \(String(describing: previewContent))")
        
        parseMetadata(from: markdownFile)
    }
    
    // Initialize properties by reading metadata from the header of the post's source content Markdown file
    private func parseMetadata(from markdownFile: MarkdownFile?) {
        let metadata = markdownFile?.metadata
        
        if let title = metadata?["title"] {
            self.title = title
        }
        
        if let createdDateString = metadata?["created"],
           let createdDate = dateFrom(createdDateString) {
            self.createdDate = createdDate
        }
        
        if let updatedDateString = metadata?["updated"],
           let updatedDate = dateFrom(updatedDateString) {
            self.updatedDate = updatedDate
        }
        
        if let previewContent = metadata?["preview"] {
            self.previewContent = previewContent
        }
    }
    
    // Parse a date string formatted as Year-Month-Day
    private func dateFrom(_ string: String?) -> Date? {
        guard let string = string else {
            return nil
        }
        
        let dateFormatStyle = Date.FormatStyle().year().month().day()
        return try? dateFormatStyle.parse(string)
    }
}
