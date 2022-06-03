//
// Copyright (c) WhatsApp Inc. and its affiliates.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree.
//

import UIKit

public struct WAPacksLimits {
    public static let MaxStaticStickerFileSize: Int = 100 * 1024
    public static let MaxAnimatedStickerFileSize: Int = 500 * 1024
    public static let MaxTrayImageFileSize: Int = 50 * 1024

    public static let MinAnimatedStickerFrameDurationMS: Int = 8
    public static let MaxAnimatedStickerTotalDurationMS: Int = 10000

    public static let TrayImageDimensions: CGSize = CGSize(width: 96, height: 96)
    public static let ImageDimensions: CGSize = CGSize(width: 512, height: 512)

    public static let MinStickersPerPack: Int = 3
    public static let MaxStickersPerPack: Int = 30

    public static let MaxCharLimit128: Int = 128

    public static let MaxEmojisCount: Int = 3
}
