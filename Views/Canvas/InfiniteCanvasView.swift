//
//  InfiniteCanvasView.swift
//  infinitenote
//

import UIKit
import SwiftUI
import Combine
import PencilKit

// MARK: - Stable RNG (deterministic grain for pencil/crayon texture)

private struct StableRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 1 : seed }

    mutating func next() -> UInt64 {
        state ^= state &<< 13
        state ^= state &>> 7
        state ^= state &<< 17
        return state
    }
}

// MARK: - Stroke

struct Stroke {
    let id = UUID()
    var points: [CGPoint]
    var lineWidth: CGFloat

    // Local origin — camera base position when stroke was created.
    // Points are stored as small local offsets from this origin,
    // preserving floating-point precision at any zoom level.
    let originX: Double
    let originY: Double

    // Store color as concrete RGBA values to avoid dynamic color issues
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    // Tool properties
    let toolType: DrawingToolType
    let opacity: CGFloat
    let isDraft: Bool
    let dashPattern: [CGFloat]
    let isEraser: Bool

    init(points: [CGPoint], color: UIColor, lineWidth: CGFloat, originX: Double = 0, originY: Double = 0, toolType: DrawingToolType = .pen, opacity: CGFloat = 1.0, draftMode: DraftMode = .off) {
        self.points = points
        self.lineWidth = lineWidth
        self.originX = originX
        self.originY = originY
        self.toolType = toolType
        self.opacity = opacity * toolType.defaultOpacity * draftMode.opacity
        self.isDraft = draftMode != .off
        self.dashPattern = draftMode.dashPattern
        self.isEraser = toolType == .eraser

        // Convert to RGB color space and extract components
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1

        // Try to get RGB components directly
        if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
            // Success
        } else if color.getWhite(&r, alpha: &a) {
            // Grayscale color
            g = r
            b = r
        } else {
            // Fallback: convert through CGColor
            if let cgColor = color.cgColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil),
               let components = cgColor.components, components.count >= 3 {
                r = components[0]
                g = components[1]
                b = components[2]
                a = components.count >= 4 ? components[3] : 1.0
            }
        }

        self.red = r
        self.green = g
        self.blue = b
        self.alpha = a
    }
}

// MARK: - View Model

class InfiniteCanvasViewModel: ObservableObject {
    @Published var strokes: [Stroke] = []
    @Published var currentStroke: Stroke?

    // Compound camera — base holds the coarse position, fine accumulates
    // small gesture deltas precisely. cameraX/Y are computed as base+fine.
    var cameraBaseX: Double = 0
    var cameraBaseY: Double = 0
    var cameraFineX: Double = 0
    var cameraFineY: Double = 0

    var cameraX: Double {
        get { cameraBaseX + cameraFineX }
        set { cameraBaseX = newValue; cameraFineX = 0 }
    }
    var cameraY: Double {
        get { cameraBaseY + cameraFineY }
        set { cameraBaseY = newValue; cameraFineY = 0 }
    }

    var zoom: Double = 1.0

    // Tool settings
    @Published var currentColor: UIColor = .black
    @Published var currentLineWidth: CGFloat = 3.0
    @Published var currentTool: DrawingToolType = .pencil
    @Published var currentOpacity: CGFloat = 1.0
    @Published var draftMode: DraftMode = .off

    // Ruler
    @Published var rulerGuide: RulerGuide?
    @Published var isRulerActive: Bool = false
    @Published var snapToAngles: Bool = true

    // Grid
    @Published var gridSettings: GridSettings = GridSettings()

    private var undoStack: [[Stroke]] = []
    private var redoStack: [[Stroke]] = []

    func undo() {
        guard !undoStack.isEmpty else { return }
        redoStack.append(strokes)
        strokes = undoStack.removeLast()
    }

    func redo() {
        guard !redoStack.isEmpty else { return }
        undoStack.append(strokes)
        strokes = redoStack.removeLast()
    }

    func addStroke(_ stroke: Stroke) {
        // Handle eraser
        if stroke.isEraser {
            eraseWithStroke(stroke)
            return
        }

        undoStack.append(strokes)
        if undoStack.count > 50 { undoStack.removeFirst() }
        redoStack.removeAll()
        strokes.append(stroke)
    }

    private func eraseWithStroke(_ eraserStroke: Stroke) {
        guard !strokes.isEmpty else { return }

        let eraseRadius = eraserStroke.lineWidth / 2
        var modified = false

        var newStrokes: [Stroke] = []
        for stroke in strokes {
            // Transform eraser points into this stroke's local coordinate space
            let dx = CGFloat(eraserStroke.originX - stroke.originX)
            let dy = CGFloat(eraserStroke.originY - stroke.originY)
            var shouldKeep = true
            for erasePoint in eraserStroke.points {
                let adjustedX = erasePoint.x + dx
                let adjustedY = erasePoint.y + dy
                for strokePoint in stroke.points {
                    let dist = hypot(adjustedX - strokePoint.x, adjustedY - strokePoint.y)
                    if dist < eraseRadius + stroke.lineWidth / 2 {
                        shouldKeep = false
                        modified = true
                        break
                    }
                }
                if !shouldKeep { break }
            }
            if shouldKeep {
                newStrokes.append(stroke)
            }
        }

        if modified {
            undoStack.append(strokes)
            if undoStack.count > 50 { undoStack.removeFirst() }
            redoStack.removeAll()
            strokes = newStrokes
        }
    }

