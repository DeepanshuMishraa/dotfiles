import Foundation
import CoreGraphics

public struct DisplayGeometry: Equatable, Sendable {
    public var cocoaFrame: CGRect
    public var cgFrame: CGRect

    public init(cocoaFrame: CGRect, cgFrame: CGRect) {
        self.cocoaFrame = cocoaFrame
        self.cgFrame = cgFrame
    }

    public func cocoaRect(for cgRect: CGRect) -> CGRect? {
        guard cgFrame.intersects(cgRect) else { return nil }
        return CGRect(
            x: cocoaFrame.minX + cgRect.minX - cgFrame.minX,
            y: cocoaFrame.maxY - (cgRect.minY - cgFrame.minY) - cgRect.height,
            width: cgRect.width,
            height: cgRect.height
        )
    }
}

public enum BorderGeometry {
    public static func overlayFrame(windowFrame: CGRect, width: CGFloat, gap: CGFloat) -> CGRect {
        windowFrame.insetBy(dx: -(width / 2 + gap), dy: -(width / 2 + gap))
    }

    public static func pathRect(overlaySize: CGSize, width: CGFloat) -> CGRect {
        CGRect(origin: .zero, size: overlaySize).insetBy(dx: width / 2, dy: width / 2)
    }
}
