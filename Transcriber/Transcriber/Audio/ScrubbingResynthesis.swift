//
//  ScrubbingResynthesis.swift
//  Transcriber
//
//  Created by Daniel Kuntz on 10/30/23.
//

import Foundation
import Accelerate

class ScrubbingResynthesis {
    var sound: Sound
    let FFT_SIZE: Int = 2048
    let DELETE_THRESHOLD: Int = 4096

    private var playheadPosition: Int = 0

    private var fft: vDSP.FFT<DSPSplitComplex>?
    private var resynthesisBufferL: [Float] = []
    private var resynthesisBufferR: [Float] = []
    private var lDeletionIdx: Int = 0
    private var rDeletionIdx: Int = 0

    private lazy var phaseAccumulatorL: [Float] = [Float](repeating: -10,
                                                          count: FFT_SIZE / 2)
    private lazy var phaseAccumulatorR: [Float] = [Float](repeating: -10,
                                                          count: FFT_SIZE / 2)
    private lazy var window: [Float] = {
        var window = [Float](repeating: 0, count: FFT_SIZE)
        vDSP_hann_window(&window, vDSP_Length(FFT_SIZE), Int32(vDSP_HANN_NORM))
        return window
    }()

    private var isBuffering: Bool = false
    private var bufferQueue = DispatchQueue(label: "com.codalabs.transcriber.scrub_buffer",
                                            qos: .userInteractive)
    private var arrayAccessQueue = DispatchQueue(label: "com.codalabs.transcriber.scrub_array_access",
                                                 qos: .userInteractive,
                                                 attributes: .concurrent)
    private var semaphoreL = DispatchSemaphore(value: 0)
    private var semaphoreR = DispatchSemaphore(value: 0)
    private var bufferingSemaphore = DispatchSemaphore(value: 1)

    init(sound: Sound, playhead: Int) {
        self.sound = sound

        let log2Size = Int(log2f(Float(FFT_SIZE)))
        fft = vDSP.FFT(log2n: vDSP_Length(log2Size),
                       radix: .radix2,
                       ofType: DSPSplitComplex.self)
        setPlayheadPosition(playhead)
    }

    func setPlayheadPosition(_ position: Int) {
        bufferQueue.async {
            if self.playheadPosition != position {
                self.playheadPosition = position
                self.buffer()
            }
        }
    }

    func popNextSample() -> (Float, Float) {
        semaphoreL.wait()
        semaphoreR.wait()
        var lSamp: Float = 0.0
        var rSamp: Float = 0.0
        arrayAccessQueue.sync {
            if !resynthesisBufferL.isEmpty {
                lSamp = resynthesisBufferL[lDeletionIdx]
                lDeletionIdx += 1
            }

            if !resynthesisBufferR.isEmpty {
                rSamp = self.resynthesisBufferR[rDeletionIdx]
                rDeletionIdx += 1
            }

            if min(resynthesisBufferL.count - lDeletionIdx,
                   resynthesisBufferR.count - rDeletionIdx) < FFT_SIZE*2 {
                bufferQueue.async {
                    self.buffer()
                }
            }
        }

        return (lSamp, rSamp)
    }

    private func buffer() {
        guard !isBuffering else {
            return
        }
        isBuffering = true

        var lCount = 0
        var rCount = 0
        arrayAccessQueue.sync(flags: .barrier) {
            lCount = resynthesisBufferL.count - lDeletionIdx
            rCount = resynthesisBufferR.count - rDeletionIdx
        }

        // Fill buffers
        while min(lCount, rCount) < FFT_SIZE*2 {
            fillBuffer(with: &sound.bufferL,
                       resynthesisBuffer: &resynthesisBufferL,
                       phaseAccumulator: &phaseAccumulatorL,
                       semaphore: &semaphoreL)
            fillBuffer(with: &sound.bufferR,
                       resynthesisBuffer: &resynthesisBufferR,
                       phaseAccumulator: &phaseAccumulatorR,
                       semaphore: &semaphoreR)

            arrayAccessQueue.sync(flags: .barrier) {
                lCount = resynthesisBufferL.count - lDeletionIdx
                rCount = resynthesisBufferR.count - rDeletionIdx
            }
        }

        // Purge buffers if necessary
        arrayAccessQueue.sync(flags: .barrier) {
            if lDeletionIdx > DELETE_THRESHOLD && 
               rDeletionIdx > DELETE_THRESHOLD {
                resynthesisBufferL.removeFirst(lDeletionIdx)
                resynthesisBufferR.removeFirst(rDeletionIdx)
                lDeletionIdx = 0
                rDeletionIdx = 0
            }
        }

        isBuffering = false
    }