    func clear() {
        guard !strokes.isEmpty else { return }
        undoStack.append(strokes)
        strokes.removeAll()
    }

    func setTool(_ tool: DrawingToolType) {
        currentTool = tool
        currentLineWidth = tool.defaultLineWidth
        currentOpacity = tool.defaultOpacity

        // Reset ruler state when switching away from ruler
        if tool != .ruler {
            rulerGuide = nil
            isRulerActive = false
        }
    }

    func setLineWidth(_ width: CGFloat) {
        currentLineWidth = max(currentTool.minLineWidth, min(currentTool.maxLineWidth, width))
    }

    /// Fold fine deltas into base. Call when gestures end.
    /// Skips the fold when the Double rounding error would cause a visible
    /// screen-space shift (> 0.5 px). At extreme zoom with a large base,
    /// `base + fine` can lose the fine bits entirely, so we leave fine
    /// untouched in that case — it stays small naturally at high zoom
    /// because gesture deltas are divided by zoom.
    func foldCamera() {
        let newBaseX = cameraBaseX + cameraFineX
        let newBaseY = cameraBaseY + cameraFineY
        let errX = newBaseX.ulp   // smallest representable change at newBaseX
        let errY = newBaseY.ulp
        let maxScreenErr = max(errX, errY) * zoom
        guard maxScreenErr < 0.5 else { return }
        cameraBaseX = newBaseX
        cameraBaseY = newBaseY
        cameraFineX = 0
        cameraFineY = 0
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
}

// MARK: - Canvas Undo Manager

class CanvasUndoManager: UndoManager {
    weak var viewModel: InfiniteCanvasViewModel?
    weak var canvasView: InfiniteCanvasUIView?

    override var canUndo: Bool { viewModel?.canUndo ?? false }
    override var canRedo: Bool { viewModel?.canRedo ?? false }

    override func undo() {
        viewModel?.undo()
        canvasView?.invalidateStrokeCache()
        canvasView?.setNeedsDisplay()
        NotificationCenter.default.post(name: .NSUndoManagerDidUndoChange, object: self)
    }

    override func redo() {
        viewModel?.redo()
        canvasView?.invalidateStrokeCache()
        canvasView?.setNeedsDisplay()
        NotificationCenter.default.post(name: .NSUndoManagerDidRedoChange, object: self)
    }
}

// MARK: - Canvas View

class InfiniteCanvasUIView: UIView {
    var viewModel: InfiniteCanvasViewModel!
    var onZoomChanged: ((Double) -> Void)?

    private var currentPoints: [CGPoint] = []
    private var isDrawing = false
    private var isTwoFingerGesture = false
    private var pinchOccurredDuringGesture = false
    private var lastDisplayTime: CFTimeInterval = 0

    // Origin for the stroke currently being drawn
    private var currentStrokeOriginX: Double = 0
    private var currentStrokeOriginY: Double = 0

    // PencilKit tool picker (UI only — rendering is custom)
    var toolPicker: PKToolPicker?

    private lazy var _undoManager: CanvasUndoManager = {
        let um = CanvasUndoManager()
        return um
    }()

    override var canBecomeFirstResponder: Bool { true }
    override var undoManager: UndoManager? { _undoManager }

    // Cache for completed strokes
    private var strokeCache: UIImage?
    private var cacheZoom: Double = 0
    private var cacheCameraBaseX: Double = 0
    private var cacheCameraBaseY: Double = 0
    private var cacheCameraFineX: Double = 0
    private var cacheCameraFineY: Double = 0
    private var cachedStrokeCount: Int = 0

    // Pinch state (incremental)
    private var pinchPrevCenter: CGPoint = .zero
    private var pinchPrevScale: Double = 1.0

    // Pan state (incremental)
    private var panPrevTranslation: CGPoint = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .systemGray6
        isMultipleTouchEnabled = true

        // Pinch
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        pinch.delegate = self
        addGestureRecognizer(pinch)

        // Two finger pan
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        pan.delegate = self
        addGestureRecognizer(pan)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }

        _undoManager.viewModel = viewModel
        _undoManager.canvasView = self

        if toolPicker == nil {
            let picker = PKToolPicker()
            picker.addObserver(self)
            picker.setVisible(true, forFirstResponder: self)
            self.toolPicker = picker
        }

