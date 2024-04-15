//
//  MarkdownFile.swift
//
//
//  Created by John Wickham on 4/14/24.
//

import Foundation
import Ink

struct MarkdownFile {
    
    let fileURL: URL
    
    private var fileContent: String? {
        Log.shared.trace("Reading Markdown file: \(fileURL)")
        return try? String(contentsOf: fileURL)
    }
    
    private let parser = MarkdownParser()
    
    private var parsedContent: Markdown? {
        Log.shared.trace("Parsing Markdown content")
        guard let fileContent = fileContent else {
            return nil
        }
        return parser.parse(fileContent)
    }
    
    public var metadata: [String : String]? {
        return parsedContent?.metadata
    }
    
    public var markupRepresentation: String? {
        // TODO: Perform syntax highlighting
        return parsedContent?.html
    }
    
}