    private func fillBuffer(with soundBuffer: inout ContiguousArray<Float>,
                            resynthesisBuffer: inout [Float],
                            phaseAccumulator: inout [Float],
                            semaphore: inout DispatchSemaphore) {
        let halfN = Int(FFT_SIZE / 2)
        let hopSize = FFT_SIZE / 4

        let idx1 = (playheadPosition - 1)               .clamped(to: 0...(soundBuffer.count-(FFT_SIZE)-1))
        let idx2 = (playheadPosition - 1 + FFT_SIZE)    .clamped(to: (idx1+1)...(soundBuffer.count-1))
        let idx3 = (playheadPosition)                   .clamped(to: 0...(soundBuffer.count-(FFT_SIZE)-1))
        let idx4 = (playheadPosition + FFT_SIZE)        .clamped(to: (idx3+1)...(soundBuffer.count-1))

        guard idx1 != idx3 else {
            let zeroBuff = [Float](repeating: 0.0, count: FFT_SIZE)
            resynthesisBuffer.append(contentsOf: zeroBuff)
            zeroBuff.forEach { _ in semaphore.signal() }
            return
        }

        // Grab two slices – one at the playhead position and one shifted backwards by 1 sample
        var signal1 = Array(soundBuffer[idx1...(idx2-1)])
        var signal2 = Array(soundBuffer[idx3...(idx4-1)])

        // Window the slices before doing the forward FFT
        vDSP_vmul(signal1, 1, window, 1, &signal1, 1, vDSP_Length(signal1.count))
        vDSP_vmul(signal2, 1, window, 1, &signal2, 1, vDSP_Length(signal2.count))

        var forwardOutput1Real = [Float](repeating: 0,
                                         count: halfN)
        var forwardOutput1Imag = [Float](repeating: 0,
                                         count: halfN)
        var forwardOutput2Real = [Float](repeating: 0,
                                         count: halfN)
        var forwardOutput2Imag = [Float](repeating: 0,
                                         count: halfN)

        // Forward FFT
        forwardFFT(&signal1, &forwardOutput1Real, &forwardOutput1Imag)
        forwardFFT(&signal2, &forwardOutput2Real, &forwardOutput2Imag)

        var phases1 = [Float](repeating: 0,
                              count: halfN)
        var mags2 = [Float](repeating: 0,
                            count: halfN)
        var phases2 = [Float](repeating: 0,
                              count: halfN)

        // Get magnitudes and phases
        polarToPhases(&forwardOutput1Real, &forwardOutput1Imag, &phases1)
        polarToRect(&forwardOutput2Real, &forwardOutput2Imag, &mags2, &phases2)

        var phaseShiftedReal = [Float](repeating: 0.0, count: FFT_SIZE/2)
        var phaseShiftedImag = [Float](repeating: 0.0, count: FFT_SIZE/2)

        // Phase accumulation
        for i in 0..<FFT_SIZE/2 {
            if phaseAccumulator[i] == -10.0 {
                phaseAccumulator[i] = phases2[i]
            } else {
                // Accumulate the phase difference from the previous frame
                let phaseDiff = (phases2[i] - phases1[i]) * Float(hopSize)
                phaseAccumulator[i] = unwrap(phaseAccumulator[i] + phaseDiff)
            }

            // Convert back to real / imaginary
            phaseShiftedReal[i] = mags2[i] * cos(phaseAccumulator[i])
            phaseShiftedImag[i] = mags2[i] * sin(phaseAccumulator[i])
        }

        // Perform inverse FFT
        var recreatedSignal = inverseFFT(&phaseShiftedReal, &phaseShiftedImag)

        // Window the output signal. Windowing the input and the output results in a squared
        // Hann window, which has a constant overlap add property if the overlap is 25%.
        vDSP_vmul(recreatedSignal, 1, window, 1, &recreatedSignal, 1, vDSP_Length(recreatedSignal.count))

        // Multiply the output by 0.25 to keep the same loudness
        var scaleFactor: Float = 0.25
        vDSP_vsmul(recreatedSignal, 1, &scaleFactor, &recreatedSignal, 1, vDSP_Length(recreatedSignal.count))

        arrayAccessQueue.sync(flags: .barrier) {
            if resynthesisBuffer.isEmpty {
                resynthesisBuffer.append(contentsOf: recreatedSignal)
            } else {
                // Blend recreatedSignal with resynthesisBuffer according to hopSize
                let startIdx = resynthesisBuffer.count - FFT_SIZE + hopSize
                for i in startIdx..<resynthesisBuffer.count {
                    resynthesisBuffer[i] += recreatedSignal[i - startIdx]
                }
                recreatedSignal.removeFirst(recreatedSignal.count - hopSize)
                resynthesisBuffer.append(contentsOf: recreatedSignal)
                recreatedSignal.forEach { _ in semaphore.signal() }
            }
        }
    }

