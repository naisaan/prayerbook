import UIKit

/// Where the cover picture goes, so its star lines up exactly with the splash screen's star:
/// the same size, in the middle of the screen. When the splash fades, the star stays put and
/// the cover appears around it.
enum CoverArt {
    /// The star's middle in the BookCover picture, as a share of its width and height.
    static let starCenter = CGPoint(x: 426.0 / 852, y: 868.5 / 1846)
    /// The star's width, as a share of the picture's width.
    static let starWidthShare: CGFloat = 513.0 / 852
    /// In the Splash picture the star fills all but a thin clear border.
    static let splashStarShare: CGFloat = 847.0 / 863

    static var imageSize: CGSize {
        UIImage(named: "BookCover")?.size ?? CGSize(width: 852, height: 1846)
    }

    /// The cover picture's frame on a screen this size: filling it, with the star in the middle.
    static func coverRect(in bounds: CGSize) -> CGRect {
        let image = imageSize
        guard image.width > 0, image.height > 0 else { return CGRect(origin: .zero, size: bounds) }
        let scale = max(
            bounds.width / image.width,
            // Tall enough to reach the top and bottom with the star in the middle.
            bounds.height / (2 * starCenter.y * image.height),
            bounds.height / (2 * (1 - starCenter.y) * image.height)
        )
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(
            x: bounds.width / 2 - starCenter.x * size.width,
            y: bounds.height / 2 - starCenter.y * size.height,
            width: size.width,
            height: size.height
        )
    }

    /// How wide the Splash picture should be drawn so its star matches the cover's.
    static func splashWidth(in bounds: CGSize) -> CGFloat {
        coverRect(in: bounds).width * starWidthShare / splashStarShare
    }
}
