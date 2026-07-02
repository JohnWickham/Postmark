//
//  StaticContentGeneratorTests.swift
//
//
//  Created by John Wickham on 4/21/24.
//

import postmark
import XCTest

final class StaticContentGeneratorTests: XCTestCase {
    
    private var testDirectoryURL: URL!
    private var testPostDirectoryURL: URL!
    private static let testPost = Post(slug: "example-post", title: "Example Post", topics: [], createdDate: Date(), publishStatus: .public)
    
    override func setUpWithError() throws {
        testDirectoryURL = try makeTemporaryDirectory()
        testPostDirectoryURL = testDirectoryURL.appendingPathComponent("example-post", isDirectory: true)
        try FileManager.default.createDirectory(at: testPostDirectoryURL, withIntermediateDirectories: true)
        guard let exampleContentFileURL = Bundle.module.url(forResource: "Example", withExtension: "md") else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.copyItem(at: exampleContentFileURL, to: testPostDirectoryURL.appendingPathComponent("Example.md"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: testDirectoryURL)
        testDirectoryURL = nil
        testPostDirectoryURL = nil
    }
    
    func testGeneratingStaticFragment() throws {
        let generator = StaticContentGenerator(contentDirectory: testPostDirectoryURL)
        let markdownFile = try MarkdownFile(fileURL: testPostDirectoryURL.appendingPathComponent("Example.md"))
        let generatedMarkup = markdownFile.markupRepresentation(fragment: true)
        
        try generator.generateStaticContent(for: StaticContentGeneratorTests.testPost, with: markdownFile, fragment: true)
        
        let generatedFileURL = testPostDirectoryURL.appendingPathComponent("index.html")
        XCTAssertFileExists(generatedFileURL)
        
        let generatedFileContent = try String(contentsOf: generatedFileURL)
        XCTAssertEqual(generatedFileContent, generatedMarkup)
        XCTAssertFalse(generatedFileContent.contains("<html>"))
    }
    
    func testGeneratingStaticFullyFormed() throws {
        let generator = StaticContentGenerator(contentDirectory: testPostDirectoryURL)
        let markdownFile = try MarkdownFile(fileURL: testPostDirectoryURL.appendingPathComponent("Example.md"))
        let generatedMarkup = markdownFile.markupRepresentation(fragment: false)
        
        try generator.generateStaticContent(for: StaticContentGeneratorTests.testPost, with: markdownFile, fragment: false)
        
        let generatedFileURL = testPostDirectoryURL.appendingPathComponent("index.html")
        XCTAssertFileExists(generatedFileURL)
        
        let generatedFileContent = try String(contentsOf: generatedFileURL)
        XCTAssertEqual(generatedFileContent, generatedMarkup)
        XCTAssertTrue(generatedFileContent.contains("<html>"))
        XCTAssertTrue(generatedFileContent.contains("<title>"))
    }
    
    func testOverwritesExistingStaticContent() throws {
        let generator = StaticContentGenerator(contentDirectory: testPostDirectoryURL)
        let markdownFile = try MarkdownFile(fileURL: testPostDirectoryURL.appendingPathComponent("Example.md"))
        let generatedFileURL = testPostDirectoryURL.appendingPathComponent("index.html")
        try "stale content".write(to: generatedFileURL, atomically: true, encoding: .utf8)
        
        try generator.generateStaticContent(for: StaticContentGeneratorTests.testPost, with: markdownFile, fragment: true)
        
        let generatedFileContent = try String(contentsOf: generatedFileURL)
        XCTAssertNotEqual(generatedFileContent, "stale content")
        XCTAssertEqual(generatedFileContent, markdownFile.markupRepresentation(fragment: true))
    }
    
}
