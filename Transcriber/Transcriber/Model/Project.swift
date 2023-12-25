//
//  Project.swift
//  Transcriber
//
//  Created by Daniel Kuntz on 11/25/21.
//

import Foundation

struct DebouncePropertySetter {
    static var timers: [AnyHashable: Timer] = [:]
}

class Project: Cacheable {
    private(set) var id: String = UUID().uuidString
    private(set) var lastModifiedDate: Date = Date()

    var name: String = ""                                   { didSet { cache() } }
    var needsRename: Bool = false                           { didSet { cache() } }
    var mediaType: ProjectMediaType = .audio                { didSet { cache() } }
    var audioFilename: String?                              { didSet { cache() } }
    var videoFilename: String?                              { didSet { cache() } }
    var mediaDuration: TimeInterval = 0                     { didSet { cache() } }
    var videoViewVisible: Bool = true                       { didSet { cache() } }
    var videoViewContentOffset: CGPoint?                    { didSet { cache() } }
    var videoViewZoomScale: CGFloat?                        { didSet { cache() } }
    var playheadLocation: TimeInterval = 0                  { didSet { cache() } }
    var waveformZoomScale: CGFloat = 1                      { didSet { cache() } }
    var flags: [Flag] = []                                  { didSet { cache() } }
    var loopingOn: Bool = false                             { didSet { cache() } }
    var loopRange: ClosedRange<Float>?                      { didSet { cache() } }
    var eqFreqRange: ClosedRange<Float>?                    { didSet { cache() } }
    var channelMode: AudioChannelMode = .lr                 { didSet { cache() } }
    var cents: Float = 0                                    { didSet { cache() } }
    var semitones: Float = 0                                { didSet { cache() } }
    var speed: Float = 1                                    { didSet { cache() } }

    var formattedDuration: String {
        let minutes = Int(mediaDuration / 60)
        let seconds = Int(mediaDuration.truncatingRemainder(dividingBy: 60))
        return "\(minutes)" + ":" + ((seconds < 10) ? "0" : "") + "\(seconds)"
    }

    var formattedLastModifiedDate: String {
        let secondsInDay: TimeInterval = 60 * 60 * 24
        let daysSince = Date().timeIntervalSince(lastModifiedDate) / secondsInDay

        if daysSince < 1 {
            return "Last modified today"
        } else if daysSince < 2 {
            return "Last modified yesterday"
        } else if daysSince <= 7 {
            return "Last modified \(Int(daysSince)) days ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, YYYY"
            return formatter.string(from: lastModifiedDate)
        }
    }

    var audioURL: URL? {
        guard let audioFilename = audioFilename else {
            return nil
        }

        return FileManager.getDocumentsDirectory().appendingPathComponent(audioFilename)
    }

    var videoURL: URL? {
        guard let videoFilename = videoFilename else {
            return nil
        }

        return FileManager.getDocumentsDirectory().appendingPathComponent(videoFilename)
    }

    func getFilename() -> String {
        return id + ".json"
    }

    func cache() {
        lastModifiedDate = Date()
        Cache.projects.cacheItem(self)
    }

    func debounceSetProperty<T>(_ path: WritableKeyPath<Project, T>, newValue: T) {
        DebouncePropertySetter.timers[path]?.invalidate()
        DebouncePropertySetter.timers[path] = nil
        DebouncePropertySetter.timers[path] = Timer.scheduledTimer(withTimeInterval: 0.1,
                                                                   repeats: false,
                                                                   block: { [weak self] _ in
            self?[keyPath: path] = newValue
        })
    }
}

enum ProjectMediaType: Codable {
    case audio
    case video
}

struct Flag: Codable {
    var timestamp: TimeInterval
    var text: String
}
