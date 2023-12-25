//
//  VerticalPicker.swift
//  VerticalPicker
//
//  Created by Daniel Kuntz on 8/11/21.
//

import UIKit
import PureLayout

protocol VerticalPickerDelegate: AnyObject {
    func verticalPicker(_ picker: VerticalPicker, didSelect value: Float)
}

class VerticalPicker: UIView {

    // MARK: - Constants

    private let bigFont = UIFont(name: "SFMono-Bold", size: 19)
    private let bgColor = UIColor(hex: "2B2B2E")
    private let magnifierColor = UIColor(hex: "404043")

    private var range: ClosedRange<Float> = -50...50
    private var stride: Float = 1
    private var centerValue: Float = 0
    private var decimalPlaces: Int = 0
    private var suffix: String = ""
    private var hasCentered: Bool = false
    private var isCentering: Bool = false

    private var tickView: VerticalPickerTickView!
    private var scrollView: UIScrollView!
    private var invisibleScrollingView: UIView!
    private var invisibleScrollingViewHeightConstraint: NSLayoutConstraint!
    private var magnifierView: UIView!
    private var label: UILabel!

    private var feedbackGenerator = UISelectionFeedbackGenerator()

    weak var delegate: VerticalPickerDelegate?
    private(set) var value: Float = 0

    // MARK: - Setup

    override func awakeFromNib() {
        super.awakeFromNib()
        layer.cornerRadius = 11
        layer.cornerCurve = .continuous
        layer.masksToBounds = true

        tickView = VerticalPickerTickView()
        addSubview(tickView)

        magnifierView = UIView()
        magnifierView.backgroundColor = magnifierColor
        magnifierView.layer.cornerRadius = 4
        magnifierView.layer.cornerCurve = .continuous
        addSubview(magnifierView)

        label = UILabel()
        label.font = bigFont
        label.textColor = .white
        label.textAlignment = .center
        addSubview(label)

        scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        addSubview(scrollView)

        invisibleScrollingView = UIView()
        invisibleScrollingView.backgroundColor = .clear
        scrollView.addSubview(invisibleScrollingView)

        tickView.autoPinEdgesToSuperviewEdges()
        scrollView.autoPinEdgesToSuperviewEdges()
        invisibleScrollingView.autoPinEdgesToSuperviewEdges()
        invisibleScrollingViewHeightConstraint = invisibleScrollingView.autoSetDimension(.height, toSize: 100)
        invisibleScrollingView.autoMatch(.width, to: .width, of: scrollView)
        magnifierView.autoSetDimension(.height, toSize: 29)
        magnifierView.autoPinEdge(toSuperviewEdge: .leading, withInset: 4)
        magnifierView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 4)
        magnifierView.autoAlignAxis(toSuperviewAxis: .horizontal)
        label.autoCenterInSuperview()

        setRange(-50...50, stride: 1)

        let doubleTapGR = UITapGestureRecognizer(target: self, action: #selector(doubleTapHandler(_:)))
        doubleTapGR.numberOfTapsRequired = 2
        doubleTapGR.cancelsTouchesInView = false
        addGestureRecognizer(doubleTapGR)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        scrollView.contentInset = UIEdgeInsets(top: bounds.height / 2,
                                               left: 0,
                                               bottom: bounds.height / 2,
                                               right: 0)

        if !hasCentered {
            center()
            hasCentered = true
        }

        if !scrollView.isDragging && !scrollView.isDecelerating && !isCentering {
            scrollToNearestNumber(animated: false)
        }
    }

    func setRange(_ range: ClosedRange<Float>, stride: Float, centerValue: Float = 0, decimals: Int = 0, suffix: String = "") {
        self.range = range
        self.stride = stride
        self.centerValue = centerValue
        self.decimalPlaces = decimals
        self.suffix = suffix
        tickView.range = range
        tickView.stride = stride
        tickView.decimalPlaces = decimals
        tickView.suffix = suffix

        let totalHeight = tickView.totalHeight
        invisibleScrollingViewHeightConstraint.constant = totalHeight
        center()
    }

    func setValue(_ value: Float) {
        self.value = value
        scrollToNearestNumber()
        delegate?.verticalPicker(self, didSelect: value)
    }

    @objc private func doubleTapHandler(_ recognizer: UITapGestureRecognizer) {
        center(true)
    }

    private func center(_ animated: Bool = false) {
        let yFraction = 1 - ((centerValue - range.lowerBound) / (range.upperBound - range.lowerBound))
        let contentOffset = (CGFloat(yFraction) * tickView.totalHeight) - (scrollView.bounds.height / 2)

        isCentering = true
        scrollView.setContentOffset(CGPoint(x: 0, y: contentOffset), animated: animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isCentering = false
        }
    }
}

extension VerticalPicker: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        tickView.scrollOffset = scrollView.contentOffset.y

        let yFraction = 1 - ((scrollView.contentOffset.y + (scrollView.bounds.height / 2)) / tickView.totalHeight)
        let unroundedValue = yFraction * CGFloat(range.upperBound - range.lowerBound) + CGFloat(range.lowerBound)
        let roundedValue = Float(unroundedValue).rounded(toPlaces: decimalPlaces).clamped(to: range)

        let valueString = decimalPlaces == 0 ? "\(Int(roundedValue))" : String(format: "%.2f", roundedValue)
        if range.lowerBound < 0 {
            label.text = (roundedValue >= 0 ? "+" : "") + valueString + suffix
        } else {
            label.text = valueString + suffix
        }

        if roundedValue != value && hasCentered {
            feedbackGenerator.selectionChanged()
            value = roundedValue
            delegate?.verticalPicker(self, didSelect: value)
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            scrollToNearestNumber()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollToNearestNumber()
    }

    func scrollToNearestNumber(animated: Bool = true) {
        let yFraction = (CGFloat(value) - CGFloat(range.lowerBound)) / CGFloat(range.upperBound - range.lowerBound)
        let newOffset = (tickView.totalHeight * (1 - yFraction)) - (self.scrollView.bounds.height / 2)
        scrollView.setContentOffset(CGPoint(x: 0, y: newOffset), animated: animated)
    }
}
