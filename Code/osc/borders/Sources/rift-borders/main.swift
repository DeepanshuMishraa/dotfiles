import AppKit
import CoreGraphics
import Darwin
import Foundation
import RiftBordersCore

// The daemon deliberately keeps all WindowServer-facing declarations here.
// They are private APIs, matching the mechanism used by JankyBorders, and are
// isolated so future macOS changes have one place to audit.
typealias NotifyProc = @convention(c) (UInt32, UnsafeMutableRawPointer?, Int, UnsafeMutableRawPointer?) -> Void

@_silgen_name("SLSMainConnectionID")
private func SLSMainConnectionID() -> Int32
@_silgen_name("SLSRegisterNotifyProc")
private func SLSRegisterNotifyProc(_ proc: NotifyProc, _ event: UInt32, _ context: UnsafeMutableRawPointer?) -> CGError
@_silgen_name("SLSRequestNotificationsForWindows")
private func SLSRequestNotificationsForWindows(_ cid: Int32, _ windows: UnsafePointer<UInt32>?, _ count: Int32) -> CGError
@_silgen_name("SLSWindowIsOrderedIn")
private func SLSWindowIsOrderedIn(_ cid: Int32, _ windowID: UInt32, _ shown: UnsafeMutablePointer<Bool>) -> CGError
@_silgen_name("SLSGetEventPort")
private func SLSGetEventPort(_ cid: Int32, _ port: UnsafeMutablePointer<mach_port_t>) -> CGError
@_silgen_name("SLEventCreateNextEvent")
private func SLEventCreateNextEvent(_ cid: Int32) -> Unmanaged<CGEvent>?
@_silgen_name("_CFMachPortSetOptions")
private func _CFMachPortSetOptions(_ port: CFMachPort, _ options: Int32)
@_silgen_name("_SLPSGetFrontProcess")
private func SLPSGetFrontProcess(_ psn: inout PSN) -> OSStatus
@_silgen_name("GetProcessPID")
private func GetProcessPID(_ psn: inout PSN, _ pid: inout pid_t) -> OSStatus

private let windowMove: UInt32 = 806
private let windowResize: UInt32 = 807
private let windowClose: UInt32 = 804
private let windowReorder: UInt32 = 808
private let windowLevel: UInt32 = 811
private let windowUnhide: UInt32 = 815
private let windowHide: UInt32 = 816
private let windowUpdate: UInt32 = 723
private let windowTitle: UInt32 = 1322
private let windowCreate: UInt32 = 1325
private let windowDestroy: UInt32 = 1326
// WindowServer animation lifecycle. Unlike windowHide (816), which arrives
// after the Dock's genie/scale animation, transitionBegin fires when the
// animation is committed and lets the border disappear before it becomes a
// detached rectangle.
private let windowTransitionBegin: UInt32 = 1327
private let windowTransitionEnd: UInt32 = 1328
private let spaceChange: UInt32 = 1401
private let frontChange: UInt32 = 1508

private struct PSN { var high: UInt32 = 0; var low: UInt32 = 0 }

private struct TrackedWindow: Equatable {
    let id: UInt32
    let pid: pid_t
    let ownerName: String
    let appName: String
    let bundleIdentifier: String?
    let frame: CGRect
    let role: String?
    let focused: Bool
}

