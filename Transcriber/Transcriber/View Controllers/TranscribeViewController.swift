//
//  TranscribeViewController.swift
//  Transcriber
//
//  Created by Daniel Kuntz on 8/11/21.
//

import UIKit
import UniformTypeIdentifiers
import PhotosUI
import MobileCoreServices

class TranscribeViewController: UIViewController {

    // MARK: - Outlets

    @IBOutlet weak var videoSwitcherButton: UIBarButtonItem!
    @IBOutlet weak var waveformGroupView: WaveformGroupView!
    @IBOutlet weak var loopButton: ScalingPressButton!
    @IBOutlet weak var loopMoveButton: ScalingPressButton!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var freezeButton: ScalingPressButton!
    @IBOutlet weak var playButton: ScalingPressButton!
    @IBOutlet weak var eqContainer: UIView!
    @IBOutlet weak var equalizer: EqualizerView!
    @IBOutlet weak var channelModeButton: ScalingPressButton!
    @IBOutlet weak var sliderContainer: UIStackView!
    @IBOutlet weak var centsPicker: VerticalPicker!
    @IBOutlet weak var semitonesPicker: VerticalPicker!
    @IBOutlet weak var speedPicker: VerticalPicker!
    @IBOutlet weak var videoScrollView: UIScrollView!
    @IBOutlet weak var videoView: UIView!

    private var player: AVPlayer?
    private(set) var playerLayer: AVPlayerLayer?

    private var videoViewVisible: Bool = true
    private var sound: Sound?
    private var isLooping: Bool = false
    private var feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var seeking: Bool = false
    private var viewHasAppeared: Bool = false

    var project: Project?

