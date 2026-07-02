//
//  InotifyWatcher.swift
//  Postmark
//
//  Created by John Wickham on 6/3/25.
//

#if os(Linux)
import Dispatch
import Foundation
import Glibc

final class InotifyWatcher: FileWatcher {
    private let rootPath: String
    private var fileDescriptor: Int32 = -1
    private var watchDescriptors: [Int32: String] = [:]
    var onEvent: ((FileChangeEvent) -> Void)?

    init(path: String) {
        self.rootPath = path
    }

    func startWatching() {
        fileDescriptor = inotify_init1(Int32(IN_NONBLOCK))
        guard fileDescriptor != -1 else { return }

        addWatchesRecursively(at: rootPath)

        DispatchQueue.global(qos: .utility).async { [weak self] in
            var buffer = [UInt8](repeating: 0, count: 4096)
            while let strongSelf = self, strongSelf.fileDescriptor != -1 {
                let bytesRead = read(strongSelf.fileDescriptor, &buffer, buffer.count)
                if bytesRead <= 0 {
                    usleep(10_000)
                    continue
                }

                var offset = 0
                while offset < bytesRead {
                    let event = withUnsafePointer(to: &buffer[offset]) {
                        $0.withMemoryRebound(to: inotify_event.self, capacity: 1) {
                            $0.pointee
                        }
                    }

                    if let path = strongSelf.watchDescriptors[event.wd] {
                        let nameOffset = offset + MemoryLayout<inotify_event>.size
                        let fileName = buffer.withUnsafeBufferPointer { bufferPointer in
                            String(cString: bufferPointer.baseAddress!.advanced(by: nameOffset).withMemoryRebound(to: CChar.self, capacity: Int(event.len)) { $0 })
                        }
                        let fullPath = fileName.isEmpty ? path : "\(path)/\(fileName)"
                        let kind: FileChangeKind

                        if event.mask & UInt32(IN_CREATE | IN_MOVED_TO) != 0 {
                            kind = .created
                        } else if event.mask & UInt32(IN_DELETE | IN_MOVED_FROM | IN_DELETE_SELF | IN_MOVE_SELF) != 0 {
                            kind = .removed
                        } else if event.mask & UInt32(IN_MODIFY | IN_CLOSE_WRITE | IN_ATTRIB) != 0 {
                            kind = .modified
                        } else {
                            offset += Int(event.len) + MemoryLayout<inotify_event>.size
                            continue
                        }

                        strongSelf.onEvent?(FileChangeEvent(path: fullPath, kind: kind))

                        if event.mask & UInt32(IN_ISDIR) != 0 && kind == .created {
                            strongSelf.addWatchesRecursively(at: fullPath)
                        }
                    }

                    offset += Int(event.len) + MemoryLayout<inotify_event>.size
                }
            }
        }
    }

    func stopWatching() {
        if fileDescriptor != -1 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
        watchDescriptors.removeAll()
    }
    
    private func addWatchesRecursively(at path: String) {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
            if let wd = addWatch(at: path) {
                watchDescriptors[wd] = path
            }

            if let contents = try? FileManager.default.contentsOfDirectory(atPath: path) {
                for entry in contents {
                    addWatchesRecursively(at: "\(path)/\(entry)")
                }
            }
        }
    }

    private func addWatch(at path: String) -> Int32? {
        let mask = UInt32(IN_CREATE | IN_DELETE | IN_MODIFY | IN_MOVED_TO | IN_MOVED_FROM | IN_CLOSE_WRITE | IN_ATTRIB | IN_DELETE_SELF | IN_MOVE_SELF)
        let wd = inotify_add_watch(fileDescriptor, path, mask)
        return wd != -1 ? wd : nil
    }
}
#endif
