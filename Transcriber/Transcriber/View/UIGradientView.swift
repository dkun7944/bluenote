//
//  UIGradientView.swift
//  Transcriber
//
//  Created by Daniel Kuntz on 10/28/23.
//

import UIKit

class UIGradientView: UIView {

    private(set) var gradientLayer: CAGradientLayer

    var colors: [UIColor] = [UIColor.red, UIColor.blue] {
        didSet {
            updateGradientColors()
        }
    }

    var locations: [NSNumber]? {
        didSet {
            updateGradientLocations()
        }
    }

    override init(frame: CGRect) {
        gradientLayer = CAGradientLayer()
        super.init(frame: frame)
        setupGradientLayer()
    }

    required init?(coder aDecoder: NSCoder) {
        gradientLayer = CAGradientLayer()
        super.init(coder: aDecoder)
        setupGradientLayer()
    }

    private func setupGradientLayer() {
        gradientLayer.frame = self.bounds
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        updateGradientColors()
        updateGradientLocations()
        self.layer.insertSublayer(gradientLayer, at: 0)
    }

    private func updateGradientColors() {
        gradientLayer.colors = colors.map { $0.cgColor }
    }

    private func updateGradientLocations() {
        gradientLayer.locations = locations
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = self.bounds
    }
}
