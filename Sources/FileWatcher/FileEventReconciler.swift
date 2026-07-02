//
//  FileEventReconciler.swift
//  Postmark
//
//  Created by John Wickham on 6/3/25.
//

import Foundation

final class FileEventReconciler {
    private var folderEvents: [String: FileChangeKind] = [:]
    private var dispatchTimer: DispatchSourceTimer?
    private let debounceInterval: TimeInterval = 0.2
    private let queue = DispatchQueue(label: "Postmark.FileEventReconciler")

    var onReconciledEvents: (([FileChangeEvent]) -> Void)?

    func enqueue(_ event: FileChangeEvent) {
        queue.async {
            let folderPath = URL(fileURLWithPath: event.path).deletingLastPathComponent().path
            let current = self.folderEvents[folderPath]

            switch event.kind {
            case .removed:
                self.folderEvents[folderPath] = .removed
            case .created:
                if current != .removed {
                    self.folderEvents[folderPath] = .created
                }
            case .modified:
                if current == nil {
                    self.folderEvents[folderPath] = .modified
                }
            }

            self.resetTimer()
        }
    }

    private func resetTimer() {
        dispatchTimer?.cancel()
        dispatchTimer = DispatchSource.makeTimerSource(queue: queue)
        dispatchTimer?.schedule(deadline: .now() + debounceInterval)
        dispatchTimer?.setEventHandler { [weak self] in
            self?.flush()
        }
        dispatchTimer?.resume()
    }

    private func flush() {
        let events = folderEvents.map { FileChangeEvent(path: $0.key, kind: $0.value) }
        folderEvents.removeAll()
        onReconciledEvents?(events)
    }
}
