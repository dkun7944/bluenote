//
//  VerticalPickerTickView.swift
//  VerticalPickerTickView
//
//  Created by Daniel Kuntz on 8/17/21.
//

import UIKit

class VerticalPickerTickView: UIView {

    // MARK: - Constants

    private let font = UIFont(name: "SFMono-Medium", size: 10)!
    private let bgColor = UIColor(hex: "2B2B2E")
    private let bigTickLength: CGFloat = 17
    private let smallTickLength: CGFloat = 9
    private let tickHeight: CGFloat = 1
    private let tickSpacing: CGFloat = 16

    var range: ClosedRange<Float> = -50...50
    var stride: Float = 1
    var decimalPlaces: Int = 0
    var suffix: String = ""

    var scrollOffset: CGFloat = 0 {
        didSet {
            setNeedsDisplay()
        }
    }

    var totalHeight: CGFloat {
        return CGFloat((range.upperBound - range.lowerBound) / stride) * (tickHeight + tickSpacing) * 2
    }

    // MARK: - Draw

    override func draw(_ rect: CGRect) {
        bgColor.setFill()
        UIBezierPath(rect: rect).fill()
        
        var big: Int = 1
        var y: CGFloat = -1 * scrollOffset

        while y < 0 {
            y += tickHeight + tickSpacing
            big = (big + 1) % 2
        }

        let halfHeight = bounds.height / 2

        while y < bounds.height {
            if y + scrollOffset > totalHeight {
                return
            }

            let halfHeightFraction = 1 - (abs(halfHeight - y) / halfHeight)
            let alpha = (0.6 * halfHeightFraction) + 0.05
            let color = UIColor.white.withAlphaComponent(alpha)
            color.setFill()

            let length: CGFloat = big == 1 ? bigTickLength : smallTickLength

            let leftRect = CGRect(x: 0, y: y - (tickHeight / 2), width: length, height: tickHeight)
            UIBezierPath(rect: leftRect).fill()

            let rightRect = CGRect(x: bounds.width - length, y: y, width: length, height: tickHeight)
            UIBezierPath(rect: rightRect).fill()

            if big == 1 {
                let yFraction = 1 - ((y + scrollOffset) / totalHeight)
                let value = yFraction * CGFloat(range.upperBound - range.lowerBound) + CGFloat(range.lowerBound)
                guard range.contains(Float(value)) else {
                    break
                }

                let roundedValue = Float(value).rounded(toPlaces: decimalPlaces)
                let valueString = decimalPlaces == 0 ? "\(Int(roundedValue))" : "\(roundedValue)"
                var string: NSString {
                    if range.lowerBound < 0 {
                        return ((value >= 0 ? "+" : "") + valueString + suffix) as NSString
                    } else {
                        return (valueString + suffix) as NSString
                    }
                }

                let sizedFont = font.withSize(font.pointSize * (0.25 * halfHeightFraction + 0.9))
                let attributes: [NSAttributedString.Key: Any] = [.font : sizedFont,
                                                                 .foregroundColor : color]
                let stringSize = string.size(withAttributes: attributes)
                let stringLocation = CGPoint(x: (bounds.width / 2) - (stringSize.width / 2),
                                             y: y - (tickHeight / 2) - (stringSize.height / 2))
                string.draw(at: stringLocation, withAttributes: attributes)
            }

            y += tickHeight + tickSpacing
            big = (big + 1) % 2
        }
    }
}
