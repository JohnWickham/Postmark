//
//  FileEventResponder.swift
//
//
//  Created by John Wickham on 4/24/24.
//

import Foundation

public struct FileEventResponder {
    
    public var contentDirectoryURL: URL
    public var shouldGenerateFragments: Bool
    
    public func fileDidChange() {
        Log.shared.debug("Received a file change without event details.")
    }
    
    func handle(_ event: FileChangeEvent) {
        let fileHelper = PostFilesHelper(contentDirectoryURL: contentDirectoryURL)
        let fileURL = URL(fileURLWithPath: event.path).standardizedFileURL
        
        do {
            switch event.kind {
            case .created, .modified:
                guard let postDirectory = try postDirectoryToProcess(forChangedFileAt: fileURL, fileHelper: fileHelper) else {
                    Log.shared.trace("Changed file is not a post folder or post source file: \(fileURL.path)")
                    return
                }
                
                Log.shared.debug("Processing changed post at: \(postDirectory.path)")
                try processPost(in: postDirectory)
                
            case .removed:
                guard let postDirectory = postDirectoryToDelete(forRemovedFileAt: fileURL, fileHelper: fileHelper) else {
                    Log.shared.trace("Removed file is not a post folder or post source file: \(fileURL.path)")
                    return
                }
                
                let slug = try fileHelper.makePostSlug(for: postDirectory)
                Log.shared.debug("Deleting removed post from database: \(slug)")
                try DataStore.shared.delete(postWith: slug)
            }
        }
        catch {
            Log.shared.error("Failed to handle file event \(event.kind) at \(fileURL.path): \(error)")
        }
    }
    
    private func processPost(in postDirectory: URL) throws {
        let options: PostProcessingQueue.ProcessingOptions = shouldGenerateFragments ? [.generateFragments] : []
        let processingQueue = try PostProcessingQueue(postDirectory: postDirectory, in: contentDirectoryURL, options: options)
        try processingQueue.process()
    }
    
    private func postDirectoryToProcess(forChangedFileAt fileURL: URL, fileHelper: PostFilesHelper) throws -> URL? {
        if try isExistingDirectory(fileURL), try fileHelper.isPostFolder(fileURL, skipDirectoryCheck: true) {
            return fileURL
        }
        
        guard fileURL.pathExtension == "md",
              let parentDirectory = fileHelper.getContainingDirectory(for: fileURL),
              try fileHelper.isPostFolder(parentDirectory, skipDirectoryCheck: true) else {
            return nil
        }
        
        return parentDirectory
    }
    
    private func postDirectoryToDelete(forRemovedFileAt fileURL: URL, fileHelper: PostFilesHelper) -> URL? {
        guard let parentDirectory = fileHelper.getContainingDirectory(for: fileURL) else {
            return nil
        }
        
        if parentDirectory.standardizedFileURL == contentDirectoryURL.standardizedFileURL {
            return fileURL
        }
        
        if fileURL.pathExtension == "md",
           parentDirectory.deletingLastPathComponent().standardizedFileURL == contentDirectoryURL.standardizedFileURL {
            return parentDirectory
        }
        
        return nil
    }
    
    private func isExistingDirectory(_ fileURL: URL) throws -> Bool {
        let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
        return resourceValues.isDirectory == true
    }
    
}