private final class BorderView: NSView {
    private let stroke = CAShapeLayer()
    private let gradient = CAGradientLayer()
    private let gradientMask = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        stroke.fillColor = nil
        gradientMask.strokeColor = CGColor(gray: 1, alpha: 1)
        gradientMask.fillColor = nil
        gradient.mask = gradientMask
        layer?.addSublayer(stroke)
        layer?.addSublayer(gradient)
    }

    required init?(coder: NSCoder) { fatalError("BorderView does not support NSCoder") }

    func update(size: CGSize, radius: CGFloat, appearance: Appearance, shape: BorderShape, scale: CGFloat, animated: Bool, duration: Double) {
        frame = CGRect(origin: .zero, size: size)
        let pathRect = BorderGeometry.pathRect(overlaySize: size, width: appearance.width.map { CGFloat($0) } ?? 3)
        let actualRadius: CGFloat = shape == .square ? 0 : (shape == .uniform ? 9 : radius)
        let path = CGPath(roundedRect: pathRect, cornerWidth: actualRadius, cornerHeight: actualRadius, transform: nil)

        stroke.frame = bounds
        stroke.path = path
        stroke.lineWidth = CGFloat(appearance.width ?? 3)
        stroke.contentsScale = scale
        let targetOpacity = Float(max(0, min(1, appearance.opacity)))
        let oldStrokeOpacity = stroke.presentation()?.opacity ?? stroke.opacity
        let oldGradientOpacity = gradient.presentation()?.opacity ?? gradient.opacity
        stroke.opacity = targetOpacity
        // A shadow is visually attractive but it creates a translucent halo
        // outside the window edge. Borders are meant to terminate exactly at
        // the target geometry, so glow remains a bright paint variant rather
        // than a compositor blur.
        stroke.shadowOpacity = 0
        stroke.shadowRadius = 0
        stroke.shadowOffset = .zero
        stroke.shadowColor = cgColor(appearance.color)

        if appearance.paint == .gradient, let endColor = appearance.endColor {
            gradient.isHidden = false
            stroke.isHidden = true
            gradient.frame = bounds
            gradient.colors = [cgColor(appearance.color), cgColor(endColor)]
            gradient.startPoint = CGPoint(x: 0, y: 0)
            gradient.endPoint = CGPoint(x: 1, y: 1)
            gradient.opacity = targetOpacity
            gradientMask.frame = bounds
            gradientMask.path = path
            gradientMask.lineWidth = stroke.lineWidth
        } else {
            gradient.isHidden = true
            stroke.isHidden = false
            stroke.strokeColor = cgColor(appearance.color)
        }
        if animated && duration > 0 {
            animateOpacity(layer: stroke, from: oldStrokeOpacity, to: targetOpacity, duration: duration)
            animateOpacity(layer: gradient, from: oldGradientOpacity, to: targetOpacity, duration: duration)
        }
    }

    private func animateOpacity(layer: CALayer, from: Float, to: Float, duration: Double) {
        guard abs(from - to) > 0.001 else { return }
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "rift-borders.opacity")
    }

    private func cgColor(_ color: ColorValue) -> CGColor {
        CGColor(red: CGFloat(color.red) / 255,
                green: CGFloat(color.green) / 255,
                blue: CGFloat(color.blue) / 255,
                alpha: CGFloat(color.alpha) / 255)
    }
}

private final class BorderOverlay: NSWindow {
    let borderView = BorderView(frame: .zero)
    var targetID: UInt32 = 0

    init() {
        super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = true
        hasShadow = false
        level = .floating
        collectionBehavior = [.stationary, .ignoresCycle, .fullScreenAuxiliary]
        animationBehavior = .none
        contentView = borderView
    }

    func display(frame: CGRect, radius: CGFloat, appearance: Appearance, shape: BorderShape, hidpi: Bool, order: BorderOrder, animated: Bool, duration: Double) {
        level = order == .above ? .floating : .normal
        setFrame(frame, display: false)
        let scale = (screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2)
        let effectiveScale = hidpi ? scale : 1
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        borderView.update(size: frame.size, radius: radius, appearance: appearance, shape: shape, scale: effectiveScale, animated: animated, duration: duration)
        CATransaction.commit()
        if !isVisible { orderFrontRegardless() }
    }
}

private final class WindowServerEvents {
    var handler: ((UInt32, UInt32?) -> Void)?
    private let cid = SLSMainConnectionID()
    private var subscribed = Set<UInt32>()

    func start() {
        Self.current = self
        for event in [windowClose, windowMove, windowResize, windowReorder, windowLevel,
                      windowUnhide, windowHide, windowUpdate, windowTitle, windowCreate,
                      windowDestroy, windowTransitionBegin, windowTransitionEnd,
                      spaceChange, frontChange] {
            _ = SLSRegisterNotifyProc(Self.callback, event, nil)
        }
        installEventPort()
    }

