import Foundation
import XCTest

func makeTemporaryDirectory(named name: String = UUID().uuidString) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("postmark-tests", isDirectory: true)
        .appendingPathComponent(name, isDirectory: true)
    
    try? FileManager.default.removeItem(at: directory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

func waitForCondition(
    timeout: TimeInterval = 5,
    pollInterval: TimeInterval = 0.05,
    _ condition: @escaping () -> Bool
) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    
    while Date() < deadline {
        if condition() {
            return true
        }
        Thread.sleep(forTimeInterval: pollInterval)
    }
    
    return condition()
}

func writePost(
    in contentDirectory: URL,
    folderName: String,
    fileName: String? = nil,
    markdown: String
) throws -> (postDirectory: URL, markdownFile: URL) {
    let postDirectory = contentDirectory.appendingPathComponent(folderName, isDirectory: true)
    try FileManager.default.createDirectory(at: postDirectory, withIntermediateDirectories: true)
    
    let markdownFile = postDirectory.appendingPathComponent(fileName ?? "\(folderName).md")
    try markdown.write(to: markdownFile, atomically: true, encoding: .utf8)
    
    return (postDirectory, markdownFile)
}

func XCTAssertFileExists(_ fileURL: URL, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "Expected file to exist at \(fileURL.path)", file: file, line: line)
}