    // MARK: - Setup
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        loadProject()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        TranscriberAudioEngine.shared.reset()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let contentOffset = project?.videoViewContentOffset,
           let zoomScale = project?.videoViewZoomScale {
            videoScrollView.setZoomScale(zoomScale, animated: false)
            videoScrollView.setContentOffset(contentOffset, animated: false)
        }
        viewHasAppeared = true
    }

    private func setup() {
        videoScrollView.delegate = self
        videoScrollView.showsVerticalScrollIndicator = false
        videoScrollView.showsHorizontalScrollIndicator = false

        waveformGroupView.delegate = self
        equalizer.delegate = self

        centsPicker.setRange(-50...50, stride: 1)
        centsPicker.delegate = self
        semitonesPicker.setRange(-12...12, stride: 1)
        semitonesPicker.delegate = self
        speedPicker.setRange(0.2...1.5, stride: 0.1, centerValue: 1, decimals: 2, suffix: "x")
        speedPicker.delegate = self

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(navigationBarTapped))
        self.navigationController?.navigationBar.addGestureRecognizer(tapGesture)
        if project?.needsRename ?? false {
            navigationBarTapped()
            project?.needsRename = false
        }

        TranscriberAudioEngine.shared.playbackProgressCallback = { progress in
            DispatchQueue.main.async {
                self.waveformGroupView.scrub(toProgress: progress)
            }
        }

        TranscriberAudioEngine.shared.scrubbingPausedCallback = {
            DispatchQueue.main.async {
                UIView.transition(with: self.playButton, duration: 0.3, options: [.transitionFlipFromLeft], animations: {
                    self.playButton.setImage(UIImage(named: "glyph_play"), for: .normal)
                }, completion: nil)
            }
        }

        TranscriberAudioEngine.shared.start()
    }

    @objc private func navigationBarTapped() {
        let alertController = UIAlertController(title: "Name this project", message: nil, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "Project name"
        }

        let submitAction = UIAlertAction(title: "Next", style: .default) { [weak self, weak alertController] _ in
            guard let textField = alertController?.textFields?.first,
                  let text = textField.text else { return }
            self?.project?.name = text
            self?.title = text
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        alertController.addAction(submitAction)
        alertController.addAction(cancelAction)

        self.present(alertController, animated: true)
    }

    private func loadProject() {
        guard let project = project else {
            return
        }

        title = project.name
        loadAudio(atURL: project.audioURL)
        
        if let videoURL = project.videoURL {
            loadVideo(atURL: videoURL)
            setVideoViewVisible(project.videoViewVisible, animated: false)
        } else {
            setVideoViewVisible(false, animated: false)
            videoSwitcherButton.isHidden = true
        }

        TranscriberAudioEngine.shared.seek(offset: project.playheadLocation)

        waveformGroupView.setZoomScale(project.waveformZoomScale)
        setLoopingOn(project.loopingOn)
        if let loopRange = project.loopRange {
            waveformGroupView.hasShownLoopView = true
            waveformGroupView.setLoopRange(loopRange)
        }

        if let eqFreqRange = project.eqFreqRange {
            equalizer.setFrequencyRange(eqFreqRange)
        }

        TranscriberAudioEngine.shared.channelMode = project.channelMode
        channelModeButton.setTitle(project.channelMode.displayName, for: .normal)

        centsPicker.setValue(project.cents)
        semitonesPicker.setValue(project.semitones)
        speedPicker.setValue(project.speed)
    }

    private func loadAudio(atURL url: URL?) {
        guard let url = url else {
            return
        }

        sound = Sound(fileUrl: url)
        waveformGroupView.render(sound!)
        equalizer.sound = sound
        TranscriberAudioEngine.shared.sound = sound
        waveformGroupView.scrub(toProgress: 0)
    }

    private func loadVideo(atURL url: URL?) {
        guard let url = url else {
            return
        }

        player = AVPlayer(url: url)
        playerLayer?.removeFromSuperlayer()
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = videoView.bounds
        playerLayer?.videoGravity = .resizeAspect
        videoView.layer.addSublayer(playerLayer!)

        videoScrollView.minimumZoomScale = 1
        videoScrollView.maximumZoomScale = 7
    }
    
    @IBAction func loopTapped(_ sender: UIButton) {
        feedbackGenerator.impactOccurred()
        setLoopingOn(!isLooping)
        project?.loopingOn = isLooping
    }

    func setLoopingOn(_ on: Bool) {
        isLooping = on
        if !isLooping {
            waveformGroupView.hideLoopView()
            loopButton.setImage(UIImage(named: "glyph_loop"), for: .normal)
            TranscriberAudioEngine.shared.disableLooping()
            loopMoveButton.isUserInteractionEnabled = false
            UIView.animate(withDuration: 0.2) {
                self.loopMoveButton.alpha = 0.4
            }
        } else {
            waveformGroupView.showLoopView()
            loopButton.setImage(UIImage(named: "glyph_loop_filled"), for: .normal)
            TranscriberAudioEngine.shared.enableLooping()
            loopMoveButton.isUserInteractionEnabled = true
            UIView.animate(withDuration: 0.2) {
                self.loopMoveButton.alpha = 1
            }
        }
    }

    @IBAction func videoSwitchTapped(_ sender: Any) {
        feedbackGenerator.impactOccurred()
        setVideoViewVisible(!videoViewVisible, animated: true)
    }

    func setVideoViewVisible(_ visible: Bool, animated: Bool = true) {
        videoViewVisible = visible
        project?.videoViewVisible = visible

        UIView.animate(withDuration: animated ? 0.5 : 0.0,
                       delay: 0,
                       usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0.1,
                       options: [.curveEaseInOut, .beginFromCurrentState],
                       animations: {
            self.videoScrollView.isHidden = !self.videoViewVisible
            self.videoScrollView.alpha = self.videoViewVisible ? 1 : 0
            self.eqContainer.isHidden = self.videoViewVisible
            self.eqContainer.alpha = self.videoViewVisible ? 0 : 1
            self.sliderContainer.isHidden = self.videoViewVisible
            self.sliderContainer.alpha = self.videoViewVisible ? 0 : 1
            self.view.layoutIfNeeded()
        }, completion: nil)

        UIView.transition(with: self.navigationController!.navigationBar,
                          duration: animated ? 0.2 : 0.0,
                          options: [.transitionCrossDissolve, .allowUserInteraction],
                          animations: {
            self.videoSwitcherButton.image = self.videoViewVisible ? UIImage(named: "glyph_video") : UIImage(named: "glyph_audio")
        }, completion: nil)
    }

    @IBAction func loopMoveTapped(_ sender: Any) {
        waveformGroupView.moveLoopToCurrentFrame()
        feedbackGenerator.impactOccurred()
    }

    @IBAction func playPauseTapped(_ sender: UIButton) {
        if TranscriberAudioEngine.shared.playing {
            TranscriberAudioEngine.shared.stopPlaying()
            UIView.transition(with: sender, duration: 0.3, options: [.transitionFlipFromLeft], animations: {
                sender.setImage(UIImage(named: "glyph_play"), for: .normal)
            }, completion: nil)
        } else {
            waveformGroupView.stopDecelerating()
            TranscriberAudioEngine.shared.startPlaying()
            TranscriberAudioEngine.shared.frozen = false
            UIView.transition(with: sender, duration: 0.3, options: [.transitionFlipFromLeft], animations: {
                sender.setImage(UIImage(named: "glyph_pause"), for: .normal)
            }, completion: nil)

            UIView.transition(with: self.freezeButton, duration: 0.3, options: [.transitionCrossDissolve], animations: {
                self.freezeButton.setImage(UIImage(named: "glyph_freeze"), for: .normal)
            }, completion: nil)
        }
        feedbackGenerator.impactOccurred()
    }

    @IBAction func ffTapped(_ sender: Any) {
        TranscriberAudioEngine.shared.seek(offset: 1)
        feedbackGenerator.impactOccurred()
    }

    @IBAction func rwTapped(_ sender: Any) {
        TranscriberAudioEngine.shared.seek(offset: -1)
        feedbackGenerator.impactOccurred()
    }
    
    @IBAction func freezeTapped(_ sender: UIButton) {
        TranscriberAudioEngine.shared.frozen = !TranscriberAudioEngine.shared.frozen
        let newImage = UIImage(named: TranscriberAudioEngine.shared.frozen ? "glyph_freeze_filled" : "glyph_freeze")
        sender.setImage(newImage, for: .normal)
        feedbackGenerator.impactOccurred()
    }

    @IBAction func flagTapped(_ sender: Any) {
        waveformGroupView.addFlag()
    }
    
    @IBAction func channelModeTapped(_ sender: UIButton) {
        TranscriberAudioEngine.shared.channelMode = TranscriberAudioEngine.shared.channelMode.next()
        sender.setTitle(TranscriberAudioEngine.shared.channelMode.displayName, for: .normal)
        feedbackGenerator.impactOccurred()
        project?.channelMode = TranscriberAudioEngine.shared.channelMode
    }
}

