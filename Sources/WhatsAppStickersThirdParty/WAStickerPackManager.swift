//
// Copyright (c) WhatsApp Inc. and its affiliates.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree.
//

import UIKit

extension Dictionary {
    func bytesSize() -> Int {
        let encoder = NSKeyedArchiver(requiringSecureCoding: true)
        encoder.encode(self, forKey: "dictionary")
        encoder.finishEncoding()

        return encoder.encodedData.count
    }
}

class WAStickerPackManager {

    static let queue: DispatchQueue = DispatchQueue(label: "stickerPackQueue")

    static func stickersJSON(contentsOfFile filename: String) throws -> [String: Any] {
        if let path = Bundle.main.path(forResource: filename, ofType: "wasticker") {
            let data: Data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
            return try JSONSerialization.jsonObject(with: data) as! [String: Any]
        }

        throw WAStickerPackError.fileNotFound
    }

    /**
     *  Retrieves sticker packs from a JSON dictionary.
     *  If the processing of a certain sticker pack encounters an exception (see methods in StickerPack.swift),
     *  that sticker pack won't be returned along with the rest (eg if identifer isn't unique or stickers have
     *  invalid image dimensions)
     *
     *  - Parameter dict: JSON dictionary
     *  - Parameter completionHandler: called on the main queue
     */
    static func fetchStickerPacks(fromJSON dict: [String: Any], completionHandler: @escaping ([WAStickerPack]) -> Void) {
        queue.async {
            let packs: [[String: Any]] = dict["sticker_packs"] as! [[String: Any]]
            var stickerPacks: [WAStickerPack] = []
            var currentIdentifiers: [String: Bool] = [:]

            let iosAppStoreLink: String? = dict["ios_app_store_link"] as? String
            let androidAppStoreLink: String? = dict["android_play_store_link"] as? String
            WAInteroperability.iOSAppStoreLink = iosAppStoreLink != "" ? iosAppStoreLink : nil
            WAInteroperability.AndroidStoreLink = androidAppStoreLink != "" ? androidAppStoreLink : nil

            for pack in packs {
                let packName: String = pack["name"] as! String
                let packPublisher: String = pack["publisher"] as! String
                let packTrayImageFileName: String = pack["tray_image_file"] as! String

                var packPublisherWebsite: String? = pack["publisher_website"] as? String
                var packPrivacyPolicyWebsite: String? = pack["privacy_policy_website"] as? String
                var packLicenseAgreementWebsite: String? = pack["license_agreement_website"] as? String
                // If the strings are empty, consider them as nil
                packPublisherWebsite = packPublisherWebsite != "" ? packPublisherWebsite : nil
                packPrivacyPolicyWebsite = packPrivacyPolicyWebsite != "" ? packPrivacyPolicyWebsite : nil
                packLicenseAgreementWebsite = packLicenseAgreementWebsite != "" ? packLicenseAgreementWebsite : nil

                // Pack identifier has to be a valid string and be unique
                let packIdentifier: String? = pack["identifier"] as? String
                if packIdentifier != nil && currentIdentifiers[packIdentifier!] == nil {
                    currentIdentifiers[packIdentifier!] = true
                } else {
                    if let packIdentifier = packIdentifier {
                        fatalError("Missing identifier or a sticker pack already has the identifier \(packIdentifier).")
                    }

                    fatalError("\(packName) must have an identifier and it must be unique.")
                }

                let animatedStickerPack: Bool? = pack["animated_sticker_pack"] as? Bool

                var stickerPack: WAStickerPack?

                do {
                    stickerPack = try WAStickerPack(identifier: packIdentifier!, name: packName, publisher: packPublisher, trayImageFileName: packTrayImageFileName, animatedStickerPack: animatedStickerPack, publisherWebsite: packPublisherWebsite, privacyPolicyWebsite: packPrivacyPolicyWebsite, licenseAgreementWebsite: packLicenseAgreementWebsite)
                } catch WAStickerPackError.fileNotFound {
                    fatalError("\(packTrayImageFileName) not found.")
                } catch WAStickerPackError.emptyString {
                    fatalError("The name, identifier, and publisher strings can't be empty.")
                } catch WAStickerPackError.unsupportedImageFormat(let imageFormat) {
                    fatalError("\(packTrayImageFileName): \(imageFormat) is not a supported format.")
                } catch WAStickerPackError.invalidImage {
                    fatalError("Tray image file size is 0 KB.")
                } catch WAStickerPackError.imageTooBig(let imageFileSize, _) {
                    let roundedSize = round((Double(imageFileSize) / 1024) * 100) / 100;
                    fatalError("\(packTrayImageFileName): \(roundedSize) KB is bigger than the max tray image file size (\(WAPacksLimits.MaxTrayImageFileSize / 1024) KB).")
                } catch WAStickerPackError.incorrectImageSize(let imageDimensions) {
                    fatalError("\(packTrayImageFileName): \(imageDimensions) is not compliant with tray dimensions requirements, \(WAPacksLimits.TrayImageDimensions).")
                } catch WAStickerPackError.animatedImagesNotSupported {
                    fatalError("\(packTrayImageFileName) is an animated image. Animated images are not supported.")
                } catch WAStickerPackError.stringTooLong {
                    fatalError("Name, identifier, and publisher of sticker pack must be less than \(WAPacksLimits.MaxCharLimit128) characters.")
                } catch {
                    fatalError(error.localizedDescription)
                }

                let stickers: [[String: Any]] = pack["stickers"] as! [[String: Any]]
                for sticker in stickers {
                    let emojis: [String]? = sticker["emojis"] as? [String]

                    let filename = sticker["image_file"] as! String
                    do {
                        try stickerPack!.addSticker(contentsOfFile: filename, emojis: emojis)
                    } catch WAStickerPackError.stickersNumOutsideAllowableRange {
                        fatalError("Sticker count outside the allowable limit (\(WAPacksLimits.MaxStickersPerPack) stickers per pack).")
                    } catch WAStickerPackError.fileNotFound {
                        fatalError("\(filename) not found.")
                    } catch WAStickerPackError.unsupportedImageFormat(let imageFormat) {
                        fatalError("\(filename): \(imageFormat) is not a supported format.")
                    } catch WAStickerPackError.invalidImage {
                        fatalError("Image file size is 0 KB.")
                    } catch WAStickerPackError.imageTooBig(let imageFileSize, let animated) {
                        let roundedSize = round((Double(imageFileSize) / 1024) * 100) / 100;
                        let maxSize = animated ? WAPacksLimits.MaxAnimatedStickerFileSize : WAPacksLimits.MaxStaticStickerFileSize
                        fatalError("\(filename): \(roundedSize) KB is bigger than the max file size (\(maxSize / 1024) KB).")
                    } catch WAStickerPackError.incorrectImageSize(let imageDimensions) {
                        fatalError("\(filename): \(imageDimensions) is not compliant with sticker images dimensions, \(WAPacksLimits.ImageDimensions).")
                    } catch WAStickerPackError.tooManyEmojis {
                        fatalError("\(filename) has too many emojis. \(WAPacksLimits.MaxEmojisCount) is the maximum number.")
                    } catch WAStickerPackError.minFrameDurationTooShort(let minFrameDuration) {
                        let roundedDuration = round(minFrameDuration)
                        fatalError("\(filename): \(roundedDuration) ms is shorter than the min frame duration (\(WAPacksLimits.MinAnimatedStickerFrameDurationMS) ms).")
                    } catch WAStickerPackError.totalAnimationDurationTooLong(let totalFrameDuration) {
                        let roundedDuration = round(totalFrameDuration)
                        fatalError("\(filename): \(roundedDuration) ms is longer than the max total animation duration (\(WAPacksLimits.MaxAnimatedStickerTotalDurationMS) ms).")
                    } catch WAStickerPackError.animatedStickerPackWithStaticStickers {
                        fatalError("Animated sticker pack contains static stickers.")
                    } catch WAStickerPackError.staticStickerPackWithAnimatedStickers {
                        fatalError("Static sticker pack contains animated stickers.")
                    } catch {
                        fatalError(error.localizedDescription)
                    }
                }

                if stickers.count < WAPacksLimits.MinStickersPerPack {
                  fatalError("Sticker count smaller that the allowable limit (\(WAPacksLimits.MinStickersPerPack) stickers per pack).")
                }

                stickerPacks.append(stickerPack!)
            }

            DispatchQueue.main.async {
                completionHandler(stickerPacks)
            }
        }
    }

}
