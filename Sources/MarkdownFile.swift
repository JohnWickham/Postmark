//
//  MarkdownFile.swift
//
//
//  Created by John Wickham on 4/14/24.
//

import Foundation
import Ink
import SwiftHTMLParser

struct MarkdownFile {
    
    let fileURL: URL
    
    private var fileContent: String? {
        Log.shared.trace("Reading Markdown file: \(fileURL)")
        return try? String(contentsOf: fileURL)
    }
    
    private let parser = MarkdownParser()
    
    public var parsedContent: Markdown? {
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
    
    // Finds the first paragraph or span element in the parsed markdup document
    public var bodyContent: String? {
        guard let markupRepresentation = markupRepresentation,
              let nodeTree = try? HTMLParser.parse(markupRepresentation) else {
            return nil
        }
        
        let nodeSelectors = [ElementSelector().withTagName("p"), ElementSelector().withTagName("span")]
        let matchingElements = HTMLTraverser.findElements(in: nodeTree, matching: nodeSelectors)
        return matchingElements.first?.textNodes.first?.text
    }
    
    // The text content of the first paragraph or span element in the parsed markup, truncated to 30 words.
    public var truncatedBodyContent: String? {
        guard let bodyContent = bodyContent else {
            return nil
        }
        
        return bodyContent.split(separator: " ").prefix(upTo: 31).joined(separator: " ")
    }
    
}
