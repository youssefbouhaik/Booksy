//
//  ReaderComponents.swift
//  Folio / Books
//
//  Shared UI components, shapes, and helpers for Booksy Reader
//

import SwiftUI
import AppKit

// MARK: - Circular Apple Books Tool Button
struct AppleBooksIconButton: View {
    let icon: String?
    let text: String?
    let isActive: Bool
    let activeColor: Color?
    let tooltip: String
    let action: () -> Void
    
    @State private var isHovered: Bool = false
    
    init(systemName: String, isActive: Bool = false, activeColor: Color? = nil, tooltip: String = "", action: @escaping () -> Void) {
        self.icon = systemName
        self.text = nil
        self.isActive = isActive
        self.activeColor = activeColor
        self.tooltip = tooltip
        self.action = action
    }
    
    init(text: String, isActive: Bool = false, activeColor: Color? = nil, tooltip: String = "", action: @escaping () -> Void) {
        self.icon = nil
        self.text = text
        self.isActive = isActive
        self.activeColor = activeColor
        self.tooltip = tooltip
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isHovered ? Color.primary.opacity(0.08) : (isActive ? Color.primary.opacity(0.12) : Color.clear))
                    .frame(width: 28, height: 28)
                
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(isActive ? (activeColor ?? .primary) : .primary.opacity(0.85))
                } else if let text = text {
                    Text(text)
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundColor(isActive ? (activeColor ?? .primary) : .primary.opacity(0.85))
                }
            }
            .frame(width: 32, height: 32)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .focusEffectDisabled()
        .help(tooltip)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = h
            }
        }
    }
}

// MARK: - Red Bookmark Ribbon Shape
struct BookmarkRibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 8))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Window Accessor
struct WindowAccessor: NSViewRepresentable {
    var onWindow: (NSWindow) -> Void
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let w = view.window {
                onWindow(w)
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        if let w = nsView.window {
            onWindow(w)
        }
    }
}

// MARK: - Color Hex Initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
