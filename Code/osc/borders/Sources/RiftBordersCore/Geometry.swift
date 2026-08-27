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

    public func isFullscreen(_ cgRect: CGRect, tolerance: CGFloat = 4) -> Bool {
        let intersection = cgFrame.intersection(cgRect)
        guard cgRect.area > 0, cgFrame.area > 0 else { return false }
        let coversDisplay = intersection.area / cgFrame.area >= 0.98
        let reachesEdges = cgRect.minX <= cgFrame.minX + tolerance
            && cgRect.minY <= cgFrame.minY + tolerance
            && cgRect.maxX >= cgFrame.maxX - tolerance
            && cgRect.maxY >= cgFrame.maxY - tolerance
        return coversDisplay && reachesEdges
    }
}

public struct WindowFrameCandidate: Equatable, Sendable {
    public var id: UInt32
    public var ownerName: String
    public var frame: CGRect

    public init(id: UInt32, ownerName: String, frame: CGRect) {
        self.id = id
        self.ownerName = ownerName
        self.frame = frame
    }
}

public enum WindowSelection {
    public static func topLevel(_ candidates: [WindowFrameCandidate],
                                fullscreenFrames: [CGRect] = []) -> [WindowFrameCandidate] {
        candidates.filter { candidate in
            if fullscreenFrames.contains(where: { fullscreen in
                fullscreen.area > candidate.frame.area
                    && fullscreen.intersection(candidate.frame).area / candidate.frame.area >= 0.85
            }) {
                return false
            }
            return !candidates.contains { container in
                guard container.id != candidate.id,
                      container.ownerName == candidate.ownerName,
                      container.frame.area > candidate.frame.area else { return false }
                let overlap = container.frame.intersection(candidate.frame).area
                return overlap / candidate.frame.area >= 0.85
            }
        }
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

private extension CGRect {
    var area: CGFloat { max(0, width) * max(0, height) }
}
