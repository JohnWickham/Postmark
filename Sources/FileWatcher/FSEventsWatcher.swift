//
//  FSEventsWatcher.swift
//  Postmark
//
//  Created by John Wickham on 6/3/25.
//

#if os(macOS)
import Foundation
import CoreServices

final class FSEventsWatcher: FileWatcher {
    
    private let rootPath: String
    private var stream: FSEventStreamRef?
    private let reconciler: FileEventReconciler = FileEventReconciler()
    var onEvent: ((FileChangeEvent) -> Void)?

    init(path: String) {
        self.rootPath = path
        reconciler.onReconciledEvents = { [weak self] events in
            for event in events {
                self?.onEvent?(event)
            }
        }
    }

    func startWatching() {
        let callback: FSEventStreamCallback = { streamRef, clientCallBackInfo, numEvents, eventPathsPointer, eventFlagsPointer, eventIdsPointer in
            guard let clientCallBackInfo = clientCallBackInfo else {
                return
            }
            let eventPaths = unsafeBitCast(eventPathsPointer, to: NSArray.self) as! [String]
            let eventFlags = UnsafeBufferPointer(start: eventFlagsPointer, count: numEvents)

            for (index, path) in eventPaths.enumerated() {
                let flag = eventFlags[index]
                let kind: FileChangeKind
                
                if flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0 {
                    kind = .created
                } else if flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0 {
                    kind = .removed
                } else if flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified) != 0 {
                    kind = .modified
                } else {
                    continue
                }

                let event = FileChangeEvent(path: path, kind: kind)
                let watcher = Unmanaged<FSEventsWatcher>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
                watcher.reconciler.enqueue(event)
            }
        }

        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [rootPath] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes |
                                      kFSEventStreamCreateFlagFileEvents |
                                      kFSEventStreamCreateFlagWatchRoot)
        ) else {
            return
        }

        self.stream = stream
        let queue = DispatchQueue(label: "com.postmark.fsevents")
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    func stopWatching() {
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }
}
#endif
