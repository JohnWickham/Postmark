//
//  Post.swift
//
//
//  Created by John Wickham on 4/14/24.
//

import Foundation

enum PostFileAnalysisError: Error {
    case notADirectory(_ url: URL)
    case noCreationDate(directory: URL)
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
    init(describing directory: URL) throws {
        guard directory.isDirectory else {
            throw PostFileAnalysisError.notADirectory(directory)
        }
        
        let fileManager = FileManager()
        let directoryAttributes = try fileManager.attributesOfItem(atPath: directory.path)
        
        guard let directoryCreationDate = directoryAttributes[FileAttributeKey.creationDate] as? Date else {
            throw PostFileAnalysisError.noCreationDate(directory: directory)
        }
        
        self.slug = directory.lastPathComponent
        self.title = "Example Post Title" // TODO: Initialize the title by parsing the Markdown source file and selecting the first heading
        self.createdDate = directoryCreationDate
//        self.topics = [] // TODO: Initialize topics by parsing the post's meta file and querying Topics
    }
}
