//
// Copyright (c) WhatsApp Inc. and its affiliates.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree.
//

import UIKit
import SDWebImageWebPCoder

extension CGSize {

    public static func ==(left: CGSize, right: CGSize) -> Bool {
        return left.width.isEqual(to: right.width) && left.height.isEqual(to: right.height)
    }

    public static func <(left: CGSize, right: CGSize) -> Bool {
        return left.width.isLess(than: right.width) && left.height.isLess(than: right.height)
    }

    public static func >(left: CGSize, right: CGSize) -> Bool {
        return !left.width.isLessThanOrEqualTo(right.width) && !left.height.isLessThanOrEqualTo(right.height)
    }

    public static func <=(left: CGSize, right: CGSize) -> Bool {
        return left.width.isLessThanOrEqualTo(right.width) && left.height.isLessThanOrEqualTo(right.height)
    }

    public static func >=(left: CGSize, right: CGSize) -> Bool {
        return !left.width.isLess(than: right.width) && !left.height.isLess(than: right.height)
    }

}

/**
 *  Represents the two supported extensions for sticker images: png and webp.
 */
public enum ImageDataExtension: String {
    case png = "png"
    case webp = "webp"
}

/**
 *  Stores sticker image data along with its supported extension.
 */
class WAImageData {
    let data: Data
    let type: ImageDataExtension

    var bytesSize: Int64 {
        return Int64(data.count)
    }

    /**
     *  Returns whether or not the data represents an animated image.
     *  It will always return false if the image is png.
     */
    lazy var animated: Bool = {
        if type == .webp {
            return SDImageWebPCoder.shared.decodedImage(with: data, options: nil)?.sd_isAnimated ?? false
        } else {
            return false
        }
    }()

    /**
     *  **Not Supporting at this momment**
     *  Returns the minimum frame duration for an animated image in milliseconds.
     *  It will always return -1 if the image is not animated.
     */
    /*
    lazy var minFrameDuration: Double = {
        SDImageWebPCoder.shared.decodedImage(with: data).
        return WebPManager.shared.minFrameDuration(webPData: data) * 1000
    }()
     */

    /**
     *  **Not Supporting at this momment**
     *  Returns the total animation duration for an animated image in milliseconds.
     *  It will always return -1 if the image is not animated.
     */
    /*
    lazy var totalAnimationDuration: Double = {
        return WebPManager.shared.totalAnimationDuration(webPData: data) * 1000
    }()
    */

    /**
     *  Returns the webp data representation of the current image. If the current image is already webp,
     *  the data is simply returned. If it's png, it will returned the webp converted equivalent data.
     */
    lazy var webpData: Data? = {
        if type == .webp {
            return data
        } else {
            let _image: UIImage = UIImage(data: data )!
            return SDImageWebPCoder.shared.encodedData(with: _image, format: .webP, options: [.encodeMaxFileSize: 1024 * 50])
        }
    }()

    /**
     *  Returns a UIImage of the current image data. If data is corrupt, nil will be returned.
     */
    lazy var image: UIImage? = {
        if type == .webp {
            guard let uiImage = SDImageWebPCoder.shared.decodedImage(with: data) else {
                return nil
            }
            return uiImage
        } else {
            // Static image
            return UIImage(data: data)
        }
    }()

    /**
     * Returns an image with the new size.
     */
    func image(withSize size: CGSize) -> UIImage? {
        guard let image = image else { return nil }

        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resizedImage
    }

    init(data: Data, type: ImageDataExtension) {
        self.data = data
        self.type = type
    }

    static func imageDataIfCompliant(contentsOfFile filename: String, isTray: Bool) throws -> WAImageData {
        let fileExtension: String = (filename as NSString).pathExtension

        guard let imageURL = Bundle.main.url(forResource: filename, withExtension: "") else {
            throw WAStickerPackError.fileNotFound
        }

        let data = try Data(contentsOf: imageURL)
        guard let imageType = ImageDataExtension(rawValue: fileExtension) else {
            throw WAStickerPackError.unsupportedImageFormat(fileExtension)
        }

        return try WAImageData.imageDataIfCompliant(rawData: data, extensionType: imageType, isTray: isTray)
    }

    static func imageDataIfCompliant(rawData: Data, extensionType: ImageDataExtension, isTray: Bool) throws -> WAImageData {
        let imageData = WAImageData(data: rawData, type: extensionType)

        guard imageData.bytesSize > 0 else {
            throw WAStickerPackError.invalidImage
        }
        if isTray {
            guard !imageData.animated else {
                throw WAStickerPackError.animatedImagesNotSupported
            }

            guard imageData.bytesSize <= WAPacksLimits.MaxTrayImageFileSize else {
                throw WAStickerPackError.imageTooBig(imageData.bytesSize, false)
            }

            guard imageData.image!.size == WAPacksLimits.TrayImageDimensions else {
                throw WAStickerPackError.incorrectImageSize(imageData.image!.size)
            }
        } else {
            let isAnimated = imageData.animated
            guard (isAnimated && imageData.bytesSize <= WAPacksLimits.MaxAnimatedStickerFileSize) ||
                    (!isAnimated && imageData.bytesSize <= WAPacksLimits.MaxStaticStickerFileSize) else {
                throw WAStickerPackError.imageTooBig(imageData.bytesSize, isAnimated)
            }

            guard imageData.image!.size == WAPacksLimits.ImageDimensions else {
                throw WAStickerPackError.incorrectImageSize(imageData.image!.size)
            }

            /**
             *  **Not Supporting animated at this momment**
             */
            /*
            if isAnimated {
                guard imageData.minFrameDuration >= Double(Limits.MinAnimatedStickerFrameDurationMS) else {
                    throw StickerPackError.minFrameDurationTooShort(imageData.minFrameDuration)
                }

                guard imageData.totalAnimationDuration <= Double(Limits.MaxAnimatedStickerTotalDurationMS) else {
                    throw StickerPackError.totalAnimationDurationTooLong(imageData.totalAnimationDuration)
                }
            }
             */
        }

        return imageData
    }
}
