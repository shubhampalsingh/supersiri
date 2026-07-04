import SwiftUI

/// SuperSiri design system — "Ink & Ember".
/// Deep ink surfaces, a warm ember→amber accent, rounded display type,
/// and soft glass layers. One place to change the app's whole look.
enum Theme {
    // MARK: Palette

    /// Primary accent — warm ember.
    static let ember = Color(red: 0.98, green: 0.45, blue: 0.30)
    /// Secondary accent — amber glow.
    static let amber = Color(red: 1.00, green: 0.72, blue: 0.30)
    /// Deep anchor used in gradients and dark surfaces.
    static let ink = Color(red: 0.09, green: 0.09, blue: 0.12)

    /// The signature accent gradient.
    static let accent = LinearGradient(
        colors: [ember, amber],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Subtle vertical wash used behind full screens.
    static var backdrop: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.systemBackground), ember.opacity(0.06)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    /// Card surface that adapts to light/dark.
    static let card = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.11, alpha: 1.0)
            : UIColor.secondarySystemGroupedBackground
    })

    /// Hairline border for cards.
    static let hairline = Color.primary.opacity(0.06)

    // MARK: Type

    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // MARK: Metrics

    static let cornerRadius: CGFloat = 20
    static let bubbleRadius: CGFloat = 22
}

// MARK: - Reusable components

/// The SuperSiri brand mark: a warm gradient orb with a spark.
struct BrandOrb: View {
    var size: CGFloat = 64
    var animated: Bool = false
    @State private var glowing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.amber, Theme.ember, Theme.ink],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: size * 0.05,
                        endRadius: size * 0.75
                    )
                )
                .shadow(color: Theme.ember.opacity(glowing ? 0.55 : 0.3), radius: size * 0.25, y: size * 0.06)

            Image(systemName: "sparkle")
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .scaleEffect(glowing ? 1.03 : 1.0)
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glowing = true
            }
        }
    }
}

/// Card container used across list screens.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardBackground())
    }
}

/// Small gradient tile behind an SF Symbol — used for workflow icons.
struct IconTile: View {
    let systemName: String
    var size: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(Theme.accent)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}

/// Prominent gradient button style for primary actions.
struct EmberButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(17, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}
