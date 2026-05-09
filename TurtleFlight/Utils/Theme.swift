import SwiftUI

/// Design tokens for the SwiftUI surfaces of Turtle Flight.
///
/// Every view should reference values through `Theme.*` rather than baking
/// in literal magic numbers (16pt corner radius here, 12pt over there) or
/// inline hex codes. Token names are *semantic* — `surfaceSelected` rather
/// than `whiteOpacity100` — so the tokens can be retuned later without
/// rewriting each call site.
///
/// Underlying brand colors continue to live in `Constants.Colors` (the raw
/// hex palette). `Theme.Color` is the API surface; `Constants.Colors` is
/// the source palette.
///
/// Migration notes:
///   • Existing views can adopt incrementally — replace one `RoundedRectangle(
///     cornerRadius: 16)` with `Theme.Radius.l` at a time.
///   • The `.elevation(_:)` view modifier wraps the SwiftUI `.shadow(...)`
///     so the four shadow parameters travel together as a unit.
///   • Typography tokens return `Font` values for direct use:
///     `.font(Theme.Typography.title)`.
enum Theme {

    // MARK: - Colors (semantic)

    enum Color {
        // Brand
        /// Turbo's mint, the marketing-facing brand color (matches the
        /// `Turbo` palette in CHARACTER_DESIGN_PROMPT.md).
        static let brandPrimary    = SwiftUI.Color(hex: Constants.Colors.turboMint)
        /// Sky blue used for theme.sky background gradient & launch screen.
        static let brandSky        = SwiftUI.Color(hex: Constants.Colors.skyBlue)

        // Surfaces (cards, panels)
        /// Translucent white card for grid tiles in their idle state.
        static let surfaceMuted    = SwiftUI.Color.white.opacity(0.20)
        /// Solid white card for the selected tile.
        static let surfaceSelected = SwiftUI.Color.white
        /// Translucent overlay used for HUD chips on top of the 3D scene.
        static let surfaceOverlay  = SwiftUI.Color(hex: Constants.Colors.panelDark).opacity(0.7)
        /// Slightly more transparent surfaceOverlay for region-name chip.
        static let surfaceOverlayMuted = SwiftUI.Color(hex: Constants.Colors.panelDark).opacity(0.5)
        /// Less translucent surfaceOverlay used by Mission stage-title pill.
        static let surfaceOverlayStrong = SwiftUI.Color(hex: Constants.Colors.panelDark).opacity(0.8)
        /// Near-opaque dark panel used by full-screen result overlays.
        static let surfacePanel = SwiftUI.Color(hex: Constants.Colors.panelDark).opacity(0.9)
        /// Subtler chip used by the collision counter on top of the HUD.
        static let surfaceOverlaySubtle = SwiftUI.Color(hex: Constants.Colors.panelDark).opacity(0.6)

        // Text
        static let textPrimary     = SwiftUI.Color(hex: Constants.Colors.panelDark)
        static let textOnDark      = SwiftUI.Color.white
        static let textOnDarkMuted = SwiftUI.Color.white.opacity(0.7)
        static let textOnDarkFaint = SwiftUI.Color.white.opacity(0.5)

        // Status / accent
        /// Easy difficulty / safe state — NOT Turbo's brand (see C4 in
        /// DESIGN_GAP_REPORT). Use `brandPrimary` for Turbo.
        static let easyGreen     = SwiftUI.Color(hex: Constants.Colors.easyGreen)
        static let normalYellow  = SwiftUI.Color(hex: Constants.Colors.normalYellow)
        static let expertRed     = SwiftUI.Color(hex: Constants.Colors.expertRed)
        static let starGold      = SwiftUI.Color(hex: Constants.Colors.starGold)
        static let boostOrange   = SwiftUI.Color(hex: Constants.Colors.boostOrange)
        static let hudCyan       = SwiftUI.Color(hex: Constants.Colors.hudCyan)
    }

    // MARK: - Spacing

