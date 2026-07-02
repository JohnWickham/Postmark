//
//  FileWatcherTests.swift
//  Postmark
//
//  Created by John Wickham on 6/3/25.
//

import XCTest
@testable import postmark

final class FileWatcherTests: XCTestCase {
    
    private var testDirectoryURL: URL!

    override func setUp() {
        super.setUp()
        
        let template = "/tmp/postmark-filewatcher-tests-XXXXXX"
        var buffer = Array(template.utf8CString)
        let result = buffer.withUnsafeMutableBufferPointer { ptr -> String? in
            guard let baseAddress = ptr.baseAddress else {
                return nil
            }
            let path = mkdtemp(baseAddress)
            return path != nil ? String(cString: path!) : nil
        }
        
        guard let path = result else {
            XCTFail("Failed to create temporary directory")
            return
        }
        
        testDirectoryURL = URL(fileURLWithPath: path, isDirectory: true)
    }
    
    
    override func tearDown() {
        if let url = testDirectoryURL {
            try? FileManager.default.removeItem(at: url)
        }
        testDirectoryURL = nil
        super.tearDown()
    }
    
    func testFileCreated() {
        let expectation = XCTestExpectation(description: "File creation event received")

        let testFileName = "test.txt"
        let testFolderPath = testDirectoryURL.path
        let testFilePath = testDirectoryURL.appendingPathComponent(testFileName).path

        #if os(macOS)
        let watcher = FSEventsWatcher(path: self.testDirectoryURL.path)
        #elseif os(Linux)
        let watcher = InotifyWatcher(path: self.testDirectoryURL.path)
        #endif

        watcher.onEvent = { event in
            let eventPath = URL(fileURLWithPath: event.path).standardizedFileURL
            #if os(macOS)
            let expectedPath = URL(fileURLWithPath: testFolderPath).standardizedFileURL
            #elseif os(Linux)
            let expectedPath = URL(fileURLWithPath: testFilePath).standardizedFileURL
            #endif
            if eventPath == expectedPath && event.kind == .created {
                expectation.fulfill()
            }
        }

        watcher.startWatching()

        let contents = "Hello, Postmark!".data(using: .utf8)!
        FileManager.default.createFile(atPath: testFilePath, contents: contents)

        wait(for: [expectation], timeout: 2.0)

        watcher.stopWatching()
    }
    
    func testFileDeleted() {
        
    }
    
    func testFileModified() {
        
    }
    
    func testSubdirectoryCreated() {
        
    }
    
    func testRecursiveWatchAfterSubdirectoryCreated() {
        
    }
    
    func testIgnoresUnrelatedDirectories() {
        
    }
    
    func testHandlesMultipleEvents() {
        
    }
    
}
