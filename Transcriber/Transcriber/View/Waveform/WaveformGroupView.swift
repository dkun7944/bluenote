//
//  WaveformGroupView.swift
//  WaveformGroupView
//
//  Created by Daniel Kuntz on 8/11/21.
//

import UIKit
import PureLayout

protocol WaveformGroupDelegate: AnyObject {
    func didScroll(toTime time: TimeInterval, userInitiated: Bool)
    func didSetLoopRange(to range: ClosedRange<Float>)
}

class WaveformGroupView: UIView {

    // MARK: - Subviews

    private var scrollView: UIScrollView!
    private var invisibleScrollingView: UIView!
    private var invisibleScrollingViewWidthConstraint: NSLayoutConstraint!
    private var waveformView: WaveformView!
    private var tickView: TickView!
    private var loopView: TrimView!

    private var pinchGR: UIPinchGestureRecognizer!
    private var startScale: CGFloat = 1
    private var startLoopProgress: ClosedRange<Float> = 0...1
    private(set) var zoomScale: CGFloat = 1

    var hasShownLoopView: Bool = false
    weak var delegate: WaveformGroupDelegate?

    // MARK: - Setup

    override func awakeFromNib() {
        super.awakeFromNib()

        waveformView = WaveformView()
        addSubview(waveformView)

        tickView = TickView()
        addSubview(tickView)

        scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        addSubview(scrollView)

        invisibleScrollingView = UIView()
        invisibleScrollingView.backgroundColor = .clear
        scrollView.addSubview(invisibleScrollingView)

        loopView = TrimView()
        loopView.color = UIColor(hex: "0984FE")
        loopView.trimViewBgColor = loopView.color.withAlphaComponent(0.1)
        loopView.alpha = 0
        loopView.delegate = self
        loopView.touchHandler = self
        loopView.extendsProgressRange = false
        invisibleScrollingView.addSubview(loopView)

        let playheadImageView = UIImageView(image: UIImage(named: "playhead"))
        playheadImageView.isUserInteractionEnabled = false
        addSubview(playheadImageView)

        scrollView.autoPinEdgesToSuperviewEdges()
        waveformView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 24, left: 0, bottom: 25, right: 0))
        loopView.autoPinEdge(.leading, to: .leading, of: invisibleScrollingView)
        loopView.autoPinEdge(.top, to: .top, of: waveformView)
        loopView.autoPinEdge(.trailing, to: .trailing, of: invisibleScrollingView)
        loopView.autoPinEdge(.bottom, to: .bottom, of: waveformView)
        tickView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        tickView.autoPinEdge(.top, to: .bottom, of: waveformView)
        invisibleScrollingView.autoPinEdgesToSuperviewEdges()
        invisibleScrollingViewWidthConstraint = invisibleScrollingView.autoSetDimension(.width, toSize: 100)
        invisibleScrollingView.autoMatch(.height, to: .height, of: scrollView)
        playheadImageView.autoAlignAxis(toSuperviewAxis: .vertical)
        playheadImageView.autoPinEdge(toSuperviewEdge: .top, withInset: 18)
        playheadImageView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 19)

        pinchGR = UIPinchGestureRecognizer(target: self, action: #selector(pinchHandler(_:)))
        addGestureRecognizer(pinchGR)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        scrollView.contentInset = UIEdgeInsets(top: 0,
                                               left: bounds.width / 2,
                                               bottom: 0,
                                               right: bounds.width / 2)
    }

    @objc private func pinchHandler(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            startScale = zoomScale
            startLoopProgress = loopView.progressRange
            loopView.isUserInteractionEnabled = false
        case .ended, .failed, .cancelled:
            loopView.isUserInteractionEnabled = true
        default: break
        }

        setZoomScale((startScale * recognizer.scale).clamped(to: 0.1...10))
    }

    func stopDecelerating() {
        scrollView.setContentOffset(scrollView.contentOffset, animated: false)
    }

    func setZoomScale(_ scale: CGFloat) {
        let playheadLocation = scrollView.contentOffset.x + (scrollView.bounds.width / 2)
        let curTimeFraction = playheadLocation / waveformView.totalWidth

        zoomScale = scale
        waveformView.set(zoomScale: zoomScale, scrollOffset: scrollView.contentOffset.x)
        tickView.set(zoomScale: zoomScale, scrollOffset: scrollView.contentOffset.x)
        invisibleScrollingViewWidthConstraint.constant = waveformView.totalWidth

        let newPlayheadLocation = (curTimeFraction * waveformView.totalWidth) - (scrollView.bounds.width / 2)
        scrollView.contentOffset = CGPoint(x: newPlayheadLocation, y: 0)
        scrollViewDidScroll(scrollView)

        layoutIfNeeded()
        loopView.setProgressRange(startLoopProgress)
    }

    func addFlag() {
        let flag = FlagView(frame: .zero)
        flag.alpha = 0
        invisibleScrollingView.addSubview(flag)

        flag.autoPinEdge(.bottom, to: .bottom, of: waveformView)
        let topInset = scrollView.bounds.height - waveformView.bounds.height - tickView.bounds.height - flag.flagHeight
        flag.autoPinEdge(toSuperviewEdge: .top, withInset: topInset)
        flag.leadingConstraint = flag.autoPinEdge(toSuperviewEdge: .leading,
                                                  withInset: scrollView.contentOffset.x + (scrollView.bounds.width / 2))

        UIView.animate(withDuration: 0.2) {
            flag.alpha = 1
        }

        flag.textField.becomeFirstResponder()
    }

    func scrub(toProgress progress: Float) {
        let contentOffset = (CGFloat(progress) * waveformView.totalWidth) - waveformView.bounds.width / 2
        scrollView.contentOffset = CGPoint(x: contentOffset, y: 0)
    }

    func showLoopView() {
        if !hasShownLoopView {
            moveLoopToCurrentFrame()
            hasShownLoopView = true
        } else {
            loopView.recalculateProgressRange()
            loopView.sendProgressToDelegate()
        }

        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut], animations: {
            self.loopView.alpha = 1
        }, completion: nil)
    }

    func setLoopRange(_ range: ClosedRange<Float>) {
        loopView.setProgressRange(range)
    }

    func moveLoopToCurrentFrame() {
        let offset: CGFloat = 50
        let lowerProgress = (scrollView.contentOffset.x + offset) / waveformView.totalWidth
        let upperProgress = (scrollView.contentOffset.x + scrollView.bounds.width - offset) / waveformView.totalWidth
        UIView.animate(withDuration: 0.2, delay: 0.0, options: [.curveEaseInOut]) {
            self.loopView.setProgressRange(Float(lowerProgress)...Float(upperProgress))
            self.loopView.layoutIfNeeded()
        }
    }

    func hideLoopView() {
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseIn], animations: {
            self.loopView.alpha = 0
        }, completion: nil)
    }

    func render(_ sound: Sound) {
        waveformView.sound = sound
        waveformView.setNeedsDisplay()
        invisibleScrollingViewWidthConstraint.constant = waveformView.totalWidth

        tickView.soundDuration = sound.duration
        tickView.setNeedsDisplay()

        scrollView.contentInset = UIEdgeInsets(top: 0,
                                               left: bounds.width / 2,
                                               bottom: 0,
                                               right: bounds.width / 2)
    }
}