        becomeFirstResponder()
        syncToolFromPicker()
    }

    func invalidateStrokeCache() {
        strokeCache = nil
    }

    private func syncToolFromPicker() {
        guard let picker = toolPicker else { return }
        let tool = picker.selectedTool

        if let inkTool = tool as? PKInkingTool {
            mapInkToolToViewModel(inkTool)
        } else if tool is PKEraserTool {
            viewModel.currentTool = .eraser
            viewModel.currentLineWidth = DrawingToolType.eraser.defaultLineWidth
        }
    }

    private func mapInkToolToViewModel(_ inkTool: PKInkingTool) {
        let inkType = inkTool.inkType

        if inkType == .pen {
            viewModel.currentTool = .pen
        } else if inkType == .pencil {
            viewModel.currentTool = .pencil
        } else if inkType == .marker {
            viewModel.currentTool = .highlighter
        } else {
            if #available(iOS 17.0, *) {
                if inkType == .crayon {
                    viewModel.currentTool = .crayon
                } else if inkType == .monoline {
                    viewModel.currentTool = .marker
                } else if inkType == .fountainPen {
                    viewModel.currentTool = .pen
                } else if inkType == .watercolor {
                    viewModel.currentTool = .highlighter
                } else {
                    viewModel.currentTool = .pen
                }
            } else {
                viewModel.currentTool = .pen
            }
        }

        viewModel.currentColor = inkTool.color
        viewModel.currentLineWidth = inkTool.width
        viewModel.currentOpacity = 1.0
    }

    // MARK: - Touch Handling for Drawing

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touches.count == 1, let touch = touches.first else { return }

        if isTwoFingerGesture { return }

        // Reclaim first responder so PKToolPicker stays visible
        if !isFirstResponder { becomeFirstResponder() }

        isDrawing = true
        let screen = touch.location(in: self)

        // Set stroke origin to FULL camera position (base+fine).
        // This keeps local coords = (screen-cx)/zoom — always tiny.
        // Using base-only would mix the accumulated `fine` into local coords,
        // and at extreme zoom the cancellation local−fine loses precision.
        currentStrokeOriginX = viewModel.cameraBaseX + viewModel.cameraFineX
        currentStrokeOriginY = viewModel.cameraBaseY + viewModel.cameraFineY

        let local = screenToLocal(screen, originX: currentStrokeOriginX, originY: currentStrokeOriginY)
        let worldLineWidth = viewModel.currentLineWidth / CGFloat(viewModel.zoom)
        currentPoints = [local]

        // Handle ruler tool
        if viewModel.currentTool == .ruler {
            viewModel.rulerGuide = RulerGuide(startPoint: local, endPoint: local, isActive: true)
            viewModel.isRulerActive = true
        }

        viewModel.currentStroke = Stroke(
            points: currentPoints,
            color: viewModel.currentTool == .eraser ? .white : viewModel.currentColor,
            lineWidth: worldLineWidth,
            originX: currentStrokeOriginX,
            originY: currentStrokeOriginY,
            toolType: viewModel.currentTool,
            opacity: viewModel.currentOpacity,
            draftMode: viewModel.draftMode
        )
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDrawing, touches.count == 1, let touch = touches.first else { return }

        let screen = touch.location(in: self)
        let local = screenToLocal(screen, originX: currentStrokeOriginX, originY: currentStrokeOriginY)

        // Handle ruler tool - only track start and end
        if viewModel.currentTool == .ruler {
            viewModel.rulerGuide?.endPoint = local
            let guide = viewModel.rulerGuide!
            let endPoint = viewModel.snapToAngles ? guide.snappedEndPoint() : guide.endPoint
            currentPoints = [guide.startPoint, endPoint]
            viewModel.currentStroke?.points = currentPoints
            setNeedsDisplay()
            return
        }

        // Add point with minimum screen distance of 4 pixels
        if let last = currentPoints.last {
            let lastScreen = localToScreen(last, originX: currentStrokeOriginX, originY: currentStrokeOriginY)
            let screenDist = hypot(screen.x - lastScreen.x, screen.y - lastScreen.y)
            if screenDist > 4 {
                currentPoints.append(local)
                viewModel.currentStroke?.points = currentPoints

                // Throttle redraws to 50fps
                let now = CACurrentMediaTime()
                if now - lastDisplayTime > 0.02 {
                    lastDisplayTime = now
                    setNeedsDisplay()
                }
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishStroke()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishStroke()
    }

    private func finishStroke() {
        // Finalize ruler stroke
        if viewModel.currentTool == .ruler, let guide = viewModel.rulerGuide {
            let endPoint = viewModel.snapToAngles ? guide.snappedEndPoint() : guide.endPoint
            currentPoints = [guide.startPoint, endPoint]
            viewModel.currentStroke?.points = currentPoints
        }

        // Single tap → duplicate point so a zero-length line draws as a round dot
        if currentPoints.count == 1 {
            currentPoints.append(currentPoints[0])
            viewModel.currentStroke?.points = currentPoints
        }

        if currentPoints.count > 1, let stroke = viewModel.currentStroke {
            viewModel.addStroke(stroke)
            NotificationCenter.default.post(name: .NSUndoManagerCheckpoint, object: undoManager)
        }
        viewModel.currentStroke = nil
        currentPoints = []
        isDrawing = false
        lastDisplayTime = 0
        viewModel.rulerGuide = nil
        viewModel.isRulerActive = false
        setNeedsDisplay()
    }

    // MARK: - Coordinate Transform (Local Origin System)

    /// Convert screen point to local coordinates relative to a stroke's origin.
    /// Formula: (screen - center) / zoom + (cameraBase - origin) + cameraFine
    /// All terms stay small for nearby strokes, preserving precision at any zoom.
    func screenToLocal(_ screen: CGPoint, originX: Double, originY: Double) -> CGPoint {
        let cx = Double(bounds.midX)
        let cy = Double(bounds.midY)
        guard viewModel.zoom > 0 else { return .zero }
        let x = (Double(screen.x) - cx) / viewModel.zoom + (viewModel.cameraBaseX - originX) + viewModel.cameraFineX
        let y = (Double(screen.y) - cy) / viewModel.zoom + (viewModel.cameraBaseY - originY) + viewModel.cameraFineY
        return CGPoint(x: x, y: y)
    }

    /// Convert local coordinates back to screen point.
    /// Formula: (local + (origin - cameraBase) - cameraFine) * zoom + center
    func localToScreen(_ local: CGPoint, originX: Double, originY: Double) -> CGPoint {
        let cx = Double(bounds.midX)
        let cy = Double(bounds.midY)
        let x = (Double(local.x) + (originX - viewModel.cameraBaseX) - viewModel.cameraFineX) * viewModel.zoom + cx
        let y = (Double(local.y) + (originY - viewModel.cameraBaseY) - viewModel.cameraFineY) * viewModel.zoom + cy
        return CGPoint(x: x, y: y)
    }

    // MARK: - Pinch Zoom (Incremental)

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        switch g.state {
        case .began:
            isTwoFingerGesture = true
            pinchOccurredDuringGesture = true
            isDrawing = false
            viewModel.currentStroke = nil
            currentPoints = []

            pinchPrevCenter = g.location(in: self)
            pinchPrevScale = 1.0

        case .changed:
            guard g.numberOfTouches >= 2 else { return }

            let scale = Double(g.scale)
            guard scale.isFinite && scale > 0 else { return }

            let currentCenter = g.location(in: self)

            // Incremental scale ratio since last frame
            let scaleRatio = scale / pinchPrevScale
            guard scaleRatio.isFinite && scaleRatio > 0 else { return }

            let oldZoom = viewModel.zoom
            var newZoom = oldZoom * scaleRatio
            newZoom = max(1.0, min(1e60, newZoom))
            guard newZoom.isFinite && newZoom > 0 else { return }

            // Actual ratio after clamping
            let r = newZoom / oldZoom

            // Incremental camera delta for zoom anchor point.
            // Formula: (screenOffset / oldZoom) * (r-1)/r
            // This avoids computing absolute world position (which loses precision).
            let screenOffX = Double(currentCenter.x) - Double(bounds.midX)
            let screenOffY = Double(currentCenter.y) - Double(bounds.midY)

            let zoomDeltaX = (screenOffX / oldZoom) * (r - 1) / r
            let zoomDeltaY = (screenOffY / oldZoom) * (r - 1) / r

            guard zoomDeltaX.isFinite && zoomDeltaY.isFinite else { return }

            viewModel.cameraFineX += zoomDeltaX
            viewModel.cameraFineY += zoomDeltaY
            viewModel.zoom = newZoom

            // Pan delta from finger movement
            let dx = Double(currentCenter.x - pinchPrevCenter.x)
            let dy = Double(currentCenter.y - pinchPrevCenter.y)
            viewModel.cameraFineX -= dx / newZoom
            viewModel.cameraFineY -= dy / newZoom

            // Fold every frame to keep fine small.  At low zoom during the
            // gesture the fold succeeds, so by the time zoom is extreme fine
            // is near zero and subsequent tiny deltas stay representable.
            viewModel.foldCamera()

            pinchPrevCenter = currentCenter
            pinchPrevScale = scale

            onZoomChanged?(newZoom)

            let now = CACurrentMediaTime()
            if now - lastDisplayTime > 0.033 {
                lastDisplayTime = now
                setNeedsDisplay()
            }

        case .ended, .cancelled:
            isTwoFingerGesture = false
            viewModel.foldCamera()
            setNeedsDisplay()

        default: break
        }
    }

    // MARK: - Pan (Incremental)

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        switch g.state {
        case .began:
            isTwoFingerGesture = true
            isDrawing = false
            viewModel.currentStroke = nil
            currentPoints = []

            panPrevTranslation = .zero

        case .changed:
            // Once a pinch has been detected during this gesture cycle,
            // suppress all pan updates — the pinch handler already handles
            // both zoom and pan. This prevents the jump when fingers lift.
            if pinchOccurredDuringGesture { return }

            let t = g.translation(in: self)
            let dx = Double(t.x) - Double(panPrevTranslation.x)
            let dy = Double(t.y) - Double(panPrevTranslation.y)
            viewModel.cameraFineX -= dx / viewModel.zoom
            viewModel.cameraFineY -= dy / viewModel.zoom
            panPrevTranslation = t

            viewModel.foldCamera()

            // Throttle redraws to ~30fps during gestures
            let now = CACurrentMediaTime()
            if now - lastDisplayTime > 0.033 {
                lastDisplayTime = now
                setNeedsDisplay()
            }

        case .ended, .cancelled:
            pinchOccurredDuringGesture = false
            isTwoFingerGesture = false
            viewModel.foldCamera()
            setNeedsDisplay()

        default: break
        }
    }

    func resetView() {
        UIView.animate(withDuration: 0.25) {
            self.viewModel.zoom = 1.0
            self.viewModel.cameraBaseX = 0
            self.viewModel.cameraBaseY = 0
            self.viewModel.cameraFineX = 0
            self.viewModel.cameraFineY = 0
            self.setNeedsDisplay()
        }
        onZoomChanged?(1.0)
    }

    // MARK: - Rendering

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Always fill background first (resolve dynamic color)
        let bgColor = UIColor.systemGray6.resolvedColor(with: traitCollection)
        ctx.setFillColor(bgColor.cgColor)
        ctx.fill(bounds)

        // Recover if zoom became invalid
        if !viewModel.zoom.isFinite || viewModel.zoom <= 0 {
            viewModel.zoom = 1.0
        }
        if !viewModel.cameraBaseX.isFinite { viewModel.cameraBaseX = 0 }
        if !viewModel.cameraBaseY.isFinite { viewModel.cameraBaseY = 0 }
        if !viewModel.cameraFineX.isFinite { viewModel.cameraFineX = 0 }
        if !viewModel.cameraFineY.isFinite { viewModel.cameraFineY = 0 }

        drawGrid(ctx)

        // Check if we need to rebuild stroke cache
        let needsCache = strokeCache == nil ||
            cacheZoom != viewModel.zoom ||
            cacheCameraBaseX != viewModel.cameraBaseX ||
            cacheCameraBaseY != viewModel.cameraBaseY ||
            cacheCameraFineX != viewModel.cameraFineX ||
            cacheCameraFineY != viewModel.cameraFineY ||
            cachedStrokeCount != viewModel.strokes.count

        if needsCache {
            rebuildStrokeCache()
        }

        // Draw cached strokes
        if let cache = strokeCache {
            cache.draw(at: .zero)
        }

        // Draw current stroke on top
        if let current = viewModel.currentStroke {
            drawStroke(current, in: ctx)
        }

        // Draw ruler guide when active
        if viewModel.isRulerActive, let guide = viewModel.rulerGuide {
            drawRulerGuide(guide, in: ctx)
        }
    }

    private func drawRulerGuide(_ guide: RulerGuide, in ctx: CGContext) {
        // Ruler guide points are in the current stroke's local space
        let ox = currentStrokeOriginX
        let oy = currentStrokeOriginY
        let startScreen = localToScreen(guide.startPoint, originX: ox, originY: oy)
        let endPoint = viewModel.snapToAngles ? guide.snappedEndPoint() : guide.endPoint
        let endScreen = localToScreen(endPoint, originX: ox, originY: oy)

        // Draw guide line
        ctx.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.5).cgColor)
        ctx.setLineWidth(1)
        ctx.setLineDash(phase: 0, lengths: [5, 3])

        ctx.beginPath()
        ctx.move(to: startScreen)
        ctx.addLine(to: endScreen)
        ctx.strokePath()

        // Draw angle indicator
        let angle = atan2(endScreen.y - startScreen.y, endScreen.x - startScreen.x)
        let angleDegrees = angle * 180 / .pi
        let length = hypot(endScreen.x - startScreen.x, endScreen.y - startScreen.y) / CGFloat(viewModel.zoom)

        // Draw markers at start and end
        ctx.setLineDash(phase: 0, lengths: [])
        ctx.setFillColor(UIColor.systemBlue.cgColor)
        ctx.fillEllipse(in: CGRect(x: startScreen.x - 4, y: startScreen.y - 4, width: 8, height: 8))
        ctx.fillEllipse(in: CGRect(x: endScreen.x - 4, y: endScreen.y - 4, width: 8, height: 8))

        // Draw measurement label
        let labelText = String(format: "%.0f° • %.0fpt", abs(angleDegrees), length)
        let midPoint = CGPoint(x: (startScreen.x + endScreen.x) / 2, y: (startScreen.y + endScreen.y) / 2 - 20)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor.systemBlue
        ]
        let size = (labelText as NSString).size(withAttributes: attributes)

        // Draw label background
        ctx.setFillColor(UIColor.systemBackground.withAlphaComponent(0.9).cgColor)
        let labelRect = CGRect(x: midPoint.x - size.width/2 - 6, y: midPoint.y - size.height/2 - 3, width: size.width + 12, height: size.height + 6)
        let path = UIBezierPath(roundedRect: labelRect, cornerRadius: 4)
        ctx.addPath(path.cgPath)
        ctx.fillPath()

        (labelText as NSString).draw(at: CGPoint(x: midPoint.x - size.width/2, y: midPoint.y - size.height/2), withAttributes: attributes)
    }

    private func rebuildStrokeCache() {
        // autoreleasepool ensures the previous cache image is freed immediately,
        // preventing memory accumulation during rapid zoom/pan
        autoreleasepool {
            let format = UIGraphicsImageRendererFormat()
            format.opaque = false
            let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)
            strokeCache = renderer.image { ctx in
                for stroke in viewModel.strokes {
                    drawStroke(stroke, in: ctx.cgContext)
                }
            }
        }
        cacheZoom = viewModel.zoom
        cacheCameraBaseX = viewModel.cameraBaseX
        cacheCameraBaseY = viewModel.cameraBaseY
        cacheCameraFineX = viewModel.cameraFineX
        cacheCameraFineY = viewModel.cameraFineY
        cachedStrokeCount = viewModel.strokes.count
    }

    private func drawStroke(_ stroke: Stroke, in ctx: CGContext) {
        guard stroke.points.count > 1 else { return }

        let screenWidth = CGFloat(Double(stroke.lineWidth) * viewModel.zoom)
        guard screenWidth > 0.01 && screenWidth.isFinite else { return }
        let safeWidth = min(screenWidth, CGFloat(30000))

        // ── Visibility check ──
        // Compute the world-space offset from stroke origin to current camera,
        // then check if the stroke's local bounding box is on screen.
        let offsetX = (stroke.originX - viewModel.cameraBaseX) - viewModel.cameraFineX
        let offsetY = (stroke.originY - viewModel.cameraBaseY) - viewModel.cameraFineY
        guard offsetX.isFinite && offsetY.isFinite else { return }

        // Bounding box of local points
        var lMinX = stroke.points[0].x, lMaxX = lMinX
        var lMinY = stroke.points[0].y, lMaxY = lMinY
        for p in stroke.points.dropFirst() {
            if p.x < lMinX { lMinX = p.x }
            if p.x > lMaxX { lMaxX = p.x }
            if p.y < lMinY { lMinY = p.y }
            if p.y > lMaxY { lMaxY = p.y }
        }
        // Convert local bbox corners to screen
        let cx = bounds.midX, cy = bounds.midY
        let z = CGFloat(viewModel.zoom)
        let ox = CGFloat(offsetX), oy = CGFloat(offsetY)
        let sMinX = (CGFloat(lMinX) + ox) * z + cx
        let sMaxX = (CGFloat(lMaxX) + ox) * z + cx
        let sMinY = (CGFloat(lMinY) + oy) * z + cy
        let sMaxY = (CGFloat(lMaxY) + oy) * z + cy
        guard sMinX.isFinite && sMaxX.isFinite && sMinY.isFinite && sMaxY.isFinite else { return }

        let margin = safeWidth + 50
        let visibleBounds = bounds.insetBy(dx: -margin, dy: -margin)
        let strokeBBox = CGRect(x: sMinX, y: sMinY, width: sMaxX - sMinX, height: sMaxY - sMinY)
        guard visibleBounds.intersects(strokeBBox) else { return }

        // ── Draw using CGContext transform (CTM) ──
        // Instead of pre-multiplying coordinates by zoom (which produces huge
        // Float32-breaking values), we set up a transform and draw in local
        // coordinates.  CG clips paths through the CTM pipeline before
        // rasterizing, so Float32 precision only matters for on-screen pixels.
        ctx.saveGState()

        // Transform: screen = (local + offset) * zoom + center
        ctx.translateBy(x: cx, y: cy)
        ctx.scaleBy(x: z, y: z)
        ctx.translateBy(x: ox, y: oy)

        // Colors and state (set AFTER saveGState)
        if stroke.isEraser {
            ctx.setBlendMode(.clear)
            ctx.setStrokeColor(UIColor.white.cgColor)
        } else {
            ctx.setBlendMode(.normal)
            ctx.setStrokeColor(red: stroke.red, green: stroke.green, blue: stroke.blue, alpha: stroke.alpha * stroke.opacity)
        }

        // Line width in world space — the CTM scales it to screen
        ctx.setLineWidth(stroke.lineWidth)
        ctx.setLineCap(stroke.toolType.lineCap)
        ctx.setLineJoin(stroke.toolType.lineJoin)

        if stroke.isDraft && !stroke.dashPattern.isEmpty {
            ctx.setLineDash(phase: 0, lengths: stroke.dashPattern)
        } else {
            ctx.setLineDash(phase: 0, lengths: [])
        }

        // Build path in local coordinates (tiny numbers — always precise)
        ctx.beginPath()
        ctx.move(to: stroke.points[0])

        if stroke.toolType == .ruler || stroke.points.count == 2 {
            ctx.addLine(to: stroke.points.last!)
        } else {
            for i in 1..<stroke.points.count {
                let p0 = stroke.points[i - 1]
                let p1 = stroke.points[i]
                let mid = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)
                if i == 1 {
                    ctx.addLine(to: mid)
                } else {
                    ctx.addQuadCurve(to: mid, control: p0)
                }
            }
            ctx.addLine(to: stroke.points.last!)
        }

        ctx.strokePath()
        ctx.restoreGState()

        // Texture effect (needs screen-space points, drawn without CTM)
        if stroke.toolType.hasTexture && safeWidth > 2 && !isTwoFingerGesture {
            let screenPoints = stroke.points.map { p -> CGPoint in
                CGPoint(x: (CGFloat(Double(p.x)) + ox) * z + cx,
                        y: (CGFloat(Double(p.y)) + oy) * z + cy)
            }
            drawTextureEffect(stroke: stroke, screenPoints: screenPoints, screenWidth: safeWidth, in: ctx)
        }

        // Reset blend mode (restoreGState already did, but be safe for cache context)
        ctx.setBlendMode(.normal)
    }

    private func drawTextureEffect(stroke: Stroke, screenPoints: [CGPoint], screenWidth: CGFloat, in ctx: CGContext) {
        let grainDensity = stroke.toolType == .crayon ? 0.15 : 0.08
        // Cap grain size so dots stay subtle at any zoom level
        let grainSize = min(screenWidth * 0.3, 3.0)

        guard grainSize > 0.5 else { return }

        ctx.setFillColor(red: stroke.red, green: stroke.green, blue: stroke.blue, alpha: stroke.alpha * stroke.opacity * CGFloat(grainDensity))

        // Seed RNG from the stroke's local-space origin so grain is stable across redraws
        let first = stroke.points[0]
        let seedX = UInt64(bitPattern: Int64(first.x * 1000))
        let seedY = UInt64(bitPattern: Int64(first.y * 1000))
        var rng = StableRNG(seed: seedX ^ (seedY &<< 32) ^ 0xDEADBEEF)

        let maxOffset = min(screenWidth / 3, 4.0)

        for i in 0..<screenPoints.count - 1 {
            let p0 = screenPoints[i]
            let p1 = screenPoints[i + 1]
            let dist = hypot(p1.x - p0.x, p1.y - p0.y)
            let steps = max(1, Int(dist / grainSize))

            for s in 0..<steps {
                let t = CGFloat(s) / CGFloat(steps)
                let x = p0.x + (p1.x - p0.x) * t
                let y = p0.y + (p1.y - p0.y) * t

                let offsetX = CGFloat.random(in: -maxOffset...maxOffset, using: &rng)
                let offsetY = CGFloat.random(in: -maxOffset...maxOffset, using: &rng)
                let dotSize = CGFloat.random(in: 0.5...grainSize, using: &rng)

                ctx.fillEllipse(in: CGRect(x: x + offsetX - dotSize/2, y: y + offsetY - dotSize/2, width: dotSize, height: dotSize))
            }
        }
    }

    private func drawGrid(_ ctx: CGContext) {
        guard viewModel.zoom > 0 && viewModel.zoom.isFinite else { return }
        guard viewModel.gridSettings.isVisible else { return }

        let gridColor = viewModel.gridSettings.color.resolvedColor(with: traitCollection)
            .withAlphaComponent(viewModel.gridSettings.opacity)

        if viewModel.gridSettings.type == .custom {
            drawCustomGrid(ctx, gridColor: gridColor)
            return
        }

        let baseSpacing = Double(viewModel.gridSettings.size.spacing)
        var spacing: Double = baseSpacing
        var s = spacing * viewModel.zoom

        // Adaptive grid - prevent infinite loops
        var iterations = 0
        while s < 15 && iterations < 50 { s *= 2; spacing *= 2; iterations += 1 }
        iterations = 0
        while s > 120 && iterations < 50 { s /= 2; spacing /= 2; iterations += 1 }

        guard s > 5 && s.isFinite else { return }

        let ox = (-viewModel.cameraX * viewModel.zoom + Double(bounds.midX)).truncatingRemainder(dividingBy: s)
        let oy = (-viewModel.cameraY * viewModel.zoom + Double(bounds.midY)).truncatingRemainder(dividingBy: s)

        guard ox.isFinite && oy.isFinite else { return }

        switch viewModel.gridSettings.type {
        case .none, .custom:
            break
        case .dots:
            drawDotsGrid(ctx, gridColor: gridColor, spacing: s, ox: ox, oy: oy)
        case .lines:
            drawLinesGrid(ctx, gridColor: gridColor, spacing: s, ox: ox, oy: oy)
        case .squares:
            drawSquaresGrid(ctx, gridColor: gridColor, spacing: s, ox: ox, oy: oy)
        case .isometric:
            drawIsometricGrid(ctx, gridColor: gridColor, spacing: s, ox: ox, oy: oy)
        }
    }

    private func drawCustomGrid(_ ctx: CGContext, gridColor: UIColor) {
        let hSpacing = Double(viewModel.gridSettings.horizontalSpacing) * viewModel.zoom
        let vSpacing = Double(viewModel.gridSettings.verticalSpacing) * viewModel.zoom

        // Apply adaptive scaling
        var hS = hSpacing
        var vS = vSpacing
        var scale: Double = 1

        var iterations = 0
        while (hS < 10 || vS < 10) && iterations < 50 {
            hS *= 2
            vS *= 2
            scale *= 2
            iterations += 1
        }
        iterations = 0
        while (hS > 150 && vS > 150) && iterations < 50 {
            hS /= 2
            vS /= 2
            scale /= 2
            iterations += 1
        }

        guard hS > 3 && vS > 3 && hS.isFinite && vS.isFinite else { return }

        let ox = (-viewModel.cameraX * viewModel.zoom + Double(bounds.midX)).truncatingRemainder(dividingBy: hS)
        let oy = (-viewModel.cameraY * viewModel.zoom + Double(bounds.midY)).truncatingRemainder(dividingBy: vS)

        guard ox.isFinite && oy.isFinite else { return }

        ctx.setStrokeColor(gridColor.cgColor)
        ctx.setLineWidth(0.5)

        // Draw vertical lines
        var x = ox - hS
        while x < Double(bounds.width) + hS {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: Double(bounds.height)))
            ctx.strokePath()
            x += hS
        }

        // Draw horizontal lines
        var y = oy - vS
        while y < Double(bounds.height) + vS {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: Double(bounds.width), y: y))
            ctx.strokePath()
            y += vS
        }

        // Draw major lines (thicker) at original spacing intervals
        let majorHSpacing = hSpacing * scale
        let majorVSpacing = vSpacing * scale

        if scale > 1 {
            ctx.setLineWidth(1.5)
            ctx.setStrokeColor(gridColor.withAlphaComponent(0.7).cgColor)

            let majorOx = (-viewModel.cameraX * viewModel.zoom + Double(bounds.midX)).truncatingRemainder(dividingBy: majorHSpacing)
            let majorOy = (-viewModel.cameraY * viewModel.zoom + Double(bounds.midY)).truncatingRemainder(dividingBy: majorVSpacing)

            // Major vertical lines
            x = majorOx - majorHSpacing
            while x < Double(bounds.width) + majorHSpacing {
                ctx.beginPath()
                ctx.move(to: CGPoint(x: x, y: 0))
                ctx.addLine(to: CGPoint(x: x, y: Double(bounds.height)))
                ctx.strokePath()
                x += majorHSpacing
            }

            // Major horizontal lines
            y = majorOy - majorVSpacing
            while y < Double(bounds.height) + majorVSpacing {
                ctx.beginPath()
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: Double(bounds.width), y: y))
                ctx.strokePath()
                y += majorVSpacing
            }
        }

        // Draw dots at intersections
        ctx.setFillColor(gridColor.withAlphaComponent(0.8).cgColor)
        let dotR: Double = 2

        x = ox - hS
        while x < Double(bounds.width) + hS {
            y = oy - vS
            while y < Double(bounds.height) + vS {
                ctx.fillEllipse(in: CGRect(x: x - dotR, y: y - dotR, width: dotR * 2, height: dotR * 2))
                y += vS
            }
            x += hS
        }
    }

    private func drawDotsGrid(_ ctx: CGContext, gridColor: UIColor, spacing s: Double, ox: Double, oy: Double) {
        ctx.setFillColor(gridColor.cgColor)
        let r = max(1.0, min(2.5, s / 30))

        var x = ox - s
        while x < Double(bounds.width) + s {
            var y = oy - s
            while y < Double(bounds.height) + s {
                ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                y += s
            }
            x += s
        }
    }

    private func drawLinesGrid(_ ctx: CGContext, gridColor: UIColor, spacing s: Double, ox: Double, oy: Double) {
        ctx.setStrokeColor(gridColor.cgColor)
        ctx.setLineWidth(0.5)

        // Horizontal lines
        var y = oy - s
        while y < Double(bounds.height) + s {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: Double(bounds.width), y: y))
            ctx.strokePath()
            y += s
        }

        // Vertical lines
        var x = ox - s
        while x < Double(bounds.width) + s {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: Double(bounds.height)))
            ctx.strokePath()
            x += s
        }
    }

    private func drawSquaresGrid(_ ctx: CGContext, gridColor: UIColor, spacing s: Double, ox: Double, oy: Double) {
        ctx.setStrokeColor(gridColor.cgColor)
        ctx.setLineWidth(0.5)

        // Draw grid squares
        var x = ox - s
        while x < Double(bounds.width) + s {
            var y = oy - s
            while y < Double(bounds.height) + s {
                ctx.stroke(CGRect(x: x, y: y, width: s, height: s))
                y += s
            }
            x += s
        }

        // Draw thicker lines every 4 squares
        ctx.setLineWidth(1.5)
        ctx.setStrokeColor(gridColor.withAlphaComponent(0.6).cgColor)

        let majorSpacing = s * 4
        let majorOx = (-viewModel.cameraX * viewModel.zoom + Double(bounds.midX)).truncatingRemainder(dividingBy: majorSpacing)
        let majorOy = (-viewModel.cameraY * viewModel.zoom + Double(bounds.midY)).truncatingRemainder(dividingBy: majorSpacing)

        // Major horizontal lines
        var my = majorOy - majorSpacing
        while my < Double(bounds.height) + majorSpacing {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 0, y: my))
            ctx.addLine(to: CGPoint(x: Double(bounds.width), y: my))
            ctx.strokePath()
            my += majorSpacing
        }

        // Major vertical lines
        var mx = majorOx - majorSpacing
        while mx < Double(bounds.width) + majorSpacing {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: mx, y: 0))
            ctx.addLine(to: CGPoint(x: mx, y: Double(bounds.height)))
            ctx.strokePath()
            mx += majorSpacing
        }
    }

    private func drawIsometricGrid(_ ctx: CGContext, gridColor: UIColor, spacing s: Double, ox: Double, oy: Double) {
        ctx.setStrokeColor(gridColor.cgColor)
        ctx.setLineWidth(0.5)

        let angle: Double = .pi / 6 // 30 degrees
        let verticalSpacing = s * cos(angle)

        // Horizontal lines
        var y = oy.truncatingRemainder(dividingBy: verticalSpacing) - verticalSpacing
        while y < Double(bounds.height) + verticalSpacing {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: Double(bounds.width), y: y))
            ctx.strokePath()
            y += verticalSpacing
        }

        // Diagonal lines (left to right, going down)
        let diagonalLength = sqrt(pow(Double(bounds.width), 2) + pow(Double(bounds.height), 2))
        var startX = ox.truncatingRemainder(dividingBy: s) - diagonalLength
        while startX < Double(bounds.width) + diagonalLength {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: startX, y: 0))
            ctx.addLine(to: CGPoint(x: startX + Double(bounds.height) / tan(angle), y: Double(bounds.height)))
            ctx.strokePath()
            startX += s
        }

        // Diagonal lines (right to left, going down)
        startX = ox.truncatingRemainder(dividingBy: s) - diagonalLength + Double(bounds.width)
        while startX > -diagonalLength {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: startX, y: 0))
            ctx.addLine(to: CGPoint(x: startX - Double(bounds.height) / tan(angle), y: Double(bounds.height)))
            ctx.strokePath()
            startX -= s
        }
    }
}

// MARK: - Gesture Delegate

extension InfiniteCanvasUIView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ a: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith b: UIGestureRecognizer) -> Bool {
        return true // Allow pinch + pan together
    }
}

// MARK: - PKToolPicker Observer

extension InfiniteCanvasUIView: PKToolPickerObserver {
    func toolPickerSelectedToolDidChange(_ toolPicker: PKToolPicker) {
        syncToolFromPicker()
    }

    func toolPickerIsRulerActiveDidChange(_ toolPicker: PKToolPicker) {
        viewModel.isRulerActive = toolPicker.isRulerActive
        setNeedsDisplay()
    }

    func toolPickerVisibilityDidChange(_ toolPicker: PKToolPicker) {
        if toolPicker.isVisible { return }
        // Re-become first responder to keep tool picker visible
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.window != nil else { return }
            self.becomeFirstResponder()
        }
    }
}
