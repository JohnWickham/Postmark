//
//  MarkdownFile.swift
//
//
//  Created by John Wickham on 4/14/24.
//

import Foundation
import Ink
import SwiftSoup

enum MarkdownDocumentError: Error {
    case failedToRead(fileAtURL: URL)
}

public struct MarkdownFile {
    
    let fileURL: URL
    
    public let parsedContent: Markdown
    
    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        
        guard let fileContent = try? String(contentsOf: fileURL) else {
            throw MarkdownDocumentError.failedToRead(fileAtURL: fileURL)
        }
        
        // TODO: Add a modifier to .headings to add `id`s so that anchors can references specific headings.
        
        let codeSyntaxHighlightingModifier = Modifier(target: .codeBlocks) { html, markdown in
            // TODO: Perform syntax highlighting
                // Determine the language by reading the code-block opening line to see if a language is specified
                // Write tokenizers for the languages I need: Swift, HTML, JS/TS, CSS/SCSS
                // Apply the matching tokenizer if one exists, otherwise do nothing
            return html
        }
        
        let parser = MarkdownParser(modifiers: [codeSyntaxHighlightingModifier])
        self.parsedContent = parser.parse(fileContent)
    }
    
    public var metadata: [String : String]? {
        return parsedContent.metadata
    }
    
    public func markupRepresentation(fragment: Bool) -> String? {
        let parsedMarkup = parsedContent.html
                
        do {
            let markupDocument = try SwiftSoup.parseBodyFragment(parsedMarkup)
            let firstHeadingElement = try markupDocument.select("h1").first
            
            if fragment {
                if firstHeadingElement != nil {
                    try markupDocument.body()?.removeChild(firstHeadingElement!)
                }
                
                return try markupDocument.body()?.html()
            }
            else {
                // TODO: The <!DOCTYPE> directive isn’t strictly necessary for HTML to validate, but would be nice to add.
                
                if firstHeadingElement != nil,
                   let firstHeadingText = try? firstHeadingElement?.text() {
                    try markupDocument.title(firstHeadingText)
                }
                
                return try markupDocument.html()
            }
            
        }
        catch {
            Log.shared.error("Failed to parse markup for document: \(error)")
        }
        
        return nil
    }
    
    // The text content of the first paragraph or span element in the parsed markup, truncated to 30 words.
    public var truncatedBodyContent: String? {
        guard let markupRepresentation = markupRepresentation(fragment: true) else {
            return nil
        }
        
        do {
            let markupDocument = try SwiftSoup.parse(markupRepresentation)
            let firstParagraphElement = try markupDocument.select("p").first
            let bodyContent = try firstParagraphElement?.text(trimAndNormaliseWhitespace: true)
            return bodyContent?.leadingWords(30)
        }
        catch {
            Log.shared.error("Couldn't find suitable body content in document markup.")
            return nil
        }
        
    }
    
}
