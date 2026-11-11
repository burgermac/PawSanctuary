//
//  ArtImageCache.swift
//  PawSanctuary
//
//  Every piece of illustrated art (animals, sub-objects, superpower badges,
//  spawners, economy items, wildcard, Second Chances) ships as a 512x512 PNG,
//  but the largest place any of it is drawn is a ~45pt board cell, briefly
//  scaled 1.5x by the merge pop: about 204 pixels on a 3x screen.
//
//  `Image("name")` from the asset catalog decodes the full 512x512 into a
//  1 MiB IOSurface the first time it is shown, and keeps it after the view
//  goes away. Measured on the Simulator (Queue #4, 10 Nov 2026): one opened
//  tier list adds 11 such surfaces that stay after it is dismissed; showing
//  all 318 art images holds 318 MiB. That is the art working set behind the
//  real-device out-of-memory item in TODO.md.
//
//  This cache draws each image once at 256x256 (exactly half the source, so
//  the art is still being scaled down everywhere it appears, including at
//  the peak of the merge pop) and hands SwiftUI that smaller bitmap: 256 KiB
//  per image instead of 1 MiB. The 512 decode is temporary and released
//  inside the autorelease pool. NSCache drops entries under memory pressure;
//  a dropped entry is simply redrawn on next use.
//

import SwiftUI
import UIKit

enum ArtImageCache {

    /// Edge length in pixels of every cached bitmap. Must stay at or above the
    /// largest on-screen pixel size of any art (see the header), or the art
    /// would be scaled up and look soft.
    static let pixelSize: CGFloat = 256

    // NSCache is internally thread-safe, so sharing it across isolation
    // domains is sound even though the type is not marked Sendable.
    nonisolated(unsafe) private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.name = "ArtImageCache"
        return c
    }()

    /// The art named `name` from the asset catalog, drawn at `pixelSize`, or
    /// `nil` if the catalog has no such image (callers fall back to their SF
    /// Symbol placeholder, as before).
    static func image(named name: String) -> Image? {
        guard let ui = uiImage(named: name) else { return nil }
        return Image(uiImage: ui)
    }

    static func uiImage(named name: String) -> UIImage? {
        let key = name as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let small = downsampled(named: name) else { return nil }
        let cost = Int(small.size.width * small.scale * small.size.height * small.scale) * 4
        cache.setObject(small, forKey: key, cost: cost)
        return small
    }

    private static func downsampled(named name: String) -> UIImage? {
        autoreleasepool {
            guard let source = UIImage(named: name) else { return nil }
            let longest = max(source.size.width * source.scale, source.size.height * source.scale)
            // Never scale up: anything already at or below the target is used as is.
            guard longest > pixelSize else { return source }
            let ratio = pixelSize / longest
            let target = CGSize(width: (source.size.width * source.scale * ratio).rounded(),
                                height: (source.size.height * source.scale * ratio).rounded())
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            return UIGraphicsImageRenderer(size: target, format: format).image { ctx in
                ctx.cgContext.interpolationQuality = .high
                source.draw(in: CGRect(origin: .zero, size: target))
            }
        }
    }
}
