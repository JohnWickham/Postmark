//
//  FileWatcher.swift
//  Postmark
//
//  Created by John Wickham on 6/3/25.
//

enum FileChangeKind {
    case created
    case modified
    case removed
}

struct FileChangeEvent {
    let path: String
    let kind: FileChangeKind
}

protocol FileWatcher: AnyObject {
    /// Start watching the specified directory and all subdirectories.
    func startWatching()

    /// Stop watching and clean up resources.
    func stopWatching()

    /// Called when a file or folder changes.
    var onEvent: ((FileChangeEvent) -> Void)? { get set }
}
