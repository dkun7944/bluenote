//
//  WaveformView.swift
//  WaveformView
//
//  Created by Daniel Kuntz on 8/11/21.
//

import UIKit
import PureLayout

class WaveformView: UIView {
    private let bgColor = UIColor(hex: "222224")
    private let lighterBgColor = UIColor(hex: "2B2B2E")
    private let lineWidth: CGFloat = 1
    private let lineSpacing: CGFloat = 3
    private let waveformHeight: CGFloat = 151

    let widthPerSecondAtDefaltZoom: CGFloat = 100

    var totalWidth: CGFloat {
        return widthPerSecondAtDefaltZoom * zoomScale * (sound?.duration ?? 1)
    }

    private var zoomScale: CGFloat = 1
    private var scrollOffset: CGFloat = 0

    var sound: Sound?

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        isOpaque = true
    }

    func set(zoomScale: CGFloat, scrollOffset: CGFloat) {
        self.zoomScale = zoomScale
        self.scrollOffset = scrollOffset
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        bgColor.setFill()
        UIBezierPath(rect: rect).fill()

        guard var sound = sound else {
            return
        }

        lighterBgColor.setFill()
        let startX = max(-1 * scrollOffset, 0)
        let endX = min(totalWidth - scrollOffset, rect.width)
        let lighterRect = CGRect(x: startX, y: 0, width: endX - startX, height: rect.height)
        UIBezierPath(rect: lighterRect).fill()

        UIColor.white.setFill()

        let totalWidth = self.totalWidth
        let durationFractionOfOneLine = (lineWidth * lineSpacing) / totalWidth

        var x = -1 * scrollOffset
        while x < (rect.width - lineWidth - lineSpacing) {
            if x < -1 * lineWidth {
                x += lineSpacing + lineWidth
                continue
            }

            let startTimeFraction = (scrollOffset + x) / totalWidth
            if startTimeFraction > 1 {
                return
            }

            let rms = sound.rms(forStartTime: startTimeFraction, length: durationFractionOfOneLine)
            let height = max(CGFloat(rms * 2) * self.waveformHeight, self.lineWidth)
            let frame = CGRect(x: x,
                               y: (self.waveformHeight / 2) - (height / 2),
                               width: self.lineWidth,
                               height: height)
            UIBezierPath(rect: frame).fill()

            x += lineSpacing + lineWidth
        }
    }
}
