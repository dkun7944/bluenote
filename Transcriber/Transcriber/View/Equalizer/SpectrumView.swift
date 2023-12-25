//
//  SpectrumView.swift
//  Equalizer
//
//  Created by Daniel Kuntz on 8/11/21.
//

import UIKit
import Accelerate

class SpectrumView: UIView {
    var sound: Sound?
    var time: TimeInterval = 0 {
        didSet {
            needsNewFFT = true
        }
    }

    private var needsNewFFT: Bool = false

    var shouldDrawFrequencyLines: Bool = false

    private let bgColor = UIColor(hex: "262629")
    private let spectrumBgColor = UIColor(white: 0.2, alpha: 1)
    private let spectrumLineColor = UIColor.white
    private let lineWidth: CGFloat = 1
    private let lineSpacing: CGFloat = 3

    private var displayLink: CADisplayLink!

    private var fft: TempiFFT = TempiFFT(withSize: 4096, sampleRate: Float(sampleRate))
    private var fftSamples: [Float] = []

    private var shapeLayer: CAShapeLayer!

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)

        backgroundColor = bgColor
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        isOpaque = true

        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink.preferredFramesPerSecond = 30
        displayLink.add(to: .main, forMode: .common)
        displayLink.add(to: .main, forMode: .tracking)

        fft.windowType = .hanning

        shapeLayer = CAShapeLayer()
        shapeLayer.frame = bounds
        layer.addSublayer(shapeLayer)
    }

    @objc private func update() {
        guard needsNewFFT else {
            return
        }

        calculateFFT()

        let points: [CGPoint] = fftSamples.enumerated().map { i, samp in
            let x = bounds.width * CGFloat(i) / CGFloat(fftSamples.count)
            let height = CGFloat(samp) * bounds.height
            return CGPoint(x: x, y: bounds.height - height)
        }

        let path = UIBezierPath()
        var lastPoint = CGPoint(x: -20, y: bounds.height*2)
        path.move(to: lastPoint)
        for point in points {
            if point.y == lastPoint.y {
                continue
            }
            let midPoint = midPoint(forPoints: lastPoint, point)
            path.addQuadCurve(to: midPoint, controlPoint: controlPointForPoints(midPoint, lastPoint))
            path.addQuadCurve(to: point, controlPoint: controlPointForPoints(midPoint, point))
            lastPoint = point
        }
        path.addLine(to: CGPoint(x: bounds.width+20, y: bounds.height*2))
        path.close()

        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = spectrumLineColor.cgColor
        shapeLayer.fillColor = spectrumBgColor.cgColor
        shapeLayer.lineWidth = lineWidth
        shapeLayer.frame = bounds
    }

    private func midPoint(forPoints p1: CGPoint, _ p2: CGPoint) -> CGPoint {
        return CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
    }

    private func controlPointForPoints(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
        var controlPoint = midPoint(forPoints: p1, p2)
        let diffY = abs(p2.y - controlPoint.y)

        if p1.y < p2.y {
            controlPoint.y += diffY
        } else if p1.y > p2.y {
            controlPoint.y -= diffY
        }

        return controlPoint
    }

    @objc private func calculateFFT() {
        guard let sound = sound else {
            return
        }

        let startIdx = Int(Double(sound.bufferL.count) * time / sound.duration)
        let count = 4096
        performFFT(n: count, startIdx: startIdx)
    }

    private func performFFT(n: Int, startIdx: Int) {
        guard let sound = sound, needsNewFFT else {
            return
        }

        guard startIdx+n < sound.bufferL.count else {
            return
        }

        needsNewFFT = false
        let inputBuffer = Array(sound.bufferL[startIdx..<startIdx+n])

        // Perform the FFT
        fft.fftForward(inputBuffer)
        // Map FFT data to logical bands. This gives 4 bands per octave across 7 octaves = 28 bands.
        fft.calculateLogarithmicBands(minFrequency: 50, maxFrequency: 20000, bandsPerOctave: 8)
        // Process some data

        let maxDB: Float = 180
        let dbRef: Float = 0.00001
        var fftArray: [Float] = []

        for i in 0..<fft.numberOfBands {
            let mag = fft.magnitudeAtBand(i) * 2 / Float(n)
            let db = ((20 * log10(mag / dbRef)) / maxDB).clamped(to: -100...100)
            fftArray.append(db)
        }

        if fftSamples.isEmpty {
            fftSamples = fftArray
            return
        }

        for i in 0..<fftSamples.count {
            fftSamples[i] = (fftSamples[i] * 0.5) + (fftArray[i] * 0.5)
        }
    }
}
