//
//  ScalingPressButton.swift
//  ScalingPressButton
//
//  Created by Daniel Kuntz on 8/11/21.
//

import UIKit

class ScalingPressButton: UIButton {
    var id: String = ""

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        startAnimatingPressActions()
    }

    func startAnimatingPressActions() {
        adjustsImageWhenHighlighted = false
        addTarget(self, action: #selector(animateDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(animateUp), for: [.touchDragExit, .touchCancel, .touchUpInside, .touchUpOutside])
    }

    @objc private func animateDown(sender: UIButton) {
        UIView.animate(withDuration: 0.2,
                       delay: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction],
                       animations: {
            sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }, completion: nil)
    }

    @objc private func animateUp(sender: UIButton) {
        UIView.animate(withDuration: 0.2,
                       delay: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction],
                       animations: {
            sender.transform = .identity
        }, completion: nil)
    }
}
