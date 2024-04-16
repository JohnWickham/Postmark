//
//  MarkdownFile.swift
//
//
//  Created by John Wickham on 4/14/24.
//

import Foundation
import Ink
import SwiftSoup

public struct MarkdownFile {
    
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
    
    public func markupRepresentation(strippingFirstHeadingElement: Bool = true) -> String? {
        // TODO: Perform syntax highlighting
        guard let parsedMarkup = parsedContent?.html else {
            return nil
        }
        
        do {
            let markupDocument = try SwiftSoup.parseBodyFragment(parsedMarkup)
            if let firstHeadingElement = try markupDocument.select("h1").first {
                try markupDocument.body()?.removeChild(firstHeadingElement)
            }
            
            return try markupDocument.body()?.html()
            
        }
        catch {
            Log.shared.error("Failed to parse markup for document: \(error)")
        }
        
        return nil
    }
    
    // The text content of the first paragraph or span element in the parsed markup, truncated to 30 words.
    public var truncatedBodyContent: String? {
        guard let markupRepresentation = markupRepresentation() else {
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
