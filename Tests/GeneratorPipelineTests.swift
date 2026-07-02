import XCTest
@testable import postmark

final class GeneratorPipelineTests: XCTestCase {

    private var testDirectoryURL: URL!
    private var contentDirectoryURL: URL!
    private var databaseFileURL: URL!
    private var responder: FileEventResponder!

    override func setUpWithError() throws {
        testDirectoryURL = try makeTemporaryDirectory()
        contentDirectoryURL = testDirectoryURL.appendingPathComponent("content", isDirectory: true)
        databaseFileURL = testDirectoryURL.appendingPathComponent("postmark.sqlite")
        try FileManager.default.createDirectory(at: contentDirectoryURL, withIntermediateDirectories: true)
        try DataStore.shared.open(databaseFile: databaseFileURL)
        responder = FileEventResponder(contentDirectoryURL: contentDirectoryURL, shouldGenerateFragments: true)
    }

    override func tearDownWithError() throws {
        DataStore.shared.close()
        try? FileManager.default.removeItem(at: testDirectoryURL)
        responder = nil
        testDirectoryURL = nil
        contentDirectoryURL = nil
        databaseFileURL = nil
    }

    func testCreatedPostFolderGeneratesFragmentAndDatabaseRow() throws {
        let post = try writePost(
            in: contentDirectoryURL,
            folderName: "hello-world",
            markdown: """
            # Hello World

            This is the body of the post.
            """
        )

        responder.handle(FileChangeEvent(path: post.postDirectory.path, kind: .created))

        let generatedFileURL = post.postDirectory.appendingPathComponent("index.html")
        XCTAssertFileExists(generatedFileURL)
        XCTAssertEqual(try String(contentsOf: generatedFileURL), "<p>This is the body of the post.</p>")

        let storedPost = try XCTUnwrap(DataStore.shared.getPost(with: "hello-world"))
        XCTAssertEqual(storedPost.title, "Hello World")
        XCTAssertEqual(storedPost.previewContent, "This is the body of the post.")
        XCTAssertEqual(storedPost.hasGeneratedContent, true)
    }

    func testModifiedPostSourceRegeneratesFragment() throws {
        let post = try writePost(
            in: contentDirectoryURL,
            folderName: "changing-post",
            markdown: """
            # Changing Post

            Original body.
            """
        )
        responder.handle(FileChangeEvent(path: post.postDirectory.path, kind: .created))

        try """
        # Changing Post

        Updated body.
        """.write(to: post.markdownFile, atomically: true, encoding: .utf8)
        responder.handle(FileChangeEvent(path: post.markdownFile.path, kind: .modified))

        let generatedFileURL = post.postDirectory.appendingPathComponent("index.html")
        XCTAssertEqual(try String(contentsOf: generatedFileURL), "<p>Updated body.</p>")

        let storedPost = try XCTUnwrap(DataStore.shared.getPost(with: "changing-post"))
        XCTAssertEqual(storedPost.previewContent, "Updated body.")
    }

    func testRemovedPostSourceDeletesDatabaseRow() throws {
        let post = try writePost(
            in: contentDirectoryURL,
            folderName: "deleted-source",
            markdown: """
            # Deleted Source

            Body.
            """
        )
        responder.handle(FileChangeEvent(path: post.postDirectory.path, kind: .created))
        XCTAssertNotNil(try DataStore.shared.getPost(with: "deleted-source"))

        try FileManager.default.removeItem(at: post.markdownFile)
        responder.handle(FileChangeEvent(path: post.markdownFile.path, kind: .removed))

        XCTAssertNil(try DataStore.shared.getPost(with: "deleted-source"))
    }

    func testRemovedPostFolderDeletesDatabaseRow() throws {
        let post = try writePost(
            in: contentDirectoryURL,
            folderName: "deleted-folder",
            markdown: """
            # Deleted Folder

            Body.
            """
        )
        responder.handle(FileChangeEvent(path: post.postDirectory.path, kind: .created))
        XCTAssertNotNil(try DataStore.shared.getPost(with: "deleted-folder"))

        try FileManager.default.removeItem(at: post.postDirectory)
        responder.handle(FileChangeEvent(path: post.postDirectory.path, kind: .removed))

        XCTAssertNil(try DataStore.shared.getPost(with: "deleted-folder"))
    }

    func testNonPostFilesAreIgnored() throws {
        let unrelatedFile = contentDirectoryURL.appendingPathComponent("notes.txt")
        try "Not Markdown".write(to: unrelatedFile, atomically: true, encoding: .utf8)

        responder.handle(FileChangeEvent(path: unrelatedFile.path, kind: .created))

        XCTAssertEqual(try DataStore.shared.getCountOfPosts(), 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: contentDirectoryURL.appendingPathComponent("index.html").path))
    }

    func testFolderPublishStatusSuffixIsStored() throws {
        let post = try writePost(
            in: contentDirectoryURL,
            folderName: "future-post.draft",
            markdown: """
            # Future Post

            Body.
            """
        )

        responder.handle(FileChangeEvent(path: post.postDirectory.path, kind: .created))

        let storedPost = try XCTUnwrap(DataStore.shared.getPost(with: "future-post"))
        XCTAssertEqual(storedPost.publishStatus, .draft)
    }

    func testDatabaseOnlyProcessingUpdatesDatabaseWithoutWritingStaticContent() throws {
        let post = try writePost(
            in: contentDirectoryURL,
            folderName: "db-only",
            markdown: """
            # Database Only

            Body.
            """
        )

        let processingQueue = try PostProcessingQueue(postDirectory: post.postDirectory, in: contentDirectoryURL, options: [.databaseOnly])
        try processingQueue.process()

        XCTAssertNotNil(try DataStore.shared.getPost(with: "db-only"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: post.postDirectory.appendingPathComponent("index.html").path))
    }

    func testProcessingReturnsStructuredResult() throws {
        let post = try writePost(
            in: contentDirectoryURL,
            folderName: "result-post",
            markdown: """
            # Result Post

            Body.
            """
        )

        let processingQueue = try PostProcessingQueue(postDirectory: post.postDirectory, in: contentDirectoryURL, options: [.generateFragments])
        let result = try processingQueue.process()

        XCTAssertEqual(result.processedSlugs, ["result-post"])
        XCTAssertTrue(result.failed.isEmpty)
    }

    func testDryRunDoesNotWriteStaticContentOrDatabaseRows() throws {
        let post = try writePost(
            in: contentDirectoryURL,
            folderName: "dry-run",
            markdown: """
            # Dry Run

            Body.
            """
        )

        let processingQueue = try PostProcessingQueue(postDirectory: post.postDirectory, in: contentDirectoryURL, options: [.dryRun])
        try processingQueue.process()

        XCTAssertNil(try DataStore.shared.getPost(with: "dry-run"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: post.postDirectory.appendingPathComponent("index.html").path))
    }
}