extension WaveformGroupView: TrimViewDelegate {
    func trimmed(to progressRange: ClosedRange<Float>) {
        delegate?.didSetLoopRange(to: progressRange)
    }
}

extension WaveformGroupView: TrimViewTouchHandler {
    func handleTouchDown() {
        scrollView.isScrollEnabled = false
    }

    func handleTouchUp() {
        scrollView.isScrollEnabled = true
    }
}

extension WaveformGroupView: UIScrollViewDelegate {
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        print(scrollView.zoomScale)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        waveformView.set(zoomScale: zoomScale, scrollOffset: scrollView.contentOffset.x)
        tickView.set(zoomScale: zoomScale, scrollOffset: scrollView.contentOffset.x)

        let userInitiated = scrollView.isTracking || scrollView.isDecelerating || scrollView.isDragging
        let playheadLocation = scrollView.contentOffset.x + (scrollView.bounds.width / 2)
        let timeFraction = playheadLocation / waveformView.totalWidth
        let time = (waveformView.sound?.duration ?? 1) * timeFraction
        let clampedTime = time.clamped(to: 0...(waveformView.sound?.duration ?? 1))
        delegate?.didScroll(toTime: clampedTime, userInitiated: userInitiated)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        TranscriberAudioEngine.shared.scrubbing = true
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, 
                                  willDecelerate decelerate: Bool) {
        if !decelerate && !TranscriberAudioEngine.shared.frozen {
            TranscriberAudioEngine.shared.scrubbing = false
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if !TranscriberAudioEngine.shared.frozen {
            TranscriberAudioEngine.shared.scrubbing = false
        }
    }
}
