//
//  ProjectsEmptyStateView.swift
//  Transcriber
//
//  Created by Daniel Kuntz on 10/26/23.
//

import UIKit
import PureLayout

class ProjectsEmptyStateView: UIView {
    init() {
        super.init(frame: .zero)

        let imageView = UIImageView()
        imageView.image = UIImage(named: "icon-emptystate")
        addSubview(imageView)

        let topLabel = UILabel()
        topLabel.text = "Welcome to BlueNote"
        topLabel.font = UIFont.systemFont(ofSize: 21.0, weight: .bold)
        topLabel.textColor = .white
        addSubview(topLabel)

        let bottomLabel = UILabel()
        bottomLabel.text = "BlueNote can help you learn songs by ear.\n\nAdd music by tapping + in the upper right corner."
        bottomLabel.font = UIFont.systemFont(ofSize: 16.0, weight: .regular)
        bottomLabel.textColor = .white
        bottomLabel.numberOfLines = 0
        bottomLabel.textAlignment = .center
        addSubview(bottomLabel)

        imageView.autoAlignAxis(.horizontal, toSameAxisOf: self, withOffset: -50.0)
        imageView.autoAlignAxis(toSuperviewAxis: .vertical)
        topLabel.autoPinEdge(.top, to: .bottom, of: imageView)
        topLabel.autoAlignAxis(toSuperviewAxis: .vertical)
        bottomLabel.autoPinEdge(.top, to: .bottom, of: topLabel, withOffset: 8.0)
        bottomLabel.autoPinEdge(toSuperviewEdge: .leading, withInset: 30.0)
        bottomLabel.autoPinEdge(toSuperviewEdge: .trailing, withInset: 30.0)
        bottomLabel.autoAlignAxis(toSuperviewAxis: .vertical)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
