//
//  DrawingTools.swift
//  infinitenote
//

import UIKit
import SwiftUI

// MARK: - Tool Types

enum DrawingToolType: String, CaseIterable, Identifiable {
    case pencil
    case pen
    case marker
    case highlighter
    case crayon
    case eraser
    case ruler

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pencil: return "pencil"
        case .pen: return "pencil.tip"
        case .marker: return "paintbrush.pointed"
        case .highlighter: return "highlighter"
        case .crayon: return "scribble.variable"
        case .eraser: return "eraser"
        case .ruler: return "ruler"
        }
    }

    var displayName: String {
        switch self {
        case .pencil: return "Pencil"
        case .pen: return "Pen"
        case .marker: return "Marker"
        case .highlighter: return "Highlighter"
        case .crayon: return "Crayon"
        case .eraser: return "Eraser"
        case .ruler: return "Ruler"
        }
    }

    var defaultOpacity: CGFloat {
        switch self {
        case .highlighter: return 0.3
        default: return 1.0
        }
    }

    var minLineWidth: CGFloat {
        switch self {
        case .pencil: return 1.0
        case .pen: return 0.5
        case .marker: return 8.0
        case .highlighter: return 15.0
        case .crayon: return 6.0
        case .eraser: return 10.0
        case .ruler: return 1.0
        }
    }

    var maxLineWidth: CGFloat {
        switch self {
        case .pencil: return 8.0
        case .pen: return 4.0
        case .marker: return 30.0
        case .highlighter: return 40.0
        case .crayon: return 20.0
        case .eraser: return 50.0
        case .ruler: return 8.0
        }
    }

    var defaultLineWidth: CGFloat {
        switch self {
        case .pencil: return 3.0
        case .pen: return 1.5
        case .marker: return 15.0
        case .highlighter: return 25.0
        case .crayon: return 10.0
        case .eraser: return 20.0
        case .ruler: return 2.0
        }
    }

    // Texture characteristics
    var hasTexture: Bool {
        switch self {
        case .pencil, .crayon: return true
        default: return false
        }
    }

    var lineCap: CGLineCap {
        switch self {
        case .highlighter: return .square
        case .marker: return .round
        default: return .round
        }
    }

    var lineJoin: CGLineJoin {
        switch self {
        case .highlighter: return .bevel
        default: return .round
        }
    }
}

// MARK: - Drawing Tool Configuration

struct DrawingToolConfig {
    var toolType: DrawingToolType
    var lineWidth: CGFloat
    var opacity: CGFloat
    var color: UIColor

    init(toolType: DrawingToolType, color: UIColor = .black) {
        self.toolType = toolType
        self.lineWidth = toolType.defaultLineWidth
        self.opacity = toolType.defaultOpacity
        self.color = color
    }

    mutating func setLineWidth(_ width: CGFloat) {
        lineWidth = max(toolType.minLineWidth, min(toolType.maxLineWidth, width))
    }
}

// MARK: - Preset Line Widths

struct LineWidthPreset: Identifiable {
    let id = UUID()
    let width: CGFloat
    let displaySize: CGFloat

    static func presetsFor(_ tool: DrawingToolType) -> [LineWidthPreset] {
        let min = tool.minLineWidth
        let max = tool.maxLineWidth
        let mid = (min + max) / 2
        let quarter = (min + mid) / 2
        let threeQuarter = (mid + max) / 2

        return [
            LineWidthPreset(width: min, displaySize: 6),
            LineWidthPreset(width: quarter, displaySize: 10),
            LineWidthPreset(width: mid, displaySize: 16),
            LineWidthPreset(width: threeQuarter, displaySize: 22),
            LineWidthPreset(width: max, displaySize: 28)
        ]
    }
}

// MARK: - Draft Mode

enum DraftMode: String, CaseIterable {
    case off
    case light
    case heavy

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .light: return "Light"
        case .heavy: return "Heavy"
        }
    }

    var icon: String {
        switch self {
        case .off: return "square"
        case .light: return "square.grid.2x2"
        case .heavy: return "square.grid.3x3"
        }
    }

    var opacity: CGFloat {
        switch self {
        case .off: return 1.0
        case .light: return 0.5
        case .heavy: return 0.25
        }
    }

    var isDashed: Bool {
        return self != .off
    }

    var dashPattern: [CGFloat] {
        switch self {
        case .off: return []
        case .light: return [8, 4]
        case .heavy: return [4, 4]
        }
    }
}

