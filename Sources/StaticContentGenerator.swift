//
//  StaticContentGenerator.swift
//
//
//  Created by John Wickham on 4/14/24.
//

import Foundation

enum StaticContentGenerationError: Error {
    case noContentSourceFile(inDirectory: URL)
}

public struct StaticContentGenerator {
    
    public let contentDirectory: URL
    
    public func generateStaticContent(for post: Post, overwriteExisting: Bool = true) {
        Log.shared.trace("Generating static content for post: \(post.slug)")
        
        let postFilesHelper = PostFilesHelper(contentDirectoryURL: contentDirectory)
        let staticContentFilePath = postFilesHelper.makeStaticContentFileURL(forPostWith: post.slug)
        
        do {
            guard let contentSourceFilePath = postFilesHelper.getContentSourceFile(forPostWith: post.slug) else {
                throw StaticContentGenerationError.noContentSourceFile(inDirectory: contentDirectory)
            }
            let markdownFile = MarkdownFile(fileURL: contentSourceFilePath)
            
            if FileManager.default.fileExists(atPath: staticContentFilePath.path) {
                
                let canDeleteFile = FileManager.default.isDeletableFile(atPath: staticContentFilePath.path)
                
                if overwriteExisting && canDeleteFile {
                    Log.shared.trace("Deleting static content file: \(staticContentFilePath.path())")
                    try FileManager.default.removeItem(at: staticContentFilePath)
                }
                else if overwriteExisting && !canDeleteFile {
                    Log.shared.error("Existing static content file could not be deleted. Nothing will be generated.")
                    return
                }
                else {
                    Log.shared.trace("Static content file already exists, but generator was told not to overwrite. Nothing will be generated.")
                    return
                }
            }
            
            Log.shared.trace("Writing markup to file: \(staticContentFilePath)")
            try markdownFile.markupRepresentation?.write(to: staticContentFilePath, atomically: true, encoding: .utf8)
            
            post.hasGeneratedContent = true
            try DataStore.shared.addOrUpdate(post)
        }
        catch {
            // TODO: Propagate this error somehow?
            Log.shared.error("Error while generating static content for post: \(error.localizedDescription)")
        }
    }
}
