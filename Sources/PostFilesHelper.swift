//
//  PostFilesHelper.swift
//  
//
//  Created by John Wickham on 4/13/24.
//

import Foundation

enum PostFilesError: Error {
    case noSuitableSlugCharacters(directoryURL: URL)
}

struct PostFilesHelper {
    
    var contentDirectoryURL: URL
    
    private static let slugSafeCharacters = CharacterSet(charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-")
    
    func getContainingDirectory(for file: URL) -> URL? {
        let parent = file.deletingLastPathComponent()
        guard parent.isDirectory else {
            return nil
        }
        return parent
    }
    
    /* Whether a URL is a directory that represents a post. */
    func isPostFolder(_ fileURL: URL) throws -> Bool {
        
        // 1. It's a directory
        guard fileURL.isDirectory else {
            Log.shared.debug("File is not a directory: \(fileURL)")
            return false
        }
        
        // 2. It's a direct child of the content directory
        let contentDirectoryContents = try FileManager.default.contentsOfDirectory(at: contentDirectoryURL.standardizedFileURL, includingPropertiesForKeys: [URLResourceKey.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants])
        
        guard contentDirectoryContents.contains(fileURL.standardizedFileURL) else {
            Log.shared.debug("Directory is not in the content directory: \(fileURL)")
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
        let postDirectoryName = postDirectory.lastPathComponent
        if let latin = postDirectoryName.applyingTransform(StringTransform("Any-Latin; Latin-ASCII;"), reverse: false) {
            let urlComponents = latin.components(separatedBy: PostFilesHelper.slugSafeCharacters.inverted)
            let result = urlComponents.filter { $0 != "" }.joined(separator: "-")

            if result.count > 0 {
                return result
            }
        }
        
        throw PostFilesError.noSuitableSlugCharacters(directoryURL: postDirectory)
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
        guard directory.isDirectory else {
            Log.shared.trace("Can't find a markdown file in URL that is not a directory: \(directory)")
            return nil
        }
        
        let contents = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .localizedNameKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])
        return contents?.first { fileURL in
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
    
    // Returns nil if no readable content source file exists
    public func getContentSourceFile(forPostWith slug: String) -> URL? {
        let postDirectoryURL = contentDirectoryURL.appending(path: slug, directoryHint: .isDirectory)
        return getContentSourceFile(forPostAt: postDirectoryURL)
    }
    
    public func makeStaticContentFileURL(forPostAt postURL: URL) -> URL? {
        return postURL.appendingPathComponent("index.html")
    }
    
    public func makeStaticContentFileURL(forPostWith slug: String) -> URL {
        return contentDirectoryURL.appending(path: slug, directoryHint: .isDirectory).appendingPathComponent("index.html")
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
