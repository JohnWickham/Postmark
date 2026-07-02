//
//  DatabaseTests.swift
//  Postmark
//
//  Created by John Wickham on 4/21/24.
//

import XCTest
@testable import postmark

final class DatabaseTests: XCTestCase {

    private var testDirectoryURL: URL!
    private var databaseFileURL: URL!
    
    // TODO: Populate the database with a set of test data
    private static let testTopics = [
        Topic(slug: "example-topic-one", title: "Example Topic One"),
        Topic(slug: "example-topic-two", title: "Example Topic Two")
    ]
    private static let testPost = Post(slug: "example-post", title: "Example Post", topics: DatabaseTests.testTopics, createdDate: Date(), publishStatus: .public)
    
    override func setUpWithError() throws {
        testDirectoryURL = try makeTemporaryDirectory()
        databaseFileURL = testDirectoryURL.appendingPathComponent("postmark.sqlite")
        try DataStore.shared.open(databaseFile: databaseFileURL)
    }

    override func tearDownWithError() throws {
        DataStore.shared.close()
        try? FileManager.default.removeItem(at: testDirectoryURL)
        testDirectoryURL = nil
        databaseFileURL = nil
    }

    func testInsertPost() throws {
        let postCountAtStart = try DataStore.shared.getCountOfPosts()
        try DataStore.shared.addOrUpdate(DatabaseTests.testPost)
        let postCountAfterInsert = try DataStore.shared.getCountOfPosts()
        
        XCTAssertEqual(postCountAfterInsert, postCountAtStart + 1)
        
        let storedPost = try XCTUnwrap(DataStore.shared.getPost(with: DatabaseTests.testPost.slug))
        XCTAssertEqual(storedPost.slug, DatabaseTests.testPost.slug)
        XCTAssertEqual(storedPost.title, DatabaseTests.testPost.title)
        XCTAssertEqual(storedPost.publishStatus, .public)
        XCTAssertEqual(storedPost.topics?.map(\.slug).sorted(), ["example-topic-one", "example-topic-two"])
    }
    
    func testUpdatePost() throws {
        let postCountAtStart = try DataStore.shared.getCountOfPosts()
        try DataStore.shared.addOrUpdate(DatabaseTests.testPost)
        
        let postCopy = DatabaseTests.testPost
        let newTitle = "New Title!"
        postCopy.title = newTitle
        try DataStore.shared.addOrUpdate(postCopy)
        
        let postsCountAfterUpdate = try DataStore.shared.getCountOfPosts()
        XCTAssertEqual(postsCountAfterUpdate, postCountAtStart + 1)
        XCTAssertEqual(postsCountAfterUpdate, 1)
        
        let storedPost = try XCTUnwrap(DataStore.shared.getPost(with: DatabaseTests.testPost.slug))
        XCTAssertEqual(storedPost.title, newTitle)
    }
    
    func testUpdatingPostReplacesTopicRelationships() throws {
        try DataStore.shared.addOrUpdate(DatabaseTests.testPost)
        XCTAssertEqual(try DataStore.shared.getTopics(forPostWith: DatabaseTests.testPost.slug).map(\.slug).sorted(), ["example-topic-one", "example-topic-two"])
        
        let updatedPost = Post(
            slug: DatabaseTests.testPost.slug,
            title: DatabaseTests.testPost.title,
            topics: [Topic(slug: "replacement-topic", title: "Replacement Topic")],
            createdDate: DatabaseTests.testPost.createdDate,
            publishStatus: .public
        )
        try DataStore.shared.addOrUpdate(updatedPost)
        
        XCTAssertEqual(try DataStore.shared.getTopics(forPostWith: DatabaseTests.testPost.slug).map(\.slug), ["replacement-topic"])
    }
    
    func testDeletePost() throws {
        let postCountAtStart = try DataStore.shared.getCountOfPosts()
        try DataStore.shared.addOrUpdate(DatabaseTests.testPost)
        
        let postCountAfterInsert = try DataStore.shared.getCountOfPosts()
        XCTAssertEqual(postCountAfterInsert, postCountAtStart + 1)
        
        let postSlug = DatabaseTests.testPost.slug
        try DataStore.shared.delete(postWith: postSlug)
        
        let postCountAfterDelete = try DataStore.shared.getCountOfPosts()
        XCTAssertEqual(postCountAfterDelete, postCountAfterInsert - 1)
        XCTAssertNil(try DataStore.shared.getPost(with: postSlug))
    }

}
