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

public struct Topic: Codable {
    var slug: String
    var title: String
}

public class Post: Codable {
    
    public enum PublishStatus: String, Codable {
        case `public` = "public"
        case draft = "draft"
        case `private` = "private"
    }
    
    var slug: String
    var title: String
    var topics: [Topic]?
    var createdDate: Date
    var updatedDate: Date?
    var publishStatus: PublishStatus
    var previewContent: String?
    var hasGeneratedContent: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case slug, title, createdDate, updatedDate, previewContent, publishStatus, hasGeneratedContent
    }
        
    init(slug: String, title: String, topics: [Topic], createdDate: Date, updatedDate: Date? = nil, publishStatus: PublishStatus, previewContent: String? = nil, hasGeneratedContent: Bool? = nil) {
        self.slug = slug
        self.title = title
        self.topics = topics
        self.createdDate = createdDate
        self.updatedDate = updatedDate
        self.publishStatus = publishStatus
        self.previewContent = previewContent
        self.hasGeneratedContent = hasGeneratedContent
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(slug, forKey: .slug)
        try container.encode(title, forKey: .title)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(updatedDate, forKey: .updatedDate)
        try container.encode(publishStatus.rawValue, forKey: .publishStatus)
        try container.encodeIfPresent(previewContent, forKey: .previewContent)
        try container.encodeIfPresent(hasGeneratedContent, forKey: .hasGeneratedContent)
    }
    
    /* Initializes a Post describing the given content directory. */
    init(describing directory: URL, markdownFile: MarkdownFile?) throws {
        
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
                
        guard let slug = try? filesHelper.makePostSlug(for: directory) else {
            throw PostFileAnalysisError.noSuitableSlug(forDirectory: directory)
        }
        
        self.slug = slug
        self.title = markdownFile?.parsedContent.title ?? "Untitled"
        self.createdDate = sourceFileCreationDate
        self.updatedDate = sourceFileUpdatedDate
        self.publishStatus = filesHelper.makePostPublishStatus(for: directory)
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
        
        if let topicNamesList = metadata?["topics"] as? String {
            let topicNames = topicNamesList.matchingSubstrings(usingRegex: "(?<=^|\\s)[a-zA-Z0-9- ]+")
            let topics = topicNames.compactMap { (topicName) -> Topic? in
                guard let slug = topicName.makeSlug() else {
                    return nil
                }
                return Topic(slug: slug.lowercased(), title: topicName)
            }
            Log.shared.trace("Found \(topics.count) topics for post: \(slug)")
            self.topics = topics
        }
        
        if let createdDateString = metadata?["created"],
           let createdDate = dateFrom(createdDateString) {
            Log.shared.trace("Made date: \(createdDate) from string: \(createdDateString)")
            self.createdDate = createdDate
        }
        
        if let updatedDateString = metadata?["updated"],
           let updatedDate = dateFrom(updatedDateString) {
            Log.shared.trace("Made date: \(updatedDate) from string: \(updatedDateString)")
            self.updatedDate = updatedDate
        }
        
        if let previewContent = metadata?["preview"] {
            self.previewContent = previewContent
        }
        
        if let publishStatusString = metadata?["status"] {
            self.publishStatus = Post.PublishStatus(rawValue: publishStatusString) ?? .public
        }
    }
    
    // Parse a date string formatted as Year-Month-Day
    private func dateFrom(_ string: String?) -> Date? {
        guard let string = string else {
            return nil
        }
        
        let parseStrategy = Date.ParseStrategy(format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)", timeZone: .current)
        return try? Date(string, strategy: parseStrategy)
    }
}

extension Post: CustomDebugStringConvertible {
    public var debugDescription: String {
        let hasGeneratedContent = hasGeneratedContent ?? false
        return "Slug: \(slug). Title: \(title). Created: \(createdDate.description(with: .current)). Updated: \(updatedDate?.description(with: .current) ?? "never"). Publish status: \(publishStatus.rawValue). Preview content: \(previewContent ?? "none").\(hasGeneratedContent ? " Has generated content" : "")"
    }
}
