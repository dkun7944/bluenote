//
//  ProjectsTableViewCell.swift
//  Transcriber
//
//  Created by Daniel Kuntz on 11/25/21.
//

import UIKit

class ProjectsTableViewCell: UITableViewCell {

    static let reuseId = "projectCell"

    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!

    func setProject(_ project: Project) {
        titleLabel.text = project.name
        subtitleLabel.text = project.formattedDuration + " · " + project.formattedLastModifiedDate
        self.backgroundImageView.image = nil

        if let url = project.videoURL {
            VideoFrameGrabber.getFirstFrameForVideo(atUrl: url) { [weak self] image in
                UIView.animate(withDuration: 0.2) {
                    self?.backgroundImageView.image = image?.blurred(radius: 5.0)
                }
            }
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        UIView.animate(withDuration: 0.2) {
            self.alpha = highlighted ? 0.6 : 1
            self.transform = highlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
        }
    }
}

extension UIImage {
    func blurred(radius: CGFloat) -> UIImage? {
        guard let ciImage = CIImage(image: self) else { return nil }
        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(radius, forKey: kCIInputRadiusKey)
        guard let outputImage = filter?.outputImage else { return nil }
        let context = CIContext(options: nil)
        if let cgImage = context.createCGImage(outputImage, from: ciImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}
