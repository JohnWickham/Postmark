//
//  PostFilesHelper.swift
//
//
//  Created by John Wickham on 4/13/24.
//

import Foundation

enum PostFilesError: Error {
    case noSuitableSlugCharacters(directoryURL: URL)
    case noContentSourceFile(inDirectory: URL)
}

struct PostFileSet {
    let contentDirectoryURL: URL
    let postDirectoryURL: URL
    let sourceMarkdownFileURL: URL
    let staticContentFileURL: URL
    let slug: String
    let publishStatus: Post.PublishStatus
}

struct PostFilesHelper {

    var contentDirectoryURL: URL

    func getContainingDirectory(for file: URL) -> URL? {
        return file.deletingLastPathComponent()
    }

    /* Whether a URL is a directory that represents a post. */
    func isPostFolder(_ fileURL: URL, skipDirectoryCheck: Bool = false) throws -> Bool {

        if !skipDirectoryCheck {
            // 1. It's a directory
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                Log.shared.trace("File is not a directory: \(fileURL)")
                return false
            }
        }

        // 2. It's a direct child of the content directory
        let contentDirectoryContents = try FileManager.default.contentsOfDirectory(at: contentDirectoryURL.standardizedFileURL, includingPropertiesForKeys: [URLResourceKey.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants])

        let postFolderPath = fileURL.standardizedFileURL.path
        let contentDirectoryPaths = contentDirectoryContents.map { $0.standardizedFileURL.path }
        guard contentDirectoryPaths.contains(postFolderPath) else {
            Log.shared.trace("Directory \(fileURL.standardizedFileURL) is not in the content directory: \(contentDirectoryURL)")
            return false
        }

        // 3. It contains a Markdown file
        if firstMarkdownFile(in: fileURL.standardizedFileURL) == nil {
            Log.shared.debug("Directory does not contain a Markdown file: \(fileURL)")
            return false
        }

        return true
    }

    func makePostSlug(for postDirectory: URL) throws -> String {
        // Delete the path extension so that slugs don't include publication directives like ".draft"
        let postDirectoryName = postDirectory.deletingPathExtension().lastPathComponent
        guard let slug = postDirectoryName.makeSlug() else {
            throw PostFilesError.noSuitableSlugCharacters(directoryURL: postDirectory)
        }
        return slug
    }

    // Determine the publish status for a post at the given directory
    func makePostPublishStatus(for postDirectory: URL) -> Post.PublishStatus {
        switch postDirectory.pathExtension {
        case "draft":
            return .draft
        case "private", "hidden":
            return .private
        default:
            return .public
        }
    }

    /* Whether a URL is a post's source Markdown file. */
    func isPostSourceContentFile(fileURL: URL) throws -> Bool {
        guard let parentDirectory = getContainingDirectory(for: fileURL) else {
            return false
        }
        let isParentPostFolder = try isPostFolder(parentDirectory)
        return isParentPostFolder && fileURL.pathExtension == "md"
    }

    // Finds the first accessible file of type "md" in the given URL, or none
    private func firstMarkdownFile(in directory: URL) -> URL? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            Log.shared.trace("Can't find a markdown file in URL that is not a directory: \(directory)")
            return nil
        }

        let contents = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .localizedNameKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])
        return contents?.sorted { lhs, rhs in
            lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
        }.first { fileURL in
            fileURL.path.hasSuffix(".md") && FileManager.default.isReadableFile(atPath: fileURL.path)
        }
    }

    // Returns nil if no readable content source file exists
    public func getContentSourceFile(forPostAt postURL: URL) -> URL? {
        do {
            if try isPostFolder(postURL) {
                return firstMarkdownFile(in: postURL)
            }
            else {
                Log.shared.debug("Requested content source file from directory that is not a post: \(postURL)")
            }
        }
        catch {
            Log.shared.error("Error determining whether directory is a post: \(error.localizedDescription)")
        }

        return nil
    }

    public func makeStaticContentFileURL(forPostAt postURL: URL) -> URL? {
        return postURL.appendingPathComponent("index.html")
    }

    public func makePostFileSet(forPostAt postURL: URL) throws -> PostFileSet {
        guard let sourceMarkdownFileURL = getContentSourceFile(forPostAt: postURL),
              let staticContentFileURL = makeStaticContentFileURL(forPostAt: postURL) else {
            throw PostFilesError.noContentSourceFile(inDirectory: postURL)
        }

        return PostFileSet(
            contentDirectoryURL: contentDirectoryURL,
            postDirectoryURL: postURL,
            sourceMarkdownFileURL: sourceMarkdownFileURL,
            staticContentFileURL: staticContentFileURL,
            slug: try makePostSlug(for: postURL),
            publishStatus: makePostPublishStatus(for: postURL)
        )
    }

    /* Every directory in the content directory containing a Markdown file. */
    public var postDirectories: [URL] {
        do {
            let contentDirectoryContents = try FileManager.default.contentsOfDirectory(at: contentDirectoryURL.standardizedFileURL, includingPropertiesForKeys: [URLResourceKey.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants])
            Log.shared.debug("Found \(contentDirectoryContents.count) items in content directory: \(contentDirectoryContents.debugDescription)")
            return contentDirectoryContents.filter { return (try? isPostFolder($0)) ?? false }
        }
        catch {
            Log.shared.debug("Failed to find post directories in \(contentDirectoryURL.standardizedFileURL): \(error.localizedDescription)")
            return []
        }
    }

}
