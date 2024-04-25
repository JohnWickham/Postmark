//
//  GeneratorPipelineTests.swift
//
//
//  Created by John Wickham on 4/24/24.
//

import XCTest
import FileMonitor
@testable import Postmark

final class GeneratorPipelineTests: XCTestCase {
    
    private var testContentDirectoryURL: URL {
        return FileManager.default.temporaryDirectory.appendingPathComponent("content", isDirectory: true)
    }
    
    private var databaseFileURL: URL {
        let temporaryDirectory = FileManager.default.temporaryDirectory
        return URL(fileURLWithPath: "store.sqlite", relativeTo: temporaryDirectory)
    }
    
    private var exampleContentFileURL: URL? {
        return Bundle.module.url(forResource: "Example", withExtension: "md")
    }
    
    override func setUpWithError() throws {
        try? FileManager.default.removeItem(at: testContentDirectoryURL)
        try FileManager.default.createDirectory(at: testContentDirectoryURL, withIntermediateDirectories: true)
        
       try DataStore.shared.open(databaseFile: databaseFileURL)
    }

    override func tearDownWithError() throws {
        DataStore.shared.close()
        try FileManager.default.removeItem(at: databaseFileURL)
        try FileManager.default.removeItem(at: testContentDirectoryURL)
    }
    
    // Test that content is generated when a new post folder (containing a Markdown file) is added
    func testAddedPostFolder() throws {
        // Write a test post folder outside the watched directory
        let testPostFolderTemporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-post", isDirectory: true)
        try FileManager.default.createDirectory(at: testPostFolderTemporaryURL, withIntermediateDirectories: true)
        // Copy the example Markdown file into the test post folder
        
        guard let exampleContentFileURL = exampleContentFileURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.copyItem(at: exampleContentFileURL, to: testPostFolderTemporaryURL.appendingPathComponent("test-post.md"))
        
        let countOfDatabasePostsBeforeProcessing = try DataStore.shared.getCountOfPosts()
        
        let processingDelayExpectation = expectation(description: "Wait for processing")
        
        // Start watching the content directory
        let responder = FileEventResponder(contentDirectoryURL: testContentDirectoryURL, shouldGenerateFragments: true)
        let monitor = try FileMonitor(directory: testContentDirectoryURL, delegate: responder, options: nil)
        try monitor.start()
        
        // Move the test post folder inside the watched content directory
        let testPostFolderInContentDirectoryURL = testContentDirectoryURL.appending(path: "test-post", directoryHint: .isDirectory)
        try FileManager.default.moveItem(at: testPostFolderTemporaryURL, to: testPostFolderInContentDirectoryURL)
        
        // Wait for processing to finish (?)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            processingDelayExpectation.fulfill()
        }
        wait(for: [processingDelayExpectation])
        
        // Assert that an HTML fragment file was produced in the tset post folder
        let generatedContentFileURL = testContentDirectoryURL.appendingPathComponent("test-post", isDirectory: true).appendingPathComponent("index.html")
        assert(FileManager.default.fileExists(atPath: generatedContentFileURL.path))
        
