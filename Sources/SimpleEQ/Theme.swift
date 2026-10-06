import SwiftUI

enum AppStyle: String, CaseIterable, Identifiable {
    case glass
    case website

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glass: return "Glass"
        case .website: return "Website"
        }
    }

    var subtitle: String {
        switch self {
        case .glass: return "Dark HUD"
        case .website: return "Light"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .glass: return .dark
        case .website: return .light
        }
    }
}

struct ThemePalette {
    let canvasTop: Color
    let canvasBottom: Color
    let panelFill: Color
    let panelStroke: Color
    let panelHighlight: Color
    let elevatedFill: Color
    let trackFill: Color

    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color

    let accent: Color
    let accentWarm: Color
    let danger: Color
    let success: Color

    let primaryButtonTop: Color
    let primaryButtonBottom: Color
    let primaryButtonText: Color
    let secondaryButtonFill: Color

    let useMaterial: Bool
    let panelShadow: Color
    let panelShadowRadius: CGFloat
    let markGradient: [Color]
    let ambientA: Color
    let ambientB: Color

    static let glass = ThemePalette(
        canvasTop: Color(red: 0.09, green: 0.09, blue: 0.10),
        canvasBottom: Color(red: 0.14, green: 0.12, blue: 0.11),
        panelFill: Color.white.opacity(0.06),
        panelStroke: Color.white.opacity(0.10),
        panelHighlight: Color.white.opacity(0.14),
        elevatedFill: Color.white.opacity(0.06),
        trackFill: Color.white.opacity(0.08),
        textPrimary: Color(red: 0.98, green: 0.95, blue: 0.92),
        textSecondary: Color.white.opacity(0.45),
        textTertiary: Color.white.opacity(0.28),
        accent: Color(red: 0.93, green: 0.51, blue: 0.93),
        accentWarm: Color(red: 0.96, green: 0.62, blue: 0.38),
        danger: Color(red: 1.0, green: 0.42, blue: 0.42),
        success: Color(red: 0.45, green: 0.88, blue: 0.62),
        primaryButtonTop: Color(red: 0.98, green: 0.94, blue: 0.90),
        primaryButtonBottom: Color(red: 0.92, green: 0.88, blue: 0.84),
        primaryButtonText: Color(red: 0.12, green: 0.11, blue: 0.10),
        secondaryButtonFill: Color.white.opacity(0.08),
        useMaterial: true,
        panelShadow: Color.black.opacity(0.35),
        panelShadowRadius: 24,
        markGradient: [
            Color(red: 0.22, green: 0.20, blue: 0.19),
            Color(red: 0.12, green: 0.11, blue: 0.10),
        ],
        ambientA: Color(red: 0.93, green: 0.51, blue: 0.93).opacity(0.12),
        ambientB: Color(red: 0.96, green: 0.62, blue: 0.38).opacity(0.10)
    )

    static let website = ThemePalette(
        canvasTop: Color(red: 1.00, green: 0.97, blue: 0.94),
        canvasBottom: Color(red: 0.99, green: 0.94, blue: 0.88),
        panelFill: Color.white.opacity(0.78),
        panelStroke: Color(red: 0.88, green: 0.84, blue: 0.80),
        panelHighlight: Color.white.opacity(0.95),
        elevatedFill: Color(red: 0.12, green: 0.11, blue: 0.10).opacity(0.05),
        trackFill: Color(red: 0.12, green: 0.11, blue: 0.10).opacity(0.08),
        textPrimary: Color(red: 0.16, green: 0.14, blue: 0.13),
        textSecondary: Color(red: 0.16, green: 0.14, blue: 0.13).opacity(0.55),
        textTertiary: Color(red: 0.16, green: 0.14, blue: 0.13).opacity(0.35),
        accent: Color(red: 0.85, green: 0.35, blue: 0.85),
        accentWarm: Color(red: 0.92, green: 0.45, blue: 0.22),
        danger: Color(red: 0.86, green: 0.25, blue: 0.25),
        success: Color(red: 0.18, green: 0.62, blue: 0.38),
        primaryButtonTop: Color(red: 0.18, green: 0.16, blue: 0.15),
        primaryButtonBottom: Color(red: 0.12, green: 0.11, blue: 0.10),
        primaryButtonText: Color(red: 1.00, green: 0.97, blue: 0.94),
        secondaryButtonFill: Color(red: 0.12, green: 0.11, blue: 0.10).opacity(0.06),
        useMaterial: false,
        panelShadow: Color(red: 0.16, green: 0.14, blue: 0.13).opacity(0.12),
        panelShadowRadius: 20,
        markGradient: [
            Color(red: 0.22, green: 0.20, blue: 0.19),
            Color(red: 0.12, green: 0.11, blue: 0.10),
        ],
        ambientA: Color(red: 0.96, green: 0.62, blue: 0.38).opacity(0.18),
        ambientB: Color(red: 0.93, green: 0.51, blue: 0.93).opacity(0.10)
    )

    static func palette(for style: AppStyle) -> ThemePalette {
        switch style {
        case .glass: return .glass
        case .website: return .website
        }
    }
}

