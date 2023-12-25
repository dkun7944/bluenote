//
//  EqualizerView.swift
//  EqualizerView
//
//  Created by Daniel Kuntz on 8/15/21.
//

import UIKit
import PureLayout

protocol EqualizerViewDelegate: AnyObject {
    func trimmed(to freqRange: ClosedRange<Float>)
}

class EqualizerView: UIView {
    var sound: Sound? {
        didSet {
            spectrumView.sound = sound
        }
    }
    
    var time: TimeInterval = 0 {
        didSet {
            spectrumView.time = time
        }
    }

    weak var delegate: EqualizerViewDelegate?

    private var spectrumView: SpectrumView!
    private var trimView: TrimView!

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = .clear

        spectrumView = SpectrumView()
        addSubview(spectrumView)
        spectrumView.autoPinEdge(toSuperviewEdge: .top)
        spectrumView.autoPinEdge(toSuperviewEdge: .bottom)
        spectrumView.autoAlignAxis(toSuperviewAxis: .vertical)
        spectrumView.autoMatch(.width, to: .width, of: self, withMultiplier: 0.85)

        trimView = TrimView()
        trimView.delegate = self
        trimView.color = UIColor(hex: "FE463A")
        trimView.trimViewBgColor = trimView.color.withAlphaComponent(0.1)
        trimView.handleColor = .white
        trimView.lrMargin = UIScreen.main.bounds.width * 0.075
        addSubview(trimView)
        trimView.autoPinEdgesToSuperviewEdges()
    }

    func setFrequencyRange(_ range: ClosedRange<Float>) {
        let minFreq: Float = 10.0
        let maxFreq: Float = 20000.0
        let maxLog = log10(maxFreq / minFreq)
        let lowerFreq = range.lowerBound
        let upperFreq = range.upperBound
        let lowerBound = log10(lowerFreq / minFreq) / maxLog
        let upperBound = log10(upperFreq / minFreq) / maxLog
        trimView.setProgressRange(lowerBound...upperBound)
    }
}

extension EqualizerView: TrimViewDelegate {
    func trimmed(to progressRange: ClosedRange<Float>) {
        let maxLog: Float = log10(20000.0 / 10.0)
        let lowerFreq = 10 * powf(10, maxLog * progressRange.lowerBound)
        let upperFreq = 10 * powf(10, maxLog * progressRange.upperBound)
        let freqRange = lowerFreq...upperFreq
        delegate?.trimmed(to: freqRange)
    }
}
