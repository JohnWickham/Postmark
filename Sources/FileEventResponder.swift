//
//  FileEventResponder.swift
//
//
//  Created by John Wickham on 4/24/24.
//

import FileMonitor
import Foundation

public struct FileEventResponder: FileDidChangeDelegate {
    
    public var contentDirectoryURL: URL
    public var shouldGenerateFragments: Bool
    
    public func fileDidChange(event: FileChange) {
        let fileHelper = PostFilesHelper(contentDirectoryURL: contentDirectoryURL)
        
        Log.shared.trace("File event: \(event.description)")
        
        // TODO: If an added or modified Markdown file is an "orphan" (direct child of the content directory without a containing post folder), create a post folder and move the file into it.
        
        switch event {
            case .created(file: let file, isDirectory: _),
                 .modified(file: let file, isDirectory: _):
                
                do {
                    let isPostFolder = try fileHelper.isPostFolder(file)
                    let isPostSourceFile = try fileHelper.isPostSourceContentFile(fileURL: file)
                    
                    guard isPostFolder || isPostSourceFile else {
                        Log.shared.trace("A file was added or changed, but it wasn't a post folder or post source file.")
                        return
                    }
                    
                    Log.shared.trace("Post folder or post source content file was added or changed.")
                    
                    if let postDirectory = isPostFolder ? file : fileHelper.getContainingDirectory(for: file) {
                        try processPost(in: postDirectory)
                    }
                }
                catch {
                    Log.shared.error("A file was added or changed, but an error occurred evalutating whether it was a post folder or post source content file: \(error.localizedDescription). Nothing will be done about this change.")
                    return
                }
                
            case .removed(file: let file, isDirectory: let isDirectory):
                
                let fileURL = URL(fileURLWithPath: file.absoluteString).standardizedFileURL
                
                Log.shared.trace("\(isDirectory ? "Directory" : "File") was deleted: \(file)")
                
                do {
                    
                    let isPostSourceContentFile = try fileHelper.isPostSourceContentFile(fileURL: fileURL)
                    let postSourceContentFileParent = fileHelper.getContainingDirectory(for: fileURL)
                    if isPostSourceContentFile && postSourceContentFileParent == nil {
                        Log.shared.trace("A post source content file was deleted, but the post's folder was, too. Nothing will be done about the deleted file; the deleted post folder will be handled instead.")
                        return
                    }
                    
                    let isPostFolder = try fileHelper.isPostFolder(fileURL)
                    guard isPostFolder else {
                        return
                    }
                    
                    Log.shared.debug("Post folder or source content file was deleted.")
                    
                    guard let postDirectory = fileHelper.getContainingDirectory(for: fileURL) else {
                        Log.shared.error("Post source content file was deleted, but couldn't determine the post directory. The state of the system may now be undefined. You may want to `postmark regenerate`")
                        return
                    }
                    
                    let slug = try fileHelper.makePostSlug(for: postDirectory)
                    try DataStore.shared.delete(postWith: slug)
                }
                catch {
                    Log.shared.error("A file was deleted, but an error occurred evaluating whether it was a post folder or source content file: \(error.localizedDescription). Nothing will be done about this change, but the state of the system may now be undefined. You may want to `postmark regenerate`.")
                }
                    
            case .childEvent(inFileAtPath: let filePath):
                Log.shared.debug("Child event in: \(filePath)")
                let postURL = URL(filePath: filePath)
                
                do {
                    guard try fileHelper.isPostFolder(postURL) else {
                        Log.shared.debug("Child event reported for \(filePath), but it appears not to be a post folder.")
                        return
                    }
                    
                    try processPost(in: postURL)
                }
                catch {
                    Log.shared.error("A child event was reported, but an error occurred in further processing: \(error)")
                }
        }
    }
    
    private func processPost(in postDirectory: URL) throws {
        let options: PostProcessingQueue.ProcessingOptions = shouldGenerateFragments ? [.generateFragments] : []
        let processingQueue = try PostProcessingQueue(postDirectory: postDirectory, in: contentDirectoryURL, options: options)
        try processingQueue.process()
    }
    
}
