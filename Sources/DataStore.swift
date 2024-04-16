//
//  File.swift
//  
//
//  Created by John Wickham on 4/13/24.
//

import Foundation
import SQLite

public class Topic: Codable {
    var slug: String
    var title: String
        
    init(slug: String, title: String) {
        self.slug = slug
        self.title = title
    }
}

public class DataStore {
    
    // TODO: How can we create the shared singleton instance by providing the database file URL?
    public static let shared: DataStore = DataStore()
    
    private init() {
    }
        
    private var connection: Connection!
    
    private let postsTable = Table("post")
    private let topicsTable = Table("topic")
    private let postTopicRelationshipTable = Table("post_topic")
    
    private let slugColumn = Expression<String>("slug")
    private let titleColumn = Expression<String>("title")
    private let parentColumn = Expression<String?>("parent")
    private let postSlugRelationColumn = Expression<String>("postSlug")
    private let topicSlugRelationColumn = Expression<String>("topicSlug")
    private let createdDateColumn = Expression<Date>("createdDate")
    private let updatedDateColumn = Expression<Date?>("updatedDate")
    private let previewContentColumm = Expression<String?>("previewContent")
    private let hasGeneratedContentColumn = Expression<Bool?>("hasGeneratedContent")
    
    public func open(databaseFile: URL) throws {
        Log.shared.trace("Opening database connection to \(databaseFile.path)")
        connection = try Connection(databaseFile.absoluteString)
        try initializeSchema()
    }
    
    private func initializeSchema() throws {
        Log.shared.trace("Initializing database")
        
        // Create Post table
        try connection.run(postsTable.create(ifNotExists: true) { table in
            table.column(slugColumn, primaryKey: true)
            table.column(titleColumn)
            table.column(createdDateColumn)
            table.column(updatedDateColumn)
            table.column(previewContentColumm)
            table.column(hasGeneratedContentColumn)
        })
        
        // Create Topic table
        try connection.run(topicsTable.create(ifNotExists: true) { table in
            table.column(slugColumn)
            table.column(titleColumn)
            table.column(parentColumn)
        })
        
        // Create Post-Topic relationship table
        try connection.run(postTopicRelationshipTable.create(ifNotExists: true) { table in
            table.column(postSlugRelationColumn)
            table.column(topicSlugRelationColumn)
            
            table.foreignKey(postSlugRelationColumn, references: postsTable, slugColumn)
            table.foreignKey(topicSlugRelationColumn, references: topicsTable, slugColumn)
        })
    }
    
    /* MARK: Public functions */
    
    public var posts: [Post] {
        get {
            return (try? connection.prepare(postsTable).compactMap { row in
                return try? row.decode() as Post
            } as [Post]) ?? []
        }
    }
    
    public var topics: [Topic] {
        get {
            return (try? connection.prepare(topicsTable).compactMap { row in
                return try? row.decode() as Topic
            } as [Topic]) ?? []
        }
    }
    
    // MARK: Posts
    
    /* Updates a Post, inserting if it does not exist. */
    public func addOrUpdate(_ post: Post) throws {
        Log.shared.trace("Will inset post with slug: \(post.slug)")
        try connection.run(postsTable.upsert(post, onConflictOf: slugColumn))
    }
    
    public func replaceAll(_ posts: [Post]) throws {
        try connection.transaction {
            try connection.run(postTopicRelationshipTable.delete())
            try connection.run(postsTable.delete())
            try connection.run(postsTable.insertMany(posts))
        }
    }
    
    public func deleteAllPosts() throws {
        Log.shared.trace("Deleting all posts.")
        try connection.transaction {
            try connection.run(postTopicRelationshipTable.delete())
            try connection.run(postsTable.delete())
        }
    }
    
    /* Deletes a Post and any relationships to Topics. */
    public func delete(_ post: Post) throws {
        Log.shared.trace("Deleting post: \(post)")
        let postToDelete = postsTable.filter(slugColumn == post.slug)
        let topicRelationships = postTopicRelationshipTable.filter(postSlugRelationColumn == post.slug)
        try connection.run(topicRelationships.delete())
        try connection.run(postToDelete.delete())
    }
    
    public func getPost(by slug: String) -> Post? {
        let postsQuery = postsTable.where(slugColumn == slug)
        // TODO: Join topics
        return try? connection.prepare(postsQuery).map { row in
            return try row.decode() as Post
        }.first
    }
    
    // MARK: Topics
    
    /* Updates a Topic, inserting if it does not exist. */
    public func addOrUpdate(_ topic: Topic) throws {
        try connection.run(topicsTable.upsert(topic, onConflictOf: slugColumn))
    }
    
    /* Deletes a Topic and any relationships to Posts. */
    public func delete(_ topic: Topic) throws {
        Log.shared.trace("Deleting topic: \(topic)")
        let topicToDelete = topicsTable.filter(slugColumn == topic.slug)
        let postRelationships = postTopicRelationshipTable.filter(topicSlugRelationColumn == topic.slug)
        try connection.run(postRelationships.delete())
        try connection.run(topicToDelete.delete())
    }
    
    public func getTopic(by slug: String) -> Topic? {
        let topicsQuery = topicsTable.where(slugColumn == slug)
        return try? connection.prepare(topicsQuery).map { row in
            return try row.decode() as Topic
        }.first
    }
    
    // MARK: Relationships
    
    public func topics(for post: Post) throws -> [Topic] {
        // FIXME: The topicsTable does not have a postSlugRelationColumn; you need to join tables.
        let topicsQuery = topicsTable.where(postSlugRelationColumn == post.slug)
        return (try? connection.prepare(topicsQuery).compactMap { row in
            return try? row.decode() as Topic
        } as [Topic]) ?? []
    }
    
    public func posts(for topic: Topic) throws -> [Post] {
        // FIXME: The postsTable does not have a topicSlugRelationColumn; you need to join tables.
        let postsQuery = postsTable.where(topicSlugRelationColumn == topic.slug)
        return (try? connection.prepare(postsQuery).compactMap { row in
            return try? row.decode() as Post
        } as [Post]) ?? []
    }
}
