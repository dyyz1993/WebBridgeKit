import SwiftUI
import WebBridgeKit

extension Color {
    static var appBackground: Color { Color(ThemeTokens.Color.background) }
    static var appCardBackground: Color { Color(ThemeTokens.Color.cardBackground) }
    static var appPrimary: Color { Color(ThemeTokens.Color.primary) }
    static var appText: Color { Color(ThemeTokens.Color.text) }
    static var appTextSecondary: Color { Color(ThemeTokens.Color.textSecondary) }
    static var appTextTertiary: Color { Color(ThemeTokens.Color.textTertiary) }
    static var appSeparator: Color { Color(ThemeTokens.Color.separator) }
    static var appError: Color { Color(ThemeTokens.Color.error) }
    static var appSuccess: Color { Color(ThemeTokens.Color.success) }

    init(_ uiColor: UIColor) {
        if #available(iOS 15.0, *) {
            self.init(uiColor: uiColor)
        } else {
            self.init(UIColor { trait in
                uiColor.resolvedColor(with: trait)
            })
        }
    }
}

struct AppBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden).background(Color.appBackground)
        } else {
            content.background(Color.appBackground)
        }
    }
}

extension Font {
    static func app(_ uiFont: UIFont) -> Font {
        let textStyle: UIFont.TextStyle
        let size = uiFont.pointSize
        if size >= 28 { textStyle = .largeTitle }
        else if size >= 22 { textStyle = .title1 }
        else if size >= 17 { textStyle = .headline }
        else if size >= 15 { textStyle = .body }
        else if size >= 13 { textStyle = .footnote }
        else if size >= 12 { textStyle = .caption1 }
        else { textStyle = .caption2 }
        return Font.system(size: size, design: .default)
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var isActive = false
    let duration: Double = 1.5

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if UIAccessibility.isReduceMotionEnabled {
                        Color.appBackgroundTertiary.opacity(0.6)
                    } else {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.appBackgroundSecondary.opacity(0.6),
                                Color.clear
                            ]),
                            startPoint: .init(x: isActive ? 1 : -1, y: 0.5),
                            endPoint: .init(x: isActive ? 2 : 0, y: 0.5)
                        )
                    }
                }
            )
            .onAppear {
                guard !UIAccessibility.isReduceMotionEnabled else { return }
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: false)) {
                    isActive = true
                }
            }
    }
}

extension Color {
    static var appBackgroundSecondary: Color { Color(ThemeTokens.Color.backgroundSecondary) }
    static var appBackgroundTertiary: Color { Color(ThemeTokens.Color.backgroundTertiary) }
}

extension View {
    func appListStyle() -> some View {
        modifier(AppBackgroundModifier())
    }

    func staggerIn(index: Int, appeared: Bool) -> some View {
        modifier(StaggerInModifier(index: index, appeared: appeared))
    }

    func springAppear(appeared: Bool, delay: Double = 0) -> some View {
        modifier(SpringAppearModifier(appeared: appeared, delay: delay))
    }

    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

struct StaggerInModifier: ViewModifier {
    let index: Int
    let appeared: Bool
    let staggerInterval: Double = 0.05

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content.opacity(appeared ? 1 : 0)
        } else {
            content
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(
                    .spring(
                        response: ThemeTokens.Animation.spring.duration,
                        dampingFraction: ThemeTokens.Animation.spring.damping
                    ).delay(Double(index) * staggerInterval),
                    value: appeared
                )
        }
    }
}

struct SpringAppearModifier: ViewModifier {
    let appeared: Bool
    let delay: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content.opacity(appeared ? 1 : 0)
        } else {
            content
                .scaleEffect(appeared ? 1.0 : 0.92)
                .opacity(appeared ? 1.0 : 0.0)
                .animation(
                    .spring(
                        response: ThemeTokens.Animation.spring.duration,
                        dampingFraction: ThemeTokens.Animation.spring.damping
                    ).delay(delay),
                    value: appeared
                )
        }
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        if reduceMotion {
            configuration.label
        } else {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .animation(.easeOut(duration: ThemeTokens.Animation.fast.duration), value: configuration.isPressed)
        }
    }
}
