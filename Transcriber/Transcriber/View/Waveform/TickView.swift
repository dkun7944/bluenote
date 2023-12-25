//
//  TickView.swift
//  TickView
//
//  Created by Daniel Kuntz on 8/11/21.
//

import UIKit

class TickView: UIView {

    let minSpacing: CGFloat = 20
    let maxSpacing: CGFloat = 60
    let bigHeight: CGFloat = 11
    let smallHeight: CGFloat = 6
    let tickWidth: CGFloat = 1

    let bgColor = UIColor(hex: "1C1C1E")
    let tickColor = UIColor(hex: "4B4B4B")
    let textColor = UIColor(hex: "5A5A5D")

    let widthPerSecondAtDefaltZoom: CGFloat = 100
    var soundDuration: CGFloat = 1

    private var totalWidth: CGFloat {
        return widthPerSecondAtDefaltZoom * zoomScale * soundDuration
    }

    private var zoomScale: CGFloat = 1
    private var scrollOffset: CGFloat = 0

    override func awakeFromNib() {
        super.awakeFromNib()
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

        guard soundDuration > 1 else {
            return
        }

        let divisor: CGFloat = (widthPerSecondAtDefaltZoom * zoomScale) < (minSpacing * 4) ? 5 : 4
        var spacing = (widthPerSecondAtDefaltZoom * zoomScale) / 4
        if spacing < minSpacing {
            while spacing < minSpacing {
                spacing *= 2
            }
        } else if spacing > maxSpacing {
            while spacing > maxSpacing {
                spacing /= 2
            }
        }

        var x = -1 * scrollOffset
        var bigCounter: Int = 0
        while x < rect.width {
            if x < (-2 * spacing) {
                x += spacing
                bigCounter = (bigCounter + 1) % Int(divisor)
                continue
            }

            if (x + scrollOffset) > totalWidth {
                break
            }

            let height = (bigCounter == 0) ? bigHeight : smallHeight
            let tickRect = CGRect(x: x - (tickWidth / 2),
                                  y: 0,
                                  width: tickWidth,
                                  height: height)

            tickColor.setFill()
            UIBezierPath(rect: tickRect).fill()

            if bigCounter == 0 {
                let time = ((x + scrollOffset) / (widthPerSecondAtDefaltZoom * zoomScale)).rounded(toPlaces: 2)
                let minutes = Int(time / 60)
                let seconds = Int(time.truncatingRemainder(dividingBy: 60))
                let milliseconds = Int((time - floor(time)) * 100)
                var millisecondsString: String {
                    if milliseconds == 0 {
                        return ""
                    } else {
                        return "." + ((milliseconds < 10) ? "0" : "") + "\(milliseconds)"
                    }
                }
                let string = ((minutes < 10) ? "0" : "") + "\(minutes)" + ":" +
                             ((seconds < 10) ? "0" : "") + "\(seconds)" + millisecondsString
                let attributes: [NSAttributedString.Key: Any] = [.font : UIFont.systemFont(ofSize: 12),
                                                                 .foregroundColor: textColor]
                (string as NSString).draw(at: CGPoint(x: x, y: height + 2),
                                          withAttributes: attributes)
            }

            x += spacing
            bigCounter = (bigCounter + 1) % Int(divisor)
        }
    }
}
