//
//  URLParsingTests.swift
//
//
//  Created by John Wickham on 4/25/24.
//

import Foundation
import XCTest
@testable import Postmark

// This test case is more of a playground for validating URL logic. It's really only testing Foundation URL methods, it probably should be removed.

final class URLParsingTests: XCTestCase {
    
    // This would be URL.currentDirectory()
    let simulatedCurrentDirectoryURL = URL(string: "file:///Users/john/Postmark/Postmark/")!
    
    func testVariousInputResolutions() {
        
        let pathToDBFileInCurrentDirectory = "postmark.sqlite"
        let relative = URL(fileURLWithPath: pathToDBFileInCurrentDirectory, relativeTo: simulatedCurrentDirectoryURL)
        assert(relative.absoluteString == simulatedCurrentDirectoryURL
            .appending(component: "postmark.sqlite")
            .absoluteString
        )
        
        let pathToDBFileWithURLRelativeToCurrentDirectory = "../postmark.sqlite"
        let relative2 = URL(fileURLWithPath: pathToDBFileWithURLRelativeToCurrentDirectory, relativeTo: simulatedCurrentDirectoryURL)
        assert(relative2.absoluteString == simulatedCurrentDirectoryURL
            .deletingLastPathComponent()
            .appending(component: "postmark.sqlite")
            .absoluteString
        )
        
        let pathToDBFileAsRootPath = "/Users/john/Postmark/tests/postmark.sqlite"
        let absoluteURLOfDBFile = URL(fileURLWithPath: pathToDBFileAsRootPath)
        let relative3 = URL(fileURLWithPath: pathToDBFileAsRootPath, relativeTo: simulatedCurrentDirectoryURL)
        assert(relative3.absoluteString == absoluteURLOfDBFile.absoluteString)
    }
    
}