        // Assert that a post row was added to the database
        let countOfDatabasePostsAfterProcessing = try DataStore.shared.getCountOfPosts()
        assert(countOfDatabasePostsAfterProcessing == countOfDatabasePostsBeforeProcessing + 1)
    }
    
    // Test that a content folder with a publish status directive is processed properly
    func testAddPostDraftFolder() throws {
    }
    
    // Test that content is generated when a new Markdown file is added to an existing folder
    func testAddedPostFile() throws {
        // Create a test post folder inside the watched content directory
        let testPostFolderInContentDirectoryURL = testContentDirectoryURL.appending(path: "test-post", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: testPostFolderInContentDirectoryURL, withIntermediateDirectories: true)
        
        let countOfDatabasePostsBeforeProcessing = try DataStore.shared.getCountOfPosts()
        
        let processingDelayExpectation = expectation(description: "Wait for processing")
        
        // Start watching the content directory
        let responder = FileEventResponder(contentDirectoryURL: testContentDirectoryURL, shouldGenerateFragments: true)
        let monitor = try FileMonitor(directory: testContentDirectoryURL, delegate: responder, options: [.markSelf])
        try monitor.start()
        
        // Move the sample content file into the post folder
        guard let exampleContentFileURL = exampleContentFileURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.copyItem(at: exampleContentFileURL, to: testPostFolderInContentDirectoryURL.appendingPathComponent("test-post.md"))
        
        // Wait for processing to finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            processingDelayExpectation.fulfill()
        }
        wait(for: [processingDelayExpectation])
        
        // Assert that an HTML fragment file was produced in the tset post folder
        let generatedContentFileURL = testContentDirectoryURL.appendingPathComponent("test-post", isDirectory: true).appendingPathComponent("index.html")
        assert(FileManager.default.fileExists(atPath: generatedContentFileURL.path))
        
        // Assert that a post row was added to the database
        let countOfDatabasePostsAfterProcessing = try DataStore.shared.getCountOfPosts()
        assert(countOfDatabasePostsAfterProcessing == countOfDatabasePostsBeforeProcessing + 1)
    }
    
    // Test that a content file added directly to the watched content directory is moved into a proper post folder and processed properly
    func testAddedOrphanContentFile() {
        
    }
    
    func testModifiedPostFile() throws {
        // Create a test post folder inside the watched content directory
        let testPostFolderInContentDirectoryURL = testContentDirectoryURL.appending(path: "test-post", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: testPostFolderInContentDirectoryURL, withIntermediateDirectories: true)
        
        // Move the sample content file into the post folder
        guard let exampleContentFileURL = exampleContentFileURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        let exampleContentFileInPostFolderURL = testPostFolderInContentDirectoryURL.appendingPathComponent("test-post.md")
        try FileManager.default.copyItem(at: exampleContentFileURL, to: exampleContentFileInPostFolderURL)
        
        let artificialDelayExpectation = expectation(description: "Artifically delay so that test-setup FSEvents aren't handled.")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            artificialDelayExpectation.fulfill()
        }
        wait(for: [artificialDelayExpectation])
        
        let countOfDatabasePostsBeforeProcessing = try DataStore.shared.getCountOfPosts()
        
        let processingDelayExpectation = expectation(description: "Wait for processing")
        
        // Start watching the content directory
        let responder = FileEventResponder(contentDirectoryURL: testContentDirectoryURL, shouldGenerateFragments: true)
        let monitor = try FileMonitor(directory: testContentDirectoryURL, delegate: responder, options: nil)
        try monitor.start()
        
        let contentToAppend = UUID().uuidString;
        let fileHandle = try FileHandle(forWritingTo: exampleContentFileInPostFolderURL)
        try fileHandle.seekToEnd()
        try fileHandle.write(contentsOf: contentToAppend.data(using: .utf8)!)
        try fileHandle.close()
        
        // Wait for processing to finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            processingDelayExpectation.fulfill()
        }
        wait(for: [processingDelayExpectation])
        
        // Assert that an HTML fragment file was produced in the tset post folder
        let generatedContentFileURL = testContentDirectoryURL.appendingPathComponent("test-post", isDirectory: true).appendingPathComponent("index.html")
        assert(FileManager.default.fileExists(atPath: generatedContentFileURL.path))
        
        let generatedContentFileText = try String(contentsOf: generatedContentFileURL, encoding: .utf8)
        assert(generatedContentFileText.contains(contentToAppend))
        
        // Assert that a post row was added to the database
        let countOfDatabasePostsAfterProcessing = try DataStore.shared.getCountOfPosts()
        assert(countOfDatabasePostsAfterProcessing == countOfDatabasePostsBeforeProcessing + 1)
    }
    
    // Test that the post is removed from the database when a post file is deleted (but the directory remains)
    func testPostFileDeleted() throws {
        // Create a test post folder inside the watched content directory
        let testPostFolderInContentDirectoryURL = testContentDirectoryURL.appending(path: "test-post", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: testPostFolderInContentDirectoryURL, withIntermediateDirectories: true)
        
        let countOfDatabasePostsBeforeProcessing = try DataStore.shared.getCountOfPosts()
        
        let addProcessingDelayExpectation = expectation(description: "Wait for processing of added file")
        let deleteProcessingDelayExpectation = expectation(description: "Wait for processing of removed file")
        
        // Start watching the content directory
        let responder = FileEventResponder(contentDirectoryURL: testContentDirectoryURL, shouldGenerateFragments: true)
        let monitor = try FileMonitor(directory: testContentDirectoryURL, delegate: responder, options: nil)
        try monitor.start()
        
        // Move the sample content file into the post folder
        guard let exampleContentFileURL = exampleContentFileURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.copyItem(at: exampleContentFileURL, to: testPostFolderInContentDirectoryURL.appendingPathComponent("test-post.md"))
        
        // Wait for processing to finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            addProcessingDelayExpectation.fulfill()
        }
        wait(for: [addProcessingDelayExpectation])
        
        // Assert that an HTML fragment file was produced in the tset post folder
        let generatedContentFileURL = testContentDirectoryURL.appendingPathComponent("test-post", isDirectory: true).appendingPathComponent("index.html")
        assert(FileManager.default.fileExists(atPath: generatedContentFileURL.path))
        
        // Assert that a post row was added to the database
        let countOfDatabasePostsAfterProcessing = try DataStore.shared.getCountOfPosts()
        assert(countOfDatabasePostsAfterProcessing == countOfDatabasePostsBeforeProcessing + 1)
        
        // Delete the sample content file from the post folder
        try FileManager.default.removeItem(at: exampleContentFileURL)
        
        // Check that the post is removed from the database
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            deleteProcessingDelayExpectation.fulfill()
        }
        wait(for: [deleteProcessingDelayExpectation])
        
        let countOfDatabasePostsAfterDeleting = try DataStore.shared.getCountOfPosts()
        assert(countOfDatabasePostsAfterDeleting == countOfDatabasePostsAfterProcessing - 1)
        
    }
    
    // Test that the post is removed from teh databse when a post folder (containing a Markdown file) is deleted
    func testPostFolderDeleted() throws {
        // Create a test post folder inside the watched content directory
        let testPostFolderInContentDirectoryURL = testContentDirectoryURL.appending(path: "test-post", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: testPostFolderInContentDirectoryURL, withIntermediateDirectories: true)
        
        // Move the sample content file into the post folder
        guard let exampleContentFileURL = exampleContentFileURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        let exampleContentFileInPostFolderURL = testPostFolderInContentDirectoryURL.appendingPathComponent("test-post.md")
        
        let artificialDelayExpectation = expectation(description: "Artifically delay so that test-setup FSEvents aren't handled.")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            artificialDelayExpectation.fulfill()
        }
        wait(for: [artificialDelayExpectation])
        
        let countOfDatabasePostsBeforeProcessing = try DataStore.shared.getCountOfPosts()
        
        let addProcessingDelayExpectation = expectation(description: "Wait for processing after adding")
        let deleteProcessingDelayExpectatino = expectation(description: "Wait for processing after deleting")
        
        // Start watching the content directory
        let responder = FileEventResponder(contentDirectoryURL: testContentDirectoryURL, shouldGenerateFragments: true)
        let monitor = try FileMonitor(directory: testContentDirectoryURL, delegate: responder, options: nil)
        try monitor.start()
        
        try FileManager.default.copyItem(at: exampleContentFileURL, to: exampleContentFileInPostFolderURL)
        
        // Wait for processing to finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            addProcessingDelayExpectation.fulfill()
        }
        wait(for: [addProcessingDelayExpectation])
        
        // Assert that a post row was added to the database
        let countOfDatabasePostsAfterProcessing = try DataStore.shared.getCountOfPosts()
        assert(countOfDatabasePostsAfterProcessing == countOfDatabasePostsBeforeProcessing + 1)
        
        // Delete the post folder
        try FileManager.default.removeItem(at: testPostFolderInContentDirectoryURL)
        
        // Wait for processing to finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            deleteProcessingDelayExpectatino.fulfill()
        }
        wait(for: [deleteProcessingDelayExpectatino])
        
        let countOfDatabasePostsAfterDeleting = try DataStore.shared.getCountOfPosts()
        assert(countOfDatabasePostsAfterDeleting == countOfDatabasePostsAfterProcessing - 1)
        
    }
    
}
