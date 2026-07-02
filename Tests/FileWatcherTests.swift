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
    private var watcher: FileWatcher!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testDirectoryURL = try makeTemporaryDirectory()
        watcher = makeWatcher()
    }
    
    override func tearDownWithError() throws {
        watcher?.stopWatching()
        try? FileManager.default.removeItem(at: testDirectoryURL)
        watcher = nil
        testDirectoryURL = nil
        try super.tearDownWithError()
    }
    
    func testFileCreated() throws {
        let expectation = XCTestExpectation(description: "File creation event received")

        let testFileURL = testDirectoryURL.appendingPathComponent("test.txt")

        watcher.onEvent = { event in
            if self.event(event, matches: testFileURL, kind: .created) {
                expectation.fulfill()
            }
        }

        watcher.startWatching()

        let contents = "Hello, Postmark!".data(using: .utf8)!
        FileManager.default.createFile(atPath: testFileURL.path, contents: contents)

        wait(for: [expectation], timeout: 2.0)
    }
    
    func testFileDeleted() throws {
        let testFileURL = testDirectoryURL.appendingPathComponent("deleted.txt")
        FileManager.default.createFile(atPath: testFileURL.path, contents: Data())
        let expectation = XCTestExpectation(description: "File deletion event received")
        
        watcher.onEvent = { event in
            if self.event(event, matches: testFileURL, kind: .removed) {
                expectation.fulfill()
            }
        }
        
        watcher.startWatching()
        try FileManager.default.removeItem(at: testFileURL)
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testFileModified() throws {
        let testFileURL = testDirectoryURL.appendingPathComponent("modified.txt")
        try "Before".write(to: testFileURL, atomically: true, encoding: .utf8)
        let expectation = XCTestExpectation(description: "File modification event received")
        
        watcher.onEvent = { event in
            if self.event(event, matches: testFileURL, kind: .modified) {
                expectation.fulfill()
            }
        }
        
        watcher.startWatching()
        Thread.sleep(forTimeInterval: 0.3)
        let fileHandle = try FileHandle(forWritingTo: testFileURL)
        try fileHandle.seekToEnd()
        try fileHandle.write(contentsOf: Data(" After".utf8))
        try fileHandle.close()
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testSubdirectoryCreated() throws {
        let subdirectoryURL = testDirectoryURL.appendingPathComponent("subdirectory", isDirectory: true)
        let expectation = XCTestExpectation(description: "Subdirectory creation event received")
        
        watcher.onEvent = { event in
            if self.event(event, matches: subdirectoryURL, kind: .created) {
                expectation.fulfill()
            }
        }
        
        watcher.startWatching()
        try FileManager.default.createDirectory(at: subdirectoryURL, withIntermediateDirectories: true)
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testRecursiveWatchAfterSubdirectoryCreated() throws {
        let subdirectoryURL = testDirectoryURL.appendingPathComponent("subdirectory", isDirectory: true)
        let nestedFileURL = subdirectoryURL.appendingPathComponent("nested.txt")
        let subdirectoryExpectation = XCTestExpectation(description: "Subdirectory creation event received")
        let nestedFileExpectation = XCTestExpectation(description: "Nested file creation event received")
        
        watcher.onEvent = { event in
            if self.event(event, matches: subdirectoryURL, kind: .created) {
                subdirectoryExpectation.fulfill()
            }
            if self.event(event, matches: nestedFileURL, kind: .created) {
                nestedFileExpectation.fulfill()
            }
        }
        
        watcher.startWatching()
        try FileManager.default.createDirectory(at: subdirectoryURL, withIntermediateDirectories: true)
        wait(for: [subdirectoryExpectation], timeout: 2.0)
        
        FileManager.default.createFile(atPath: nestedFileURL.path, contents: Data())
        
        wait(for: [nestedFileExpectation], timeout: 2.0)
    }
    
    func testIgnoresUnrelatedDirectories() throws {
        let unrelatedDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: unrelatedDirectory) }
        let unrelatedFileURL = unrelatedDirectory.appendingPathComponent("unrelated.txt")
        let expectation = XCTestExpectation(description: "No unrelated-directory event received")
        expectation.isInverted = true
        
        watcher.onEvent = { event in
            let eventPath = URL(fileURLWithPath: event.path).standardizedFileURL
            if eventPath.path.hasPrefix(unrelatedDirectory.standardizedFileURL.path) {
                expectation.fulfill()
            }
        }
        
        watcher.startWatching()
        FileManager.default.createFile(atPath: unrelatedFileURL.path, contents: Data())
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    func testHandlesMultipleEvents() throws {
        let firstFileURL = testDirectoryURL.appendingPathComponent("first.txt")
        let secondFileURL = testDirectoryURL.appendingPathComponent("second.txt")
        #if os(macOS)
        let folderExpectation = XCTestExpectation(description: "Coalesced folder creation event received")
        #elseif os(Linux)
        let firstExpectation = XCTestExpectation(description: "First creation event received")
        let secondExpectation = XCTestExpectation(description: "Second creation event received")
        #endif
        
        watcher.onEvent = { event in
            #if os(macOS)
            if self.event(event, matches: firstFileURL, kind: .created) {
                folderExpectation.fulfill()
            }
            #elseif os(Linux)
            if self.event(event, matches: firstFileURL, kind: .created) {
                firstExpectation.fulfill()
            }
            if self.event(event, matches: secondFileURL, kind: .created) {
                secondExpectation.fulfill()
            }
            #endif
        }
        
        watcher.startWatching()
        FileManager.default.createFile(atPath: firstFileURL.path, contents: Data())
        FileManager.default.createFile(atPath: secondFileURL.path, contents: Data())
        
        #if os(macOS)
        wait(for: [folderExpectation], timeout: 1.0)
        #else
        wait(for: [firstExpectation, secondExpectation], timeout: 2.0)
        #endif
    }
    
    private func makeWatcher() -> FileWatcher {
        #if os(macOS)
        return FSEventsWatcher(path: testDirectoryURL.path)
        #elseif os(Linux)
        return InotifyWatcher(path: testDirectoryURL.path)
        #endif
    }
    
    private func event(_ event: FileChangeEvent, matches fileURL: URL, kind: FileChangeKind) -> Bool {
        guard event.kind == kind else {
            return false
        }
        
        let eventPath = URL(fileURLWithPath: event.path).standardizedFileURL
        
        #if os(macOS)
        return eventPath == expectedMacOSEventURL(for: fileURL)
        #elseif os(Linux)
        return eventPath == fileURL.standardizedFileURL
        #endif
    }
    
    private func expectedMacOSEventURL(for fileURL: URL) -> URL {
        if (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            return fileURL.deletingLastPathComponent().standardizedFileURL
        }
        
        return fileURL.deletingLastPathComponent().standardizedFileURL
    }
}
