//
//  Sound.swift
//  Sound
//
//  Created by Daniel Kuntz on 8/12/21.
//

import AVFoundation
import Accelerate

struct Sound {
    var name: String = ""
    var bufferL: ContiguousArray<Float32> = ContiguousArray<Float32>(repeating: 0.0, count: 1)
    var bufferR: ContiguousArray<Float32> = ContiguousArray<Float32>(repeating: 0.0, count: 1)
    var duration: TimeInterval = 1
    var sampleRate: Double = 44100
    var bufferPointer: UnsafeMutableBufferPointer<Float32>?

    init(fileName: String) {
        let url = Bundle.main.url(forResource: fileName, withExtension: "wav")
        self.init(fileUrl: url)
    }

    init(fileUrl: URL?) {
        guard let fileUrl = fileUrl else {
            return
        }

        let components = fileUrl.lastPathComponent.components(separatedBy: CharacterSet(charactersIn: " ."))
        name = components[0]
        loadBuffer(fromFileUrl: fileUrl)
    }

    /// Calculates the rms for a time range. Input times are represented as a fraction of total duration.
    mutating func rms(forStartTime startTime: Double, length: Double) -> Float {
        let resamp: Double = 4
        let startSample = Int(startTime * sampleRate * duration)
        let maxLength = vDSP_Length((Double(bufferL.count-startSample-1) / resamp).clamped(to: 0...Double.greatestFiniteMagnitude))
        let length = vDSP_Length(length * sampleRate * duration / resamp).clamped(to: 0...maxLength)
        var rms: Float = 0

        guard let pointer = bufferPointer else {
            return 0
        }

        vDSP_rmsqv(pointer.baseAddress!.advanced(by: startSample), Int(resamp), &rms, length)

        return rms
    }

    mutating private func loadBuffer(fromFileUrl url: URL) {
        do {
            let file = try AVAudioFile(forReading: url)
            duration = Double(file.length) / file.fileFormat.sampleRate

            if let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                          frameCapacity: AVAudioFrameCount(file.length)) {

                try file.read(into: buf)

                let outFormat = TranscriberAudioEngine.shared.format!
                let rateMultiplier = outFormat.sampleRate / file.processingFormat.sampleRate
                let converter = AVAudioConverter(from: file.processingFormat,
                                                 to: outFormat)!
                let outBuffer = AVAudioPCMBuffer(pcmFormat: outFormat,
                                                 frameCapacity: AVAudioFrameCount(rateMultiplier * Double(buf.frameLength)))!
                var error: NSError?
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    outStatus.pointee = AVAudioConverterInputStatus.haveData
                    return buf
                }
                converter.convert(to: outBuffer, error: &error, withInputFrom: inputBlock)

                if let floatChannelData = outBuffer.floatChannelData {
                    if file.fileFormat.channelCount == 2 {
                        // Stereo
                        let lArray = UnsafeBufferPointer(start: floatChannelData[0], count: Int(outBuffer.frameCapacity))
                        let rArray = UnsafeBufferPointer(start: floatChannelData[1], count: Int(outBuffer.frameCapacity))
                        bufferL = ContiguousArray<Float32>(repeating: 0.0, count: Int(outBuffer.frameCapacity))
                        bufferR = ContiguousArray<Float32>(repeating: 0.0, count: Int(outBuffer.frameCapacity))
                        for i in 0..<Int(outBuffer.frameCapacity) {
                            bufferL[i] = lArray[i]
                            bufferR[i] = rArray[i]
                        }
                    } else {
                        // Convert mono files to stereo
                        let arrayPointer = UnsafeBufferPointer(start: floatChannelData[0], count: Int(outBuffer.frameCapacity))
                        bufferL = ContiguousArray<Float32>(repeating: 0.0, count: Int(outBuffer.frameCapacity))
                        bufferR = ContiguousArray<Float32>(repeating: 0.0, count: Int(outBuffer.frameCapacity))
                        for i in 0..<Int(outBuffer.frameCapacity) {
                            bufferL[i] = arrayPointer[i]
                            bufferR[i] = arrayPointer[i]
                        }
                    }

                    bufferL.withUnsafeMutableBufferPointer { p in
                        bufferPointer = p
                    }
                }
            }
        } catch {}
    }
}

enum SoundChannel {
    case left
    case right
}
