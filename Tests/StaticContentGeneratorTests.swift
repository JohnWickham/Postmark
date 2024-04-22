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
        try FileManager.default.createDirectory(at: StaticContentGeneratorTests.testPostDirectoryURL, withIntermediateDirectories: true)
        guard let exampleContentFileURL = Bundle.module.url(forResource: "Example", withExtension: "md") else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.copyItem(at: exampleContentFileURL, to: StaticContentGeneratorTests.testPostDirectoryURL.appending(path: "Example.md"))
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: StaticContentGeneratorTests.testPostDirectoryURL)
    }
    
    func testGeneratingMarkupFile() throws {
        let generator = StaticContentGenerator(contentDirectory: StaticContentGeneratorTests.testPostDirectoryURL)
        let markdownFile = try MarkdownFile(fileURL: StaticContentGeneratorTests.testPostDirectoryURL.appending(path: "Example.md"))
        let generatedMarkup = markdownFile.markupRepresentation(strippingFirstHeadingElement: true)
        
        self.measure {
            do {
                try generator.generateStaticContent(for: StaticContentGeneratorTests.testPost, with: markdownFile)
                
                let generatedFileURL = StaticContentGeneratorTests.testPostDirectoryURL.appending(path: "index.html")
                let doesGeneratedFileExist = FileManager.default.fileExists(atPath: generatedFileURL.path)
                assert(doesGeneratedFileExist)
                
                let generatedFileContent = try String(contentsOf: generatedFileURL)
                assert(generatedFileContent == generatedMarkup)
            }
            catch {
                XCTFail("Error generating static content: \(error)")
            }
        }
    }
    
}