extension TranscribeViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return videoView
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard viewHasAppeared else {
            return
        }

        project?.debounceSetProperty(\.videoViewContentOffset, newValue: scrollView.contentOffset)
        project?.debounceSetProperty(\.videoViewZoomScale, newValue: scrollView.zoomScale)
    }
}

extension TranscribeViewController: WaveformGroupDelegate {
    func didScroll(toTime time: TimeInterval, userInitiated: Bool) {
        guard !time.isNaN else {
            return
        }
        
        let minutes = Int(time / 60)
        let seconds = Int(time.truncatingRemainder(dividingBy: 60))
        let milliseconds = Int((time - floor(time)) * 100)
        timeLabel.text = ((minutes < 10) ? "0" : "") + "\(minutes)" + ":" +
                         ((seconds < 10) ? "0" : "") + "\(seconds)" + "." +
                         ((milliseconds < 10) ? "0" : "") + "\(milliseconds)"

        equalizer.time = time

        if let sound = sound, userInitiated {
            let durationFraction = Float(time / sound.duration)
            TranscriberAudioEngine.shared.scrub(toProgress: durationFraction)
        }

        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        project?.debounceSetProperty(\.playheadLocation, newValue: time)
        project?.debounceSetProperty(\.waveformZoomScale, newValue: waveformGroupView.zoomScale)
    }

    func didSetLoopRange(to range: ClosedRange<Float>) {
        TranscriberAudioEngine.shared.setLoopProgressRange(range)
        project?.debounceSetProperty(\.loopRange, newValue: range)
    }
}

extension TranscribeViewController: EqualizerViewDelegate {
    func trimmed(to freqRange: ClosedRange<Float>) {
        TranscriberAudioEngine.shared.setFilterFreqRange(freqRange)
        project?.debounceSetProperty(\.eqFreqRange, newValue: freqRange)
    }
}

extension TranscribeViewController: VerticalPickerDelegate {
    func verticalPicker(_ picker: VerticalPicker, didSelect value: Float) {
        if picker === centsPicker || picker === semitonesPicker {
            let semitones = Float(semitonesPicker.value)
            let cents = Float(centsPicker.value)
            TranscriberAudioEngine.shared.setPitchShift(semitones, cents: cents)
            project?.debounceSetProperty(\.semitones, newValue: semitones)
            project?.debounceSetProperty(\.cents, newValue: cents)
        } else if picker === speedPicker {
            TranscriberAudioEngine.shared.setSpeed(Double(value))
            project?.debounceSetProperty(\.speed, newValue: value)
        }
    }
}