    private func forwardFFT(_ signal: inout [Float],
                            _ outputReal: inout [Float],
                            _ outputImag: inout [Float]) {
        let halfN = Int(FFT_SIZE / 2)
        var forwardInputReal = [Float](repeating: 0,
                                       count: halfN)
        var forwardInputImag = [Float](repeating: 0,
                                       count: halfN)

        // Forward FFT
        forwardInputReal.withUnsafeMutableBufferPointer { forwardInputRealPtr in
            forwardInputImag.withUnsafeMutableBufferPointer { forwardInputImagPtr in
                outputReal.withUnsafeMutableBufferPointer { forwardOutputRealPtr in
                    outputImag.withUnsafeMutableBufferPointer { forwardOutputImagPtr in

                        // Create a `DSPSplitComplex` to contain the signal.
                        var forwardInput = DSPSplitComplex(realp: forwardInputRealPtr.baseAddress!,
                                                           imagp: forwardInputImagPtr.baseAddress!)

                        // Convert the real values in `signal` to complex numbers.
                        signal.withUnsafeBytes {
                            vDSP.convert(interleavedComplexVector: [DSPComplex]($0.bindMemory(to: DSPComplex.self)),
                                         toSplitComplexVector: &forwardInput)
                        }

                        // Create a `DSPSplitComplex` to receive the FFT result.
                        var forwardOutput = DSPSplitComplex(realp: forwardOutputRealPtr.baseAddress!,
                                                            imagp: forwardOutputImagPtr.baseAddress!)

                        // Perform the forward FFT.
                        fft?.forward(input: forwardInput,
                                     output: &forwardOutput)
                    }
                }
            }
        }
    }

    private func inverseFFT(_ inputReal: inout [Float],
                            _ inputImag: inout [Float]) -> [Float] {
        var inverseOutputReal = [Float](repeating: 0,
                                        count: FFT_SIZE)
        var inverseOutputImag = [Float](repeating: 0,
                                        count: FFT_SIZE)

        return inputReal.withUnsafeMutableBufferPointer { forwardOutputRealPtr in
            inputImag.withUnsafeMutableBufferPointer { forwardOutputImagPtr in
                inverseOutputReal.withUnsafeMutableBufferPointer { inverseOutputRealPtr in
                    inverseOutputImag.withUnsafeMutableBufferPointer { inverseOutputImagPtr in

                        // Create a `DSPSplitComplex` that contains the frequency-domain data.
                        let forwardOutput = DSPSplitComplex(realp: forwardOutputRealPtr.baseAddress!,
                                                            imagp: forwardOutputImagPtr.baseAddress!)

                        // Create a `DSPSplitComplex` structure to receive the FFT result.
                        var inverseOutput = DSPSplitComplex(realp: inverseOutputRealPtr.baseAddress!,
                                                            imagp: inverseOutputImagPtr.baseAddress!)

                        // Perform the inverse FFT.
                        fft?.inverse(input: forwardOutput,
                                     output: &inverseOutput)

                        // Return an array of real values from the FFT result.
                        let scale = 1 / Float(FFT_SIZE * 2)
                        return [Float](fromSplitComplex: inverseOutput,
                                       scale: scale,
                                       count: FFT_SIZE)
                    }
                }
            }
        }
    }

    private func unwrap(_ phase: Float) -> Float {
        return (phase + .pi).truncatingRemainder(dividingBy: 2 * .pi) - .pi
    }

    private func polarToRect(_ real: inout [Float],
                             _ imag: inout [Float],
                             _ mags: inout [Float],
                             _ phases: inout [Float]) {
        let count = vDSP_Length(real.count)
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var complexSignal = DSPSplitComplex(realp: realPtr.baseAddress!,
                                                    imagp: imagPtr.baseAddress!)
                vDSP_zvmags(&complexSignal, 1, &mags, 1, count)
                mags = mags.map { sqrt($0) }
                vDSP_zvphas(&complexSignal, 1, &phases, 1, count)
            }
        }
    }

    private func polarToPhases(_ real: inout [Float],
                               _ imag: inout [Float],
                               _ phases: inout [Float]) {
        let count = vDSP_Length(real.count)
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var complexSignal = DSPSplitComplex(realp: realPtr.baseAddress!,
                                                    imagp: imagPtr.baseAddress!)
                vDSP_zvphas(&complexSignal, 1, &phases, 1, count)
            }
        }
    }
}
