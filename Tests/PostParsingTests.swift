import XCTest
@testable import postmark

final class PostParsingTests: XCTestCase {
    
    private var testDirectoryURL: URL!
    private var contentDirectoryURL: URL!
    
    override func setUpWithError() throws {
        testDirectoryURL = try makeTemporaryDirectory()
        contentDirectoryURL = testDirectoryURL.appendingPathComponent("content", isDirectory: true)
        try FileManager.default.createDirectory(at: contentDirectoryURL, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: testDirectoryURL)
        testDirectoryURL = nil
        contentDirectoryURL = nil
    }
    
    func testMetadataOverridesInferredPostFields() throws {
        let postFiles = try writePost(
            in: contentDirectoryURL,
            folderName: "metadata-post.private",
            markdown: """
            ---
            title: Metadata Title
            created: 2024-04-21
            updated: 2024-04-22
            preview: Custom preview.
            topics: Swift, Static Sites, Publishing Notes
            status: draft
            ---
            
            # Heading Title
            
            Body preview from markdown.
            """
        )
        
        let markdownFile = try MarkdownFile(fileURL: postFiles.markdownFile)
        let post = try Post(describing: postFiles.postDirectory, markdownFile: markdownFile)
        
        XCTAssertEqual(post.slug, "metadata-post")
        XCTAssertEqual(post.title, "Metadata Title")
        XCTAssertEqual(post.previewContent, "Custom preview.")
        XCTAssertEqual(post.publishStatus, .draft)
        XCTAssertEqual(post.topics?.map(\.slug).sorted(), ["publishing-notes", "static-sites", "swift"])
        XCTAssertDate(post.createdDate, matchesYear: 2024, month: 4, day: 21)
        XCTAssertDate(try XCTUnwrap(post.updatedDate), matchesYear: 2024, month: 4, day: 22)
    }
    
    func testFolderSuffixDeterminesPublishStatusWhenMetadataDoesNotOverride() throws {
        let draftPost = try postForFolder(named: "draft-post.draft")
        let privatePost = try postForFolder(named: "private-post.private")
        let hiddenPost = try postForFolder(named: "hidden-post.hidden")
        let publicPost = try postForFolder(named: "public-post")
        
        XCTAssertEqual(draftPost.publishStatus, .draft)
        XCTAssertEqual(privatePost.publishStatus, .private)
        XCTAssertEqual(hiddenPost.publishStatus, .private)
        XCTAssertEqual(publicPost.publishStatus, .public)
    }
    
    func testPreviewContentUsesLeadingParagraphWords() throws {
        let postFiles = try writePost(
            in: contentDirectoryURL,
            folderName: "preview-post",
            markdown: """
            # Preview Post
            
            One two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty twenty-one twenty-two twenty-three twenty-four twenty-five twenty-six twenty-seven twenty-eight twenty-nine thirty thirty-one.
            """
        )
        
        let post = try Post(describing: postFiles.postDirectory, markdownFile: try MarkdownFile(fileURL: postFiles.markdownFile))
        
        XCTAssertNotNil(post.previewContent)
        #if os(macOS)
        XCTAssertLessThanOrEqual(post.previewContent?.split(separator: " ").count ?? 0, 30)
        XCTAssertFalse(post.previewContent?.contains("thirty-one") ?? true)
        #elseif os(Linux)
        XCTAssertLessThanOrEqual(post.previewContent?.count ?? 0, 175)
        #endif
    }
    
    func testSlugGenerationTransliteratesUnsafeCharacters() {
        XCTAssertEqual("Café Notes & Swift".makeSlug(), "Cafe-Notes-Swift")
        XCTAssertNil("!!!".makeSlug())
    }
    
    func testPostInitializesWhenCreationDateAttributeIsUnavailable() throws {
        let postFiles = try writePost(
            in: contentDirectoryURL,
            folderName: "date-fallback",
            markdown: """
            # Date Fallback
            
            Body.
            """
        )
        
        let post = try Post(describing: postFiles.postDirectory, markdownFile: try MarkdownFile(fileURL: postFiles.markdownFile))
        
        XCTAssertEqual(post.slug, "date-fallback")
        XCTAssertNotNil(post.updatedDate)
        XCTAssertLessThanOrEqual(post.createdDate.timeIntervalSince1970, Date().timeIntervalSince1970)
    }
    
    func testMalformedMetadataDatesFallBackToFileDates() throws {
        let postFiles = try writePost(
            in: contentDirectoryURL,
            folderName: "bad-dates",
            markdown: """
            ---
            created: not-a-date
            updated: also-not-a-date
            ---
            
            # Bad Dates
            
            Body.
            """
        )
        
        let post = try Post(describing: postFiles.postDirectory, markdownFile: try MarkdownFile(fileURL: postFiles.markdownFile))
        
        XCTAssertEqual(post.slug, "bad-dates")
        XCTAssertNotNil(post.updatedDate)
        XCTAssertLessThan(abs(post.createdDate.timeIntervalSinceNow), 60)
    }
    
    func testEmptyMarkdownPostUsesFallbacks() throws {
        let postFiles = try writePost(
            in: contentDirectoryURL,
            folderName: "empty-post",
            markdown: ""
        )
        
        let post = try Post(describing: postFiles.postDirectory, markdownFile: try MarkdownFile(fileURL: postFiles.markdownFile))
        
        XCTAssertEqual(post.title, "Untitled")
        XCTAssertNil(post.previewContent)
    }
    
    func testFirstMarkdownSourceFileIsSelectedDeterministically() throws {
        let postDirectory = contentDirectoryURL.appendingPathComponent("multiple-sources", isDirectory: true)
        try FileManager.default.createDirectory(at: postDirectory, withIntermediateDirectories: true)
        try """
        # B Source
        
        Second file.
        """.write(to: postDirectory.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)
        try """
        # A Source
        
        First file.
        """.write(to: postDirectory.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        
        let sourceFile = try XCTUnwrap(PostFilesHelper(contentDirectoryURL: contentDirectoryURL).getContentSourceFile(forPostAt: postDirectory))
        let post = try Post(describing: postDirectory, markdownFile: try MarkdownFile(fileURL: sourceFile))
        
        XCTAssertEqual(sourceFile.lastPathComponent, "a.md")
        XCTAssertEqual(post.title, "A Source")
    }
    
    private func postForFolder(named folderName: String) throws -> Post {
        let postFiles = try writePost(
            in: contentDirectoryURL,
            folderName: folderName,
            markdown: """
            # \(folderName)
            
            Body.
            """
        )
        
        return try Post(describing: postFiles.postDirectory, markdownFile: try MarkdownFile(fileURL: postFiles.markdownFile))
    }
    
    private func XCTAssertDate(_ date: Date, matchesYear year: Int, month: Int, day: Int, file: StaticString = #filePath, line: UInt = #line) {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        XCTAssertEqual(components.year, year, file: file, line: line)
        XCTAssertEqual(components.month, month, file: file, line: line)
        XCTAssertEqual(components.day, day, file: file, line: line)
    }
}