    func updateSubscriptions(_ ids: [UInt32]) {
        let next = Set(ids)
        guard next != subscribed || ids.isEmpty else { return }
        subscribed = next
        _ = ids.withUnsafeBufferPointer { buffer in
            SLSRequestNotificationsForWindows(cid, buffer.baseAddress, Int32(buffer.count))
        }
    }

    private func installEventPort() {
        var port: mach_port_t = 0
        guard SLSGetEventPort(cid, &port) == .success,
              let machPort = CFMachPortCreateWithPort(nil, port, { _, _, _, _ in
                  while let event = SLEventCreateNextEvent(SLSMainConnectionID()) { event.release() }
              }, nil, nil) else { return }
        _CFMachPortSetOptions(machPort, 0x40)
        let source = CFMachPortCreateRunLoopSource(nil, machPort, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    private static weak var current: WindowServerEvents?
    private static let callback: NotifyProc = { event, data, length, _ in
        var windowID: UInt32?
        if let data, length >= MemoryLayout<UInt32>.size {
            windowID = data.assumingMemoryBound(to: UInt32.self).pointee
        }
        current?.handler?(event, windowID)
    }
}

private final class ConfigurationWatcher {
    private let url: URL
    private let callback: () -> Void
    private var source: DispatchSourceFileSystemObject?

    init(url: URL, callback: @escaping () -> Void) {
        self.url = url
        self.callback = callback
    }

    func start() {
        arm()
    }

    private func arm() {
        guard FileManager.default.fileExists(atPath: url.path) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.arm() }
            return
        }
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .attrib, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self, weak source] in
            self?.callback()
            if source?.data.contains(.rename) == true || source?.data.contains(.delete) == true {
                source?.cancel()
            }
        }
        source.setCancelHandler { [weak self] in
            close(fd)
            DispatchQueue.main.async { self?.arm() }
        }
        self.source = source
        source.resume()
    }
}

private final class BorderDaemon {
    private let configURL: URL
    private var config: BorderConfiguration
    private let ownPID = getpid()
    private let events = WindowServerEvents()
    private var watcher: ConfigurationWatcher?
    private var huedWatcher: ConfigurationWatcher?
    private let hued = HuedThemeProvider()
    private var overlays: [UInt32: BorderOverlay] = [:]
    private var lastWindows: [UInt32: TrackedWindow] = [:]
    private var reconciliationTimer: Timer?
    private var visibilityTimer: Timer?
    private var reconcileScheduled = false
    private var lastReconcile = Date.distantPast
    private var draggingUntil = Date.distantPast
    // A hide notification can precede the CGWindowList snapshot by several
    // frames while macOS is minimizing a window. Keep that window suppressed
    // until the snapshot is authoritative; otherwise a trailing reconcile can
    // resurrect its old border.
    private var hiddenUntil: [UInt32: Date] = [:]
    private var hideAllUntil = Date.distantPast
    private let hideSuppressionDuration = 0.60
    private var transitionHiddenIDs = Set<UInt32>()
    private var transitionGeneration = 0
    private let notchShroud: NSWindow = {
        let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = true
        window.backgroundColor = .black
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.animationBehavior = .none
        return window
    }()
    private var pidURL: URL { configURL.deletingLastPathComponent().appendingPathComponent("rift-borders.pid") }

    init(configURL: URL) throws {
        self.configURL = configURL
        self.config = try ConfigurationLoader.load(from: configURL)
    }