    /// Spacing scale. Used for `padding(...)`, `HStack/VStack spacing:`,
    /// frame insets, etc. Avoid inline literals — pick the closest token.
    enum Spacing {
        /// 2pt — hairline gap (between glyph + label)
        static let xxs:  CGFloat = 2
        /// 4pt — tight gap (icon-and-text inside a chip)
        static let xs:   CGFloat = 4
        /// 8pt — default tile inner padding
        static let s:    CGFloat = 8
        /// 12pt — between tiles in a row
        static let m:    CGFloat = 12
        /// 16pt — between major sections, screen edge padding
        static let l:    CGFloat = 16
        /// 24pt — between hero blocks
        static let xl:   CGFloat = 24
        /// 32pt — major vertical rhythm anchor
        static let xxl:  CGFloat = 32
        /// 48pt — top-of-screen breathing room
        static let xxxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    /// Discrete corner-radius scale. The eyeballed-magic-numbers
    /// (4/6/10/14) from the original views collapse to four steps here;
    /// pick the closest. Reviewers should push back on any new sizes.
    enum Radius {
        /// 6pt — small pill chip (HUD region label)
        static let xs: CGFloat = 6
        /// 8pt — HUD gauges, secondary chips
        static let s:  CGFloat = 8
        /// 12pt — most tiles & buttons
        static let m:  CGFloat = 12
        /// 16pt — primary cards (mode buttons, character preview)
        static let l:  CGFloat = 16
        /// 20pt — full-screen overlay panels (mission result)
        static let xl: CGFloat = 20
    }

    // MARK: - Elevation

    /// Reusable shadow recipes. Use via the `.elevation(_:)` view modifier.
    enum Elevation {
        struct Shadow {
            let color: SwiftUI.Color
            let radius: CGFloat
            let xOffset: CGFloat
            let yOffset: CGFloat
        }

        /// Resting elevation (idle tiles, region chip).
        static let card     = Shadow(color: .black.opacity(0.15), radius: 4, xOffset: 0, yOffset: 2)
        /// Pressed-or-selected elevation (active tile, ready button).
        static let cardHigh = Shadow(color: .black.opacity(0.25), radius: 8, xOffset: 0, yOffset: 4)
        /// Action button (boost/item thumb buttons, FLY!).
        static let button   = Shadow(color: .black.opacity(0.30), radius: 6, xOffset: 0, yOffset: 3)
    }

    // MARK: - Typography

    /// Centralised font scale. Sized in points; the view chooses a token
    /// rather than `.system(size: 18, weight: .bold, design: .rounded)`.
    /// All semantic display fonts are rounded to match the chibi 2D art.
    enum Typography {
        /// 42pt — app title on Home.
        static let displayLarge   = Font.system(size: 42, weight: .bold,    design: .rounded)
        /// 28pt — celebration text in the Mission result overlay.
        static let displayMedium  = Font.system(size: 28, weight: .bold,    design: .rounded)
        /// 24pt — secondary heading (e.g. failure reason).
        static let titleLarge     = Font.system(size: 24, weight: .bold,    design: .rounded)
        /// 22pt — character/vehicle name on the selection hero.
        static let title          = Font.system(size: 22, weight: .bold,    design: .rounded)
        /// 18pt — section headers, screen titles inside flows.
        static let titleSmall     = Font.system(size: 18, weight: .bold,    design: .rounded)
        /// 16pt — primary CTA, mode-button label.
        static let button         = Font.system(size: 16, weight: .heavy,   design: .rounded)
        /// 14pt — subtitle text under sections.
        static let bodyLarge      = Font.system(size: 14, weight: .medium)
        /// 13pt — section labels (Map / Vehicle / Sensitivity).
        static let label          = Font.system(size: 13, weight: .semibold)
        /// 12pt — caption text under stats.
        static let caption        = Font.system(size: 12, weight: .medium)
        /// 11pt — small label (sensitivity tier name).
        static let labelSmall     = Font.system(size: 11, weight: .bold,    design: .rounded)
        /// 10pt — tile labels (character name in grid tile).
        static let tileLabel      = Font.system(size: 10, weight: .semibold, design: .rounded)
        /// 9pt — micro-label (HUD gauge unit).
        static let microLabel     = Font.system(size: 9,  weight: .medium,  design: .monospaced)

        // HUD-specific monospace tokens — preserve numeric column alignment.
        static let hudGauge       = Font.system(size: 22, weight: .bold,    design: .monospaced)
        static let hudGaugeSmall  = Font.system(size: 14, weight: .bold,    design: .monospaced)
        static let hudTimer       = Font.system(size: 12, weight: .medium,  design: .monospaced)
        static let hudCompass     = Font.system(size: 14, weight: .bold,    design: .monospaced)
    }
}

// MARK: - Elevation modifier

extension View {
    /// Apply one of the named elevation recipes. All four shadow params
    /// travel together so a future retune (e.g. flatter shadows) is a
    /// single-source-of-truth change.
    func elevation(_ shadow: Theme.Elevation.Shadow) -> some View {
        self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.xOffset,
            y: shadow.yOffset
        )
    }
}
