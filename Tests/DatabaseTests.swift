//
//  DatabaseTests.swift
//  Postmark
//
//  Created by John Wickham on 4/21/24.
//

import Postmark
import XCTest

final class DatabaseTests: XCTestCase {

    private var databaseFileURL: URL {
        let temporaryDirectory = FileManager.default.temporaryDirectory
        return URL(fileURLWithPath: "postmark.sqlite", relativeTo: temporaryDirectory)
    }
    
    // TODO: Populate the database with a set of test data
    private static let testTopics = [
        Topic(slug: "example-topic-one", title: "Example Topic One"),
        Topic(slug: "example-topic-two", title: "Example Topic Two")
    ]
    private static let testPost = Post(slug: "example-post", title: "Example Post", topics: DatabaseTests.testTopics, createdDate: Date(), publishStatus: .public)
    
    override func setUpWithError() throws {
       try DataStore.shared.open(databaseFile: databaseFileURL)
    }

    override func tearDownWithError() throws {
        DataStore.shared.close()
        try FileManager.default.removeItem(at: databaseFileURL)
    }

    func testInsertPost() throws {
        let postCountAtStart = try DataStore.shared.getCountOfPosts()
        try DataStore.shared.addOrUpdate(DatabaseTests.testPost)
        let postCountAfterInsert = try DataStore.shared.getCountOfPosts()
        assert(postCountAfterInsert == postCountAtStart + 1)
    }
    
    func testUpdatePost() throws {
        let postCountAtStart = try DataStore.shared.getCountOfPosts()
        try DataStore.shared.addOrUpdate(DatabaseTests.testPost)
        
        let postCopy = DatabaseTests.testPost
        let newTitle = "New Title!"
        postCopy.title = newTitle
        try DataStore.shared.addOrUpdate(postCopy)
        
        let postsCountAfterUpdate = try DataStore.shared.getCountOfPosts()
        assert(postsCountAfterUpdate == postCountAtStart + 1)
        assert(postsCountAfterUpdate == 1)
        
        // TODO: Assert that the one post in the database has the updated title
    }
    
    func testDeletePost() throws {
        let postCountAtStart = try DataStore.shared.getCountOfPosts()
        try DataStore.shared.addOrUpdate(DatabaseTests.testPost)
        
        let postCountAfterInsert = try DataStore.shared.getCountOfPosts()
        assert(postCountAfterInsert == postCountAtStart + 1)
        
        let postSlug = DatabaseTests.testPost.slug
        try DataStore.shared.delete(postWith: postSlug)
        
        let postCountAfterDelete = try DataStore.shared.getCountOfPosts()
        assert(postCountAfterDelete == postCountAfterInsert - 1)
        
        // TODO: Test topics as part of this
    }

}
