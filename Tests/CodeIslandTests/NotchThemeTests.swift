import XCTest
import SwiftUI
@testable import CodeIsland

final class NotchThemeTests: XCTestCase {

    func testAllThemeIDsResolveCorrectly() {
        for themeID in NotchThemeID.allCases {
            let resolved = NotchThemeID.resolve(themeID.rawValue)
            XCTAssertEqual(resolved, themeID)
        }
        // Unknown raw values must fall back to .classic
        XCTAssertEqual(NotchThemeID.resolve(""), .classic)
        XCTAssertEqual(NotchThemeID.resolve("non_existent_theme"), .classic)
    }

    func testClassicThemePreservesOriginalTokens() {
        let classic = NotchTheme.classic

        // Surface must be solid black
        XCTAssertEqual(classic.surface, .solid(.black))
        XCTAssertNil(classic.border)
        XCTAssertEqual(classic.divider, .dashed(opacity: 0.15))
        XCTAssertEqual(classic.cornerScale, 1.0)
        XCTAssertEqual(classic.card.fill, .white.opacity(0.05))
        XCTAssertEqual(classic.card.hoverFill, .white.opacity(0.10))

        // WCAG verified palette values
        XCTAssertEqual(classic.palette.allowFill, Color(red: 0.16, green: 0.50, blue: 0.24))
        XCTAssertEqual(classic.palette.allowFillHover, Color(red: 0.17, green: 0.53, blue: 0.26))
        XCTAssertEqual(classic.palette.deny, Color(red: 0.92, green: 0.38, blue: 0.38))
        XCTAssertEqual(classic.palette.link, Color(red: 0.45, green: 0.72, blue: 1.0))
        XCTAssertEqual(classic.palette.permission, Color(red: 1.0, green: 0.6, blue: 0.2))
    }

    func testAccessibilityReduceTransparencyReplacesBlurWithSolid() {
        let glass = NotchTheme.glass
        let adjusted = glass.adjusted(
            reduceTransparency: true,
            increaseContrast: false,
            reduceMotion: false
        )

        switch adjusted.surface {
        case .solid(let color):
            XCTAssertNotNil(color)
        default:
            XCTFail("Reduce transparency must convert material surface to solid")
        }
    }

    func testAccessibilityIncreaseContrastAddsStrongBorders() {
        let classic = NotchTheme.classic
        let adjusted = classic.adjusted(
            reduceTransparency: false,
            increaseContrast: true,
            reduceMotion: false
        )

        XCTAssertNotNil(adjusted.border, "Increase contrast must add a visible border")
        XCTAssertGreaterThanOrEqual(adjusted.card.borderWidth, 1.0)
    }

    func testAllThemesHaveLocalizationStrings() {
        let supportedLanguages = ["en", "de", "zh", "zh-Hant", "ja", "ko", "tr"]

        for lang in supportedLanguages {
            guard let dict = L10n.strings[lang] else {
                XCTFail("Missing language dictionary for \(lang)")
                continue
            }

            XCTAssertNotNil(dict["notch_theme"], "Missing notch_theme key in \(lang)")
            XCTAssertNotNil(dict["notch_theme_desc"], "Missing notch_theme_desc key in \(lang)")

            for themeID in NotchThemeID.allCases {
                let titleKey = "theme_\(themeID.rawValue)"
                let descKey = "theme_\(themeID.rawValue)_desc"

                XCTAssertNotNil(dict[titleKey], "Missing \(titleKey) in \(lang)")
                XCTAssertNotNil(dict[descKey], "Missing \(descKey) in \(lang)")
            }
        }
    }
}

