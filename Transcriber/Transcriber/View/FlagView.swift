//
//  FlagView.swift
//  FlagView
//
//  Created by Daniel Kuntz on 8/28/21.
//

import UIKit

class FlagView: UIView {

    // MARK: - Variables

    private var flagView: UIView!
    private var stemView: UIView!
    private(set) var textField: UITextField!

    var leadingConstraint: NSLayoutConstraint?

    let flagHeight: CGFloat = 24
    let textMargin: CGFloat = 6

    var flagColor: UIColor = UIColor(hex: "F8D74A")
    var textColor: UIColor = .black

    private var prevText: String = "Flag"

    // MARK: - Setup

    override init(frame: CGRect) {
        super.init(frame: frame)

        flagView = UIView()
        flagView.layer.cornerRadius = 4
        flagView.layer.cornerCurve = .continuous
        flagView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMaxYCorner, .layerMaxXMinYCorner]
        flagView.backgroundColor = flagColor
        addSubview(flagView)

        textField = UITextField()
        textField.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        textField.textColor = textColor
        textField.delegate = self
        textField.returnKeyType = .done
        textField.keyboardAppearance = .dark
        flagView.addSubview(textField)

        stemView = UIView()
        stemView.backgroundColor = flagColor
        addSubview(stemView)

        flagView.autoSetDimension(.height, toSize: flagHeight)
        flagView.autoPinEdge(toSuperviewEdge: .leading)
        flagView.autoPinEdge(toSuperviewEdge: .trailing)
        flagView.autoPinEdge(toSuperviewEdge: .top)

        textField.autoAlignAxis(toSuperviewAxis: .horizontal)
        textField.autoPinEdge(toSuperviewEdge: .leading, withInset: textMargin)
        textField.autoPinEdge(toSuperviewEdge: .trailing, withInset: textMargin)

        stemView.autoSetDimension(.width, toSize: 1)
        stemView.autoPinEdge(.top, to: .bottom, of: flagView)
        stemView.autoPinEdge(toSuperviewEdge: .bottom)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

extension FlagView: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        let position = textField.endOfDocument
        textField.selectedTextRange = textField.textRange(from: position, to: position)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let text = textField.text,
           text.trimmingCharacters(in: .whitespaces).isEmpty {
            textField.text = prevText
        }

        textField.resignFirstResponder()
        prevText = textField.text ?? prevText
        return true
    }
}
