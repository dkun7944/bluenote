//
//  AudioChannelMode.swift
//  Transcriber
//
//  Created by Daniel Kuntz on 12/1/21.
//

import Foundation

enum AudioChannelMode: Int, CaseIterable, Codable {
    case lr
    case rl
    case l
    case r
    case mono

    func next() -> AudioChannelMode {
        return AudioChannelMode.allCases[(rawValue + 1) % AudioChannelMode.allCases.count]
    }

    var displayName: String {
        switch self {
        case .lr:
            return "L・R"
        case .rl:
            return "R・L"
        case .l:
            return "L"
        case .r:
            return "R"
        case .mono:
            return "MONO"
        }
    }
}