    func start() {
        writePIDFile()
        events.handler = { [weak self] event, windowID in
            guard let self else { return }
            if event == windowTransitionBegin {
                self.beginWindowTransition()
                return
            } else if event == windowTransitionEnd {
                self.endWindowTransition()
                return
            } else if event == windowHide {
                self.suppressHiddenWindow(windowID)
                // Do not reconcile immediately. A fresh snapshot during the
                // minimize transition is precisely what used to bring the
                // ghost border back. The normal timer and this delayed pass
                // restore the rest of the workspace after suppression.
                self.scheduleReconcile(after: self.hideSuppressionDuration)
            } else if event == windowUnhide {
                if let windowID { self.hiddenUntil.removeValue(forKey: windowID) }
                self.hideAllUntil = .distantPast
                self.scheduleReconcile()
            } else if event == windowClose || event == windowDestroy, let windowID {
                self.hiddenUntil.removeValue(forKey: windowID)
                self.overlays[windowID]?.orderOut(nil)
                self.overlays.removeValue(forKey: windowID)
                self.lastWindows.removeValue(forKey: windowID)
            } else if (event == windowMove || event == windowResize), let windowID {
                self.draggingUntil = Date().addingTimeInterval(0.10)
                // Move storms are display-rate work. Reading one window is
                // materially cheaper than rebuilding every window on screen.
                self.refreshOverlay(for: windowID)
                return
            }
            if event == windowCreate || event == windowDestroy { self.rebuildSubscriptions() }
            self.scheduleReconcile()
        }
        events.start()
        watcher = ConfigurationWatcher(url: configURL) { [weak self] in self?.reloadConfiguration() }
        watcher?.start()
        hued.reload()
        huedWatcher = ConfigurationWatcher(url: hued.watchedURL) { [weak self] in
            guard let self, self.hued.reload() else { return }
            self.reconcile(force: true)
        }
        huedWatcher?.start()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.reconcile(force: true)
        }
        reconciliationTimer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.rebuildSubscriptions()
            self?.scheduleReconcile()
        }
        RunLoop.main.add(reconciliationTimer!, forMode: .common)
        visibilityTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.pruneHiddenOverlays()
        }
        RunLoop.main.add(visibilityTimer!, forMode: .common)
        reconcile(force: true)
    }

    func stop() {
        reconciliationTimer?.invalidate()
        visibilityTimer?.invalidate()
        overlays.values.forEach { $0.orderOut(nil) }
        overlays.removeAll()
        notchShroud.orderOut(nil)
        try? FileManager.default.removeItem(at: pidURL)
        NSApp.terminate(nil)
    }

    func reloadConfiguration() {
        do {
            let newConfig = try ConfigurationLoader.load(from: configURL)
            config = newConfig
            reconcile(force: true)
        } catch {
            fputs("rift-borders: configuration reload failed: \(error)\n", stderr)
        }
    }

    private func reconcile(force: Bool = false) {
        reconcileScheduled = false
        lastReconcile = Date()
        guard config.enabled else {
            overlays.values.forEach { $0.orderOut(nil) }
            notchShroud.orderOut(nil)
            return
        }
        let windows = visibleWindows()
        var fullscreenDisplay: NSScreen?
        let nextIDs = Set(windows.map(\.id))
        for id in Set(overlays.keys).subtracting(nextIDs) {
            overlays[id]?.orderOut(nil)
            overlays.removeValue(forKey: id)
        }
        for window in windows {
            if !render(window, force: force), config.coverNotch,
               let screen = fullscreenScreen(for: window.frame) {
                fullscreenDisplay = screen
            }
        }
        syncNotchShroud(for: fullscreenDisplay)
        lastWindows = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })
        if force { rebuildSubscriptions() }
    }

    private func scheduleReconcile() {
        scheduleReconcile(after: 0)
    }

    private func scheduleReconcile(after requestedDelay: TimeInterval) {
        guard !reconcileScheduled else { return }
        reconcileScheduled = true
        let elapsed = Date().timeIntervalSince(lastReconcile)
        // Full window-list walks are reserved for focus/layout changes. A
        // 30 Hz ceiling leaves the main run loop available for hide events;
        // move/resize events use refreshOverlay(for:) instead.
        let delay = max(requestedDelay, (1.0 / 30.0) - elapsed)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.reconcile()
        }
    }

    private func pruneHiddenOverlays() {
        for (id, overlay) in overlays where isSuppressed(id) || !targetIsVisible(id) {
            if overlay.isVisible { overlay.orderOut(nil) }
        }
    }

    private func targetIsVisible(_ windowID: UInt32) -> Bool {
        // This is the emergency hide watchdog. Keep it to one cheap
        // WindowServer query; CGWindowListCopyWindowInfo here used to turn a
        // 60 Hz safety net into another source of main-thread stalls.
        return isOrderedIn(windowID)
    }

    private func visibleWindows() -> [TrackedWindow] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        let focusedPID = frontmostPID()
        let candidates = list.compactMap { window(from: $0, focused: false) }
        let topLevelIDs = topLevelIDs(for: candidates)
        let topLevelCandidates = candidates.filter { topLevelIDs.contains($0.id) }
        let focusedID = topLevelCandidates.first(where: { $0.pid == focusedPID })?.id
        return topLevelCandidates.map { item in
            TrackedWindow(id: item.id, pid: item.pid, ownerName: item.ownerName, appName: item.appName,
                          bundleIdentifier: item.bundleIdentifier, frame: item.frame,
                          role: item.role, focused: item.id == focusedID)
        }
    }

    private func window(from info: [String: Any], focused: Bool) -> TrackedWindow? {
        guard let id = number(info[kCGWindowNumber as String]).map({ UInt32($0) }),
              !isSuppressed(id),
              let pid = number(info[kCGWindowOwnerPID as String]).map({ pid_t($0) }),
              pid != ownPID,
              number(info[kCGWindowLayer as String]) == 0,
              (info[kCGWindowIsOnscreen as String] as? Bool) ?? false,
              isOrderedIn(id),
              let frame = bounds(info[kCGWindowBounds as String]),
              frame.width > 60, frame.height > 60,
              visibleFraction(frame) >= 0.7 else { return nil }
        let ownerName = info[kCGWindowOwnerName as String] as? String ?? "Unknown"
        let app = NSRunningApplication(processIdentifier: pid)
        let name = cleanName(app?.localizedName ?? "Unknown")
        let appName = name.isEmpty || name == "Unknown" ? ownerName : name
        guard !appName.isEmpty else { return nil }
        let role = ownerName == "Window Server" ? "system" : nil
        return TrackedWindow(id: id, pid: pid, ownerName: ownerName, appName: appName,
                             bundleIdentifier: app?.bundleIdentifier, frame: frame,
                             role: role, focused: focused)
    }

    private func refreshOverlay(for windowID: UInt32) {
        guard overlays[windowID] != nil else {
            scheduleReconcile()
            return
        }
        guard !isSuppressed(windowID),
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
              let info = list.first(where: { number($0[kCGWindowNumber as String]).map({ UInt32($0) }) == windowID }),
              let candidate = window(from: info, focused: lastWindows[windowID]?.focused ?? false),
              topLevelIDs(for: list.compactMap { window(from: $0, focused: false) }).contains(windowID),
              candidate.id == windowID else {
            overlays[windowID]?.orderOut(nil)
            overlays.removeValue(forKey: windowID)
            lastWindows.removeValue(forKey: windowID)
            return
        }
        _ = render(candidate, force: false)
        lastWindows[windowID] = candidate
    }

    private func topLevelIDs(for windows: [TrackedWindow]) -> Set<UInt32> {
        Set(WindowSelection.topLevel(windows.map {
            WindowFrameCandidate(id: $0.id,
                                 ownerName: $0.ownerName,
                                 frame: $0.frame)
        }).map(\.id))
    }

    @discardableResult
    private func render(_ window: TrackedWindow, force: Bool) -> Bool {
        if config.isExcluded(appName: window.appName, bundleIdentifier: window.bundleIdentifier) || config.excludedWindowRoles.contains(window.role ?? "") {
            overlays[window.id]?.orderOut(nil)
            return true
        }
        if fullscreenScreen(for: window.frame) != nil {
            overlays[window.id]?.orderOut(nil)
            return false
        }
        var appearance = config.appearance(focused: window.focused, appName: window.appName, bundleIdentifier: window.bundleIdentifier)
        if config.themeSource == .hued {
            let field = window.focused ? config.themeActiveField : config.themeInactiveField
            if let color = hued.color(for: field) { appearance.color = color }
            let endField = window.focused ? config.themeActiveEndField : config.themeInactiveEndField
            if let endField, let color = hued.color(for: endField) { appearance.endColor = color }
        }
        appearance.width = appearance.width ?? config.width
        let width = CGFloat(appearance.width!)
        let overlayFrame = BorderGeometry.overlayFrame(windowFrame: cocoaFrame(for: window.frame), width: width, gap: CGFloat(config.gap))
        let overlay = overlays[window.id] ?? {
            let created = BorderOverlay()
            created.targetID = window.id
            overlays[window.id] = created
            return created
        }()
        let baseRadius = config.rule(for: window.appName, bundleIdentifier: window.bundleIdentifier)?.radius ?? config.radius ?? 17.1
        let radius = max(0, CGFloat(baseRadius + config.gap + width / 2))
        let changedFocus = lastWindows[window.id]?.focused != window.focused
        let suppressFade = config.disableAnimationDuringDrag && Date() < draggingUntil
        overlay.display(frame: overlayFrame, radius: radius, appearance: appearance, shape: config.shape, hidpi: config.hidpi, order: config.order, animated: config.fadeEnabled && !force && changedFocus && !suppressFade, duration: config.fadeDurationMilliseconds / 1000)
        return true
    }

    private func suppressHiddenWindow(_ windowID: UInt32?) {
        let until = Date().addingTimeInterval(hideSuppressionDuration)
        if let windowID {
            hiddenUntil[windowID] = until
            if let overlay = overlays[windowID] {
                overlay.orderOut(nil)
            }
        } else {
            hideAllUntil = until
            overlays.values.forEach { $0.orderOut(nil) }
        }
    }

    private func isSuppressed(_ windowID: UInt32) -> Bool {
        let now = Date()
        if transitionHiddenIDs.contains(windowID) { return true }
        if now < hideAllUntil { return true }
        if let until = hiddenUntil[windowID] {
            if now < until { return true }
            hiddenUntil.removeValue(forKey: windowID)
        }
        return false
    }

    private func beginWindowTransition() {
        transitionGeneration += 1
        let generation = transitionGeneration
        let focused = Set(lastWindows.values.lazy.filter(\.focused).map(\.id))
        transitionHiddenIDs = focused.isEmpty ? Set(overlays.keys) : focused
        for id in transitionHiddenIDs {
            overlays[id]?.orderOut(nil)
        }

        // Completion notifications are private API and may be dropped across
        // display/space changes. Never let that strand a border off-screen.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            guard let self, self.transitionGeneration == generation,
                  !self.transitionHiddenIDs.isEmpty else { return }
            self.transitionHiddenIDs.removeAll()
            self.reconcile(force: true)
        }
    }

    private func endWindowTransition() {
        transitionGeneration += 1
        transitionHiddenIDs.removeAll()
        // Let the final ordered-in state land before rebuilding overlays.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in
            self?.reconcile(force: true)
        }
    }

    private func rebuildSubscriptions() {
        guard let list = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return }
        let ids = list.compactMap { number($0[kCGWindowNumber as String]).map({ UInt32($0) }) }
        events.updateSubscriptions(ids)
    }

    private func frontmostPID() -> pid_t {
        var psn = PSN()
        var pid: pid_t = 0
        guard SLPSGetFrontProcess(&psn) == 0, GetProcessPID(&psn, &pid) == 0 else { return -1 }
        return pid
    }

    private func isOrderedIn(_ windowID: UInt32) -> Bool {
        var shown = false
        guard SLSWindowIsOrderedIn(SLSMainConnectionID(), windowID, &shown) == .success else { return false }
        return shown
    }

    private func cocoaFrame(for cgFrame: CGRect) -> CGRect {
        let screen = NSScreen.screens.max { lhs, rhs in
            let lhsID = lhs.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            let rhsID = rhs.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            return cgFrame.intersection(CGDisplayBounds(lhsID)).area < cgFrame.intersection(CGDisplayBounds(rhsID)).area
        }
        if let screen {
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            let displayFrame = CGDisplayBounds(displayID)
            if let converted = DisplayGeometry(cocoaFrame: screen.frame, cgFrame: displayFrame).cocoaRect(for: cgFrame) { return converted }
        }
        return cgFrame
    }

    private func visibleFraction(_ frame: CGRect) -> CGFloat {
        let area = frame.width * frame.height
        guard area > 0 else { return 0 }
        return NSScreen.screens.reduce(CGFloat.zero) { result, screen in
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            return result + frame.intersection(CGDisplayBounds(displayID)).area
        } / area
    }

    private func fullscreenScreen(for frame: CGRect) -> NSScreen? {
        NSScreen.screens.first { screen in
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            let display = CGDisplayBounds(displayID)
            return DisplayGeometry(cocoaFrame: screen.frame, cgFrame: display).isFullscreen(frame)
        }
    }

    private func syncNotchShroud(for screen: NSScreen?) {
        guard config.coverNotch, let screen, screen.safeAreaInsets.top > 0 else {
            notchShroud.orderOut(nil)
            return
        }
        let inset = screen.safeAreaInsets.top
        let frame = CGRect(x: screen.frame.minX,
                           y: screen.frame.maxY - inset,
                           width: screen.frame.width,
                           height: inset)
        if notchShroud.frame != frame { notchShroud.setFrame(frame, display: false) }
        notchShroud.orderFrontRegardless()
    }

    private func number(_ value: Any?) -> CGFloat? {
        if let value = value as? NSNumber { return CGFloat(truncating: value) }
        return nil
    }

    private func bounds(_ value: Any?) -> CGRect? {
        guard let dict = value as? [String: Any],
              let x = number(dict["X"]), let y = number(dict["Y"]),
              let width = number(dict["Width"]), let height = number(dict["Height"])
        else { return nil }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func cleanName(_ name: String) -> String {
        String(name.unicodeScalars.filter { $0.properties.generalCategory != .format }).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func writePIDFile() {
        let directory = pidURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? "\(ownPID)\n".write(to: pidURL, atomically: true, encoding: .utf8)
    }
}

private extension CGRect {
    var area: CGFloat { max(0, width) * max(0, height) }
}

private enum Command {
    static let configURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/rift-borders/config.toml")
    static let pidURL = configURL.deletingLastPathComponent().appendingPathComponent("rift-borders.pid")
    static let serviceLabel = "com.dipxsy.rift-borders"
    static let servicePlistURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents")
        .appendingPathComponent("\(serviceLabel).plist")

    static func run(_ arguments: [String]) -> Int32 {
        let commandArguments = Array(arguments.dropFirst())
        if commandArguments.first == "service" {
            return runService(commandArguments.dropFirst().first ?? "status")
        }
        let command = commandArguments.first ?? "start"
        switch command {
        case "validate":
            do { _ = try ConfigurationLoader.load(from: configURL); print("rift-borders: configuration is valid"); return 0 }
            catch { fputs("rift-borders: \(error)\n", stderr); return 1 }
        case "status":
            return serviceStatus()
        case "stop": return serviceStop()
        case "reload": return signal(SIGHUP)
        case "start": return serviceStart()
        case "restart": return serviceRestart()
        case "daemon", "run": return startDaemon()
        case "config":
            let subcommand = commandArguments.dropFirst().first ?? "validate"
            switch subcommand {
            case "validate":
                do { _ = try ConfigurationLoader.load(from: configURL); print("rift-borders: configuration is valid"); return 0 }
                catch { fputs("rift-borders: \(error)\n", stderr); return 1 }
            case "reload": return signal(SIGHUP)
            default:
                fputs("rift-borders: unknown config command \(subcommand)\n", stderr); return 2
            }
        case "help", "--help", "-h":
            print("usage: rift-borders [start|stop|restart|reload|status|validate]")
            print("       rift-borders service [start|stop|restart|status]")
            print("       rift-borders config [reload|validate]")
            print("       rift-borders daemon   # internal foreground launchd entrypoint")
            return 0
        default:
            fputs("rift-borders: unknown command \(command)\n", stderr); return 2
        }
    }

    private static func runService(_ command: String) -> Int32 {
        switch command {
        case "start": return serviceStart()
        case "stop": return serviceStop()
        case "restart": return serviceRestart()
        case "status": return serviceStatus()
        case "reload": return signal(SIGHUP)
        default:
            fputs("rift-borders: unknown service command \(command)\n", stderr); return 2
        }
    }

    private static func serviceStart() -> Int32 {
        guard FileManager.default.fileExists(atPath: servicePlistURL.path) else {
            fputs("rift-borders: launch agent not found at \(servicePlistURL.path)\n", stderr)
            return 1
        }
        if launchctl(["print", serviceTarget]).status == 0 {
            print("rift-borders: service already running")
            return 0
        }
        let result = launchctl(["bootstrap", userDomain, servicePlistURL.path])
        if result.status == 0 {
            print("rift-borders: service started")
            return 0
        }
        // bootstrap reports an error if the label was loaded between the
        // print and bootstrap calls. Verify the actual state before failing.
        if launchctl(["print", serviceTarget]).status == 0 {
            print("rift-borders: service already running")
            return 0
        }
        fputs("rift-borders: failed to start service\n\(result.output)", stderr)
        return result.status == 0 ? 1 : result.status
    }

    private static func serviceStop() -> Int32 {
        let result = launchctl(["bootout", userDomain + "/" + serviceLabel])
        if result.status == 0 || launchctl(["print", serviceTarget]).status != 0 {
            print("rift-borders: service stopped")
            return 0
        }
        fputs("rift-borders: failed to stop service\n\(result.output)", stderr)
        return result.status == 0 ? 1 : result.status
    }

    private static func serviceRestart() -> Int32 {
        _ = serviceStop()
        return serviceStart()
    }

    private static func serviceStatus() -> Int32 {
        guard launchctl(["print", serviceTarget]).status == 0 else {
            print("rift-borders: stopped")
            return 1
        }
        if let pid = readPID(), kill(pid, 0) == 0 {
            print("rift-borders: running (pid \(pid))")
        } else {
            print("rift-borders: service loaded (starting)")
        }
        return 0
    }

    private static var userDomain: String { "gui/\(getuid())" }
    private static var serviceTarget: String { "\(userDomain)/\(serviceLabel)" }

    private static func launchctl(_ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (1, "\(error)\n")
        }
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationStatus, output)
    }

    private static func startDaemon() -> Int32 {
        if let pid = readPID(), kill(pid, 0) == 0 {
            fputs("rift-borders: already running (pid \(pid))\n", stderr); return 1
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        do {
            let daemon = try BorderDaemon(configURL: configURL)
            let term = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
            Darwin.signal(SIGTERM, SIG_IGN)
            term.setEventHandler { daemon.stop() }
            term.resume()
            let hup = DispatchSource.makeSignalSource(signal: SIGHUP, queue: .main)
            Darwin.signal(SIGHUP, SIG_IGN)
            hup.setEventHandler {
                daemon.reloadConfiguration()
            }
            hup.resume()
            daemon.start()
            app.run()
            return 0
        } catch {
            fputs("rift-borders: failed to start: \(error)\n", stderr); return 1
        }
    }

    private static func readPID() -> pid_t? {
        guard let text = try? String(contentsOf: pidURL), let value = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return pid_t(value)
    }

    private static func signal(_ value: Int32) -> Int32 {
        guard let pid = readPID() else { print("rift-borders: not running"); return 1 }
        guard kill(pid, value) == 0 else { perror("rift-borders"); return 1 }
        print("rift-borders: signal sent to pid \(pid)"); return 0
    }
}

exit(Command.run(CommandLine.arguments))
