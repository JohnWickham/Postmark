//
//  File.swift
//  
//
//  Created by John Wickham on 4/13/24.
//

import Foundation
import SQLite
import SQLite3

public class DataStore {
    
    public static let shared: DataStore = DataStore()
    
    private init() {
    }
        
    private var connection: Connection!
    
    private let postsTable = Table("posts")
    private let topicsTable = Table("topics")
    private let postTopicRelationshipTable = Table("post_topic")
    
    private let slugColumn = Expression<String>("slug")
    private let titleColumn = Expression<String>("title")
    private let parentColumn = Expression<String?>("parent")
    private let postSlugRelationColumn = Expression<String>("postSlug")
    private let topicSlugRelationColumn = Expression<String>("topicSlug")
    private let createdDateColumn = Expression<Date>("createdDate")
    private let updatedDateColumn = Expression<Date?>("updatedDate")
    private let publishStatusColumn = Expression<String>("publishStatus")
    private let previewContentColumm = Expression<String?>("previewContent")
    private let hasGeneratedContentColumn = Expression<Bool?>("hasGeneratedContent")
    
    public func open(databaseFile: URL) throws {
        Log.shared.trace("Opening database file: \(databaseFile.path)")
        connection = try Connection(databaseFile.absoluteString)
        try initializeSchema()
    }
    
    public func close() {
        // SQLite.swift automatically closes the database connection when it's deallocated
        connection = nil
    }
    
    private func initializeSchema() throws {
        Log.shared.trace("Initializing database")
        
        // Create Post table
        try connection.run(postsTable.create(ifNotExists: true) { table in
            table.column(slugColumn, primaryKey: true)
            table.column(titleColumn)
            table.column(createdDateColumn)
            table.column(updatedDateColumn)
            table.column(publishStatusColumn)
            table.column(previewContentColumm)
            table.column(hasGeneratedContentColumn)
        })
        
        // Create Topic table
        try connection.run(topicsTable.create(ifNotExists: true) { table in
            table.column(slugColumn, primaryKey: true)
            table.column(titleColumn)
            table.column(parentColumn)
        })
        
        // Create Post-Topic relationship table
        try connection.run(postTopicRelationshipTable.create(ifNotExists: true) { table in
            table.column(postSlugRelationColumn)
            table.column(topicSlugRelationColumn)
            
            table.foreignKey(postSlugRelationColumn, references: postsTable, slugColumn, delete: .cascade)
            table.foreignKey(topicSlugRelationColumn, references: topicsTable, slugColumn, delete: .cascade)
            
            table.primaryKey(postSlugRelationColumn, topicSlugRelationColumn)
        })
    }
    
    /* MARK: Public functions */
    
    // MARK: Posts
    
    public func getCountOfPosts() throws -> Int {
        return try connection.scalar(postsTable.count)
    }
    
    /* Updates a Post, inserting if it does not exist. */
    public func addOrUpdate(_ post: Post) throws {
        Log.shared.trace("Will insert post: \(post)")
        try connection.transaction {
            try connection.run(postsTable.upsert(post, onConflictOf: slugColumn))
            if let topics = post.topics {
                for topic in topics {
                    try addOrUpdate(topic)
                    try addTopicRelationship(topicSlug: topic.slug, postSlug: post.slug)
                }
            }
        }
    }
    
    public func deleteAllPosts() throws {
        Log.shared.trace("Deleting all posts.")
        try connection.transaction {
            try connection.run(postsTable.delete())
        }
    }
    
    public func delete(postWith slug: String) throws {
        let postToDelete = postsTable.filter(slugColumn == slug)
        try connection.run(postToDelete.delete())
    }
    
    // MARK: Topics
    
    /* Updates a Topic, inserting if it does not exist. */
    public func addOrUpdate(_ topic: Topic) throws {
        Log.shared.trace("Will insert topic: \(topic)")
        try connection.run(topicsTable.upsert(topic, onConflictOf: slugColumn))
    }
    
    public func deleteTopics(forPostWith slug: String) throws {
        Log.shared.trace("Will delete topics for post: \(slug)")
        let topics = postTopicRelationshipTable.join(topicsTable, on: postSlugRelationColumn == slugColumn)
        try connection.run(topics.delete())
    }
    
    // MARK: Post-Topic Relationship
    
    public func addTopicRelationship(topicSlug: String, postSlug: String) throws {
        Log.shared.trace("Will add relationship for topic \(topicSlug) to post \(postSlug)")
       
        do {
            try connection.run(postTopicRelationshipTable.insert(postSlugRelationColumn <- postSlug, topicSlugRelationColumn <- topicSlug))
        }
        catch let Result.error(_, code, _) where code == SQLITE_CONSTRAINT {
            Log.shared.debug("Relationship between topic \(topicSlug) and post \(postSlug) already exists.")
        }
    }
    
    
    
}
