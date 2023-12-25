//
//  VideoFrameGrabber.swift
//  Transcriber
//
//  Created by Daniel Kuntz on 11/25/21.
//

import UIKit
import AVFoundation

class VideoFrameGrabber {
    static func getFirstFrameForVideo(atUrl url: URL, completion: @escaping ((UIImage?) -> Void)) {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVURLAsset(url: url)
            let assetIG = AVAssetImageGenerator(asset: asset)
            assetIG.appliesPreferredTrackTransform = true
            assetIG.apertureMode = .encodedPixels

            let cmTime = CMTime(seconds: 0, preferredTimescale: 60)
            var thumbnailImageRef: CGImage?
            do {
                thumbnailImageRef = try assetIG.copyCGImage(at: cmTime, actualTime: nil)
            } catch let error {
                print("Error: \(error)")
            }

            guard let thumbnailImageRef = thumbnailImageRef else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            let image = UIImage(cgImage: thumbnailImageRef)

            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
}

