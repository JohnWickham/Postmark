//
//  File.swift
//
//
//  Created by John Wickham on 4/13/24.
//

import Foundation
import SQLite

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

    func getPost(with slug: String) throws -> Post? {
        let postQuery = postsTable.filter(slugColumn == slug)
        guard let row = try connection.pluck(postQuery) else {
            return nil
        }
        let createdDateStringColumn = Expression<String>("createdDate")
        let updatedDateStringColumn = Expression<String?>("updatedDate")

        return Post(
            slug: row[slugColumn],
            title: row[titleColumn],
            topics: try getTopics(forPostWith: slug),
            createdDate: DataStore.date(fromStoredString: row[createdDateStringColumn]) ?? Date(),
            updatedDate: DataStore.date(fromStoredString: row[updatedDateStringColumn]),
            publishStatus: Post.PublishStatus(rawValue: row[publishStatusColumn]) ?? .public,
            previewContent: row[previewContentColumm],
            hasGeneratedContent: row[hasGeneratedContentColumn]
        )
    }

    private static func date(fromStoredString string: String?) -> Date? {
        guard let string = string else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: string)
    }

    /* Updates a Post, inserting if it does not exist. */
    public func addOrUpdate(_ post: Post) throws {
        Log.shared.trace("Will insert post: \(post)")
        try connection.transaction {
            try connection.run(postsTable.upsert(post, onConflictOf: slugColumn))
            try deleteTopics(forPostWith: post.slug)
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

    public func deletePosts(excluding slugsToKeep: [String]) throws {
        Log.shared.trace("Deleting posts not found in regenerated content.")
        let slugsToKeep = Set(slugsToKeep)
        try connection.transaction {
            for row in try connection.prepare(postsTable.select(slugColumn)) {
                let slug = row[slugColumn]
                if !slugsToKeep.contains(slug) {
                    let postToDelete = postsTable.filter(slugColumn == slug)
                    try connection.run(postToDelete.delete())
                }
            }
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
        let relationships = postTopicRelationshipTable.filter(postSlugRelationColumn == slug)
        try connection.run(relationships.delete())
    }

    func getTopics(forPostWith slug: String) throws -> [Topic] {
        let relationshipRows = try connection.prepare(postTopicRelationshipTable.filter(postSlugRelationColumn == slug))
        var topics: [Topic] = []

        for relationshipRow in relationshipRows {
            let topicSlug = relationshipRow[topicSlugRelationColumn]
            if let topicRow = try connection.pluck(topicsTable.filter(slugColumn == topicSlug)) {
                topics.append(Topic(slug: topicRow[slugColumn], title: topicRow[titleColumn]))
            }
        }

        return topics
    }

    // MARK: Post-Topic Relationship

    public func addTopicRelationship(topicSlug: String, postSlug: String) throws {
        Log.shared.trace("Will add relationship for topic \(topicSlug) to post \(postSlug)")

        do {
            try connection.run(postTopicRelationshipTable.insert(postSlugRelationColumn <- postSlug, topicSlugRelationColumn <- topicSlug))
        }
        catch let Result.error(_, code, _) where code == 19 {// SQLITE_CONSTRAINT
            Log.shared.debug("Relationship between topic \(topicSlug) and post \(postSlug) already exists.")
        }
    }



}