enum Theme {
    static let radiusLg: CGFloat = 20
    static let radiusMd: CGFloat = 14
    static let radiusSm: CGFloat = 10

    static let bandPastels: [Color] = [
        Color(red: 0.95, green: 0.55, blue: 0.55),
        Color(red: 0.96, green: 0.62, blue: 0.38),
        Color(red: 0.98, green: 0.82, blue: 0.45),
        Color(red: 0.72, green: 0.88, blue: 0.48),
        Color(red: 0.45, green: 0.85, blue: 0.72),
        Color(red: 0.48, green: 0.72, blue: 0.98),
        Color(red: 0.68, green: 0.58, blue: 0.98),
        Color(red: 0.93, green: 0.51, blue: 0.93),
        Color(red: 0.95, green: 0.55, blue: 0.70),
        Color(red: 0.98, green: 0.75, blue: 0.62),
        Color(red: 0.85, green: 0.78, blue: 0.65),
        Color(red: 0.70, green: 0.85, blue: 0.90),
        Color(red: 0.75, green: 0.70, blue: 0.95),
        Color(red: 0.95, green: 0.60, blue: 0.80),
        Color(red: 0.90, green: 0.70, blue: 0.55),
        Color(red: 0.80, green: 0.80, blue: 0.85),
    ]

    static func bandColor(at index: Int) -> Color {
        bandPastels[index % bandPastels.count]
    }
}

private struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue = ThemePalette.glass
}

private struct AppStyleKey: EnvironmentKey {
    static let defaultValue = AppStyle.glass
}

extension EnvironmentValues {
    var theme: ThemePalette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }

    var appStyle: AppStyle {
        get { self[AppStyleKey.self] }
        set { self[AppStyleKey.self] = newValue }
    }
}

extension View {
    func appStyle(_ style: AppStyle) -> some View {
        environment(\.appStyle, style)
            .environment(\.theme, ThemePalette.palette(for: style))
            .preferredColorScheme(style.preferredColorScheme)
    }
}

struct StylePanel<Content: View>: View {
    var padding: CGFloat = 16
    @Environment(\.theme) private var theme
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background { panelBackground }
    }

    @ViewBuilder
    private var panelBackground: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
        ZStack {
            if theme.useMaterial {
                shape.fill(.ultraThinMaterial)
            }
            shape.fill(theme.panelFill)
            shape.strokeBorder(
                LinearGradient(
                    colors: [theme.panelHighlight, theme.panelStroke.opacity(0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        }
        .shadow(color: theme.panelShadow, radius: theme.panelShadowRadius, y: 10)
    }
}

struct SectionLabel: View {
    let title: String
    @Environment(\.theme) private var theme

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(theme.textTertiary)
    }
}

struct PillButton: View {
    enum Kind { case primary, secondary, ghost }

    let title: String
    var icon: String? = nil
    var kind: Kind = .secondary
    var isDisabled: Bool = false
    let action: () -> Void

    @Environment(\.theme) private var theme
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            }
            .shadow(color: kind == .primary ? theme.panelShadow : .clear, radius: kind == .primary ? 12 : 0, y: 6)
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: pressed)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }

    private var background: some ShapeStyle {
        switch kind {
        case .primary:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [theme.primaryButtonTop, theme.primaryButtonBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .secondary:
            return AnyShapeStyle(theme.secondaryButtonFill)
        case .ghost:
            return AnyShapeStyle(Color.clear)
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: return theme.primaryButtonText
        case .secondary, .ghost: return theme.textPrimary
        }
    }

    private var stroke: Color {
        switch kind {
        case .primary: return theme.panelHighlight.opacity(0.5)
        case .secondary: return theme.panelStroke
        case .ghost: return .clear
        }
    }
}

struct StatusChip: View {
    let text: String
    var live: Bool = false
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(live ? theme.success : theme.textTertiary)
                .frame(width: 6, height: 6)
                .shadow(color: live ? theme.success.opacity(0.7) : .clear, radius: 4)
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.elevatedFill, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(theme.panelStroke, lineWidth: 1)
        }
    }
}

struct StylePicker: View {
    @Binding var style: AppStyle
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppStyle.allCases) { item in
                let selected = style == item
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        style = item
                    }
                } label: {
                    Text(item.title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(selected ? theme.primaryButtonText : theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background {
                            if selected {
                                Capsule(style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [theme.primaryButtonTop, theme.primaryButtonBottom],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                        }
                }
                .buttonStyle(.plain)
                .help(item.subtitle)
            }
        }
        .padding(3)
        .background(theme.elevatedFill, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(theme.panelStroke, lineWidth: 1)
        }
    }
}

struct AppCanvas: View {
    @Environment(\.theme) private var theme
    @Environment(\.appStyle) private var style

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.canvasTop, theme.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(theme.ambientA)
                .frame(width: style == .website ? 360 : 280, height: style == .website ? 360 : 280)
                .blur(radius: style == .website ? 100 : 80)
                .offset(x: 160, y: -100)

            Circle()
                .fill(theme.ambientB)
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: -140, y: 180)
        }
        .ignoresSafeArea()
    }
}
