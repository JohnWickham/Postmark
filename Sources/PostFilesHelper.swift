//
//  PostFilesHelper.swift
//  
//
//  Created by John Wickham on 4/13/24.
//

import Foundation

struct PostFilesHelper {
    
    var contentDirectoryURL: URL
    
    private static let slugSafeCharacters = CharacterSet(charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-")
    
    /* Whether a URL is a directory that represents a post. */
    func isPostFolder(_ fileURL: URL) throws -> Bool {
        
        // 1. It's a directory
        guard fileURL.isDirectory else {
            Log.shared.debug("File is not a directory: \(fileURL)")
            return false
        }
        
        // 2. It's a direct child of the content directory
        let contentDirectoryContents = try FileManager.default.contentsOfDirectory(at: contentDirectoryURL.standardized, includingPropertiesForKeys: [URLResourceKey.isDirectoryKey])
        
        guard contentDirectoryContents.contains(fileURL) else {
            Log.shared.debug("Directory is not in the content directory: \(fileURL)")
            return false
        }
        
        // 3. It contains a Markdown file at its top level
        let contents = try FileManager.default.contentsOfDirectory(at: fileURL.standardized, includingPropertiesForKeys: nil)
        let containsMarkdownFile = contents.contains { filePath in
            let fileURL = URL(fileURLWithPath: filePath.standardized.path)
            return fileURL.pathExtension == "md"
        }
        
        if !containsMarkdownFile {
            Log.shared.debug("Directory does not contain a Markdown file: \(fileURL)")
        }
        
        return containsMarkdownFile
    }
    
    // TODO: Add function to get post folder by slug
    
    func postSlug(for postDirectory: URL) throws -> String {
        let postDirectoryName = postDirectory.lastPathComponent
        if let latin = postDirectoryName.applyingTransform(StringTransform("Any-Latin; Latin-ASCII; Lower;"), reverse: false) {
            let urlComponents = latin.components(separatedBy: PostFilesHelper.slugSafeCharacters.inverted)
            let result = urlComponents.filter { $0 != "" }.joined(separator: "-")

            if result.count > 0 {
                return result
            }
        }
        
        return UUID().uuidString
    }
    
    /* Whether a URL is a post's meta JSON file. */
    func isPostMetaFile(fileURL: URL) throws -> Bool {
        let parentDirectory = fileURL.deletingLastPathComponent()
        let isParentPostFolder = try isPostFolder(parentDirectory)
        return isParentPostFolder && fileURL.lastPathComponent == "meta.json"
    }
    
    func getMetaFile(forPostWith slug: String) -> URL {
        return contentDirectoryURL.appending(path: slug, directoryHint: .isDirectory).appendingPathComponent("meta", conformingTo: .json)
    }
    
    /* Whether a URL is a post's source Markdown file. */
    func isPostSourceContentFile(fileURL: URL) throws -> Bool {
        let parentDirectory = fileURL.deletingLastPathComponent()
        let isParentPostFolder = try isPostFolder(parentDirectory)
        return isParentPostFolder && fileURL.pathExtension == "md"
    }
    
    func getContentSourceFile(forPostWith slug: String) -> URL {
        return contentDirectoryURL.appending(path: slug, directoryHint: .isDirectory).appendingPathComponent("\(slug).md")
    }
    
    /* Every directory in the content directory containing a Markdown file. */
    public var postDirectories: [URL] {
        do {
            let contentDirectoryContents = try FileManager.default.contentsOfDirectory(at: contentDirectoryURL.standardized, includingPropertiesForKeys: [URLResourceKey.isDirectoryKey])
            Log.shared.debug("Found items in content directory: \(contentDirectoryContents.debugDescription)")
            return contentDirectoryContents.filter { return (try? isPostFolder($0)) ?? false }
        }
        catch {
            Log.shared.debug("Failed to find post directories: \(error.localizedDescription)")
            return []
        }
    }
    
}