// MARK: - Color Palette

struct ColorPalette {
    static let basic: [UIColor] = [
        .black,
        .darkGray,
        .gray,
        .white,
        .systemRed,
        .systemOrange,
        .systemYellow,
        .systemGreen,
        .systemTeal,
        .systemBlue,
        .systemIndigo,
        .systemPurple,
        .systemPink,
        .brown
    ]

    static let highlighter: [UIColor] = [
        UIColor.systemYellow,
        UIColor.systemGreen,
        UIColor.systemPink,
        UIColor.systemBlue,
        UIColor.systemOrange,
        UIColor.systemPurple
    ]
}

// MARK: - Grid Settings

enum GridType: String, CaseIterable {
    case none
    case dots
    case lines
    case squares
    case isometric
    case custom

    var displayName: String {
        switch self {
        case .none: return "None"
        case .dots: return "Dots"
        case .lines: return "Lines"
        case .squares: return "Squares"
        case .isometric: return "Isometric"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .none: return "square.slash"
        case .dots: return "circle.grid.3x3"
        case .lines: return "line.3.horizontal"
        case .squares: return "squareshape.split.3x3"
        case .isometric: return "triangle"
        case .custom: return "slider.horizontal.3"
        }
    }
}

enum GridSize: String, CaseIterable {
    case small
    case medium
    case large
    case extraLarge

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }

    var spacing: CGFloat {
        switch self {
        case .small: return 20
        case .medium: return 40
        case .large: return 60
        case .extraLarge: return 100
        }
    }

    var icon: String {
        switch self {
        case .small: return "s.square"
        case .medium: return "m.square"
        case .large: return "l.square"
        case .extraLarge: return "xl.square"
        }
    }
}

struct GridSettings {
    var type: GridType = .dots
    var size: GridSize = .medium
    var color: UIColor = .systemGray4
    var opacity: CGFloat = 1.0

    // Custom grid settings
    var customHorizontal: CGFloat = 2  // Number of units horizontally
    var customVertical: CGFloat = 3    // Number of units vertically
    var customUnitSize: CGFloat = 20   // Size of each unit in points

    var isVisible: Bool {
        type != .none
    }

    // Get the actual spacing based on type
    var horizontalSpacing: CGFloat {
        if type == .custom {
            return customHorizontal * customUnitSize
        }
        return size.spacing
    }

    var verticalSpacing: CGFloat {
        if type == .custom {
            return customVertical * customUnitSize
        }
        return size.spacing
    }

    // Display string for custom grid
    var customDisplayString: String {
        let h = customHorizontal.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", customHorizontal) : String(format: "%.1f", customHorizontal)
        let v = customVertical.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", customVertical) : String(format: "%.1f", customVertical)
        return "\(h) × \(v)"
    }
}

// MARK: - Ruler Guide

struct RulerGuide {
    var startPoint: CGPoint
    var endPoint: CGPoint
    var isActive: Bool = false

    var angle: CGFloat {
        atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
    }

    var length: CGFloat {
        hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y)
    }

    // Snap angle to common angles (0, 15, 30, 45, 60, 75, 90 degrees)
    func snappedEndPoint(snapToAngles: Bool = true) -> CGPoint {
        guard snapToAngles else { return endPoint }

        let currentAngle = angle
        let snapAngles: [CGFloat] = [0, 15, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165, 180,
                                      -15, -30, -45, -60, -75, -90, -105, -120, -135, -150, -165]
            .map { $0 * .pi / 180 }

        var closestAngle = currentAngle
        var minDiff = CGFloat.greatestFiniteMagnitude

        for snapAngle in snapAngles {
            let diff = abs(currentAngle - snapAngle)
            if diff < minDiff && diff < (10 * .pi / 180) { // 10 degree threshold
                minDiff = diff
                closestAngle = snapAngle
            }
        }

        let len = length
        return CGPoint(
            x: startPoint.x + cos(closestAngle) * len,
            y: startPoint.y + sin(closestAngle) * len
        )
    }
}
