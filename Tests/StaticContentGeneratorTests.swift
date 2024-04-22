//
//  StaticContentGeneratorTests.swift
//
//
//  Created by John Wickham on 4/21/24.
//

import Postmark
import XCTest

final class StaticContentGeneratorTests: XCTestCase {
    
    private static var testPostDirectoryURL: URL {
        return FileManager.default.temporaryDirectory.appending(component: "example-post")
    }
    
    private static let testPost = Post(slug: "example-post", title: "Example Post", topics: [], createdDate: Date(), publishStatus: .public)
    
    override func setUpWithError() throws {
        try deleteExistingContents()
        try FileManager.default.createDirectory(at: StaticContentGeneratorTests.testPostDirectoryURL, withIntermediateDirectories: true)
        guard let exampleContentFileURL = Bundle.module.url(forResource: "Example", withExtension: "md") else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.copyItem(at: exampleContentFileURL, to: StaticContentGeneratorTests.testPostDirectoryURL.appending(path: "Example.md"))
    }

    override func tearDownWithError() throws {
        try deleteExistingContents()
    }
    
    func deleteExistingContents() throws {
        if FileManager.default.fileExists(atPath: StaticContentGeneratorTests.testPostDirectoryURL.path) {
            try FileManager.default.removeItem(at: StaticContentGeneratorTests.testPostDirectoryURL)
        }
    }
    
    func testGeneratingStaticFragment() throws {
        let generator = StaticContentGenerator(contentDirectory: StaticContentGeneratorTests.testPostDirectoryURL)
        let markdownFile = try MarkdownFile(fileURL: StaticContentGeneratorTests.testPostDirectoryURL.appending(path: "Example.md"))
        let generatedMarkup = markdownFile.markupRepresentation(fragment: true)
        
        self.measure {
            do {
                try generator.generateStaticContent(for: StaticContentGeneratorTests.testPost, with: markdownFile, fragment: true)
                
                let generatedFileURL = StaticContentGeneratorTests.testPostDirectoryURL.appending(path: "index.html")
                let doesGeneratedFileExist = FileManager.default.fileExists(atPath: generatedFileURL.path)
                assert(doesGeneratedFileExist)
                
                let generatedFileContent = try String(contentsOf: generatedFileURL)
                assert(generatedFileContent == generatedMarkup)
                assert(!generatedFileContent.contains("<html>"))
            }
            catch {
                XCTFail("Error generating static content: \(error)")
            }
        }
    }
    
    func testGeneratingStaticFullyFormed() throws {
        let generator = StaticContentGenerator(contentDirectory: StaticContentGeneratorTests.testPostDirectoryURL)
        let markdownFile = try MarkdownFile(fileURL: StaticContentGeneratorTests.testPostDirectoryURL.appending(path: "Example.md"))
        let generatedMarkup = markdownFile.markupRepresentation(fragment: false)
        
        self.measure {
            do {
                try generator.generateStaticContent(for: StaticContentGeneratorTests.testPost, with: markdownFile, fragment: false)
                
                let generatedFileURL = StaticContentGeneratorTests.testPostDirectoryURL.appending(path: "index.html")
                let doesGeneratedFileExist = FileManager.default.fileExists(atPath: generatedFileURL.path)
                assert(doesGeneratedFileExist)
                
                let generatedFileContent = try String(contentsOf: generatedFileURL)
                assert(generatedFileContent == generatedMarkup)
                assert(generatedFileContent.contains("<html>"))
                assert(generatedFileContent.contains("<title>"))
            }
            catch {
                XCTFail("Error generating static content: \(error)")
            }
        }
    }
    
}
