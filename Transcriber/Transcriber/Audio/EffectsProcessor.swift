//
//  EffectsProcessor.swift
//  EffectsProcessor
//
//  Created by Daniel Kuntz on 8/16/21.
//

import Foundation

class EffectsProcessor {

    var fx = createAudioEffects(Double(sampleRate))

    func processMono(_ sample: Float) -> Float {
        var sample = sample
        var output: Float = sample
        process_mono(&fx, &sample, &output)
        return output
    }

    func setLowPassFreq(_ freq: Float) {
        set_lowpass_freq(&fx, freq)
    }

    func setHighPassFreq(_ freq: Float) {
        set_highpass_freq(&fx, freq)
    }

    func setPitchShift(_ semitones: Float, cents: Float) {
        let interval = semitones + (cents / 100)
        let ratio = powf(powf(2, interval), 1 / 12)
        set_pitch_shift(&fx, ratio)
    }
}
