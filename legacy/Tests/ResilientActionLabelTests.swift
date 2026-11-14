import Foundation

@main
struct ResilientActionLabelTests {
    static func main() {
        regularPolicyAllowsTwoLinesBeforeScaling()
        compactLandscapePreservesTapTargetAndTextCapacity()
        accessibilityPolicyProtectsLongTextFromItsIcon()
        iconlessLabelsDoNotReserveIconWidth()
        sourceKeepsRequiredSwiftUILayoutFallbacks()
        FileHandle.standardOutput.write(Data("ResilientActionLabelTests: PASS\n".utf8))
    }

    private static func regularPolicyAllowsTwoLinesBeforeScaling() {
        let metrics = ResilientActionLabelPolicy.metrics(
            hasIcon: true,
            usesAccessibilitySizes: false,
            isCompactLandscape: false
        )

        expect(metrics.maximumLineCount == 2,
               "Action labels must allow a second line before shrinking text")
        expect(metrics.minimumScaleFactor >= 0.85,
               "Scale reduction must remain a last reserve, not primary layout")
        expect(metrics.minimumTargetHeight == 44,
               "Every action label must retain the platform minimum target")
        expect(!metrics.prefersStackedIcon,
               "Regular sizes should first try the compact inline composition")
    }

    private static func compactLandscapePreservesTapTargetAndTextCapacity() {
        let regular = ResilientActionLabelPolicy.metrics(
            hasIcon: true,
            usesAccessibilitySizes: false,
            isCompactLandscape: false
        )
        let landscape = ResilientActionLabelPolicy.metrics(
            hasIcon: true,
            usesAccessibilitySizes: false,
            isCompactLandscape: true
        )

        expect(landscape.horizontalPadding < regular.horizontalPadding,
               "Compact landscape may recover width from decorative padding")
        expect(landscape.iconSpacing < regular.iconSpacing,
               "Compact landscape may tighten icon spacing")
        expect(landscape.minimumTargetHeight == regular.minimumTargetHeight,
               "Compact landscape must not reduce the tap target")
        expect(landscape.maximumLineCount == regular.maximumLineCount,
               "Compact landscape must not truncate the second text line")
        expect(landscape.minimumScaleFactor == regular.minimumScaleFactor,
               "Compact landscape must not solve width pressure by smaller type")
    }

    private static func accessibilityPolicyProtectsLongTextFromItsIcon() {
        let regular = ResilientActionLabelPolicy.metrics(
            hasIcon: true,
            usesAccessibilitySizes: false,
            isCompactLandscape: false
        )
        let accessibility = ResilientActionLabelPolicy.metrics(
            hasIcon: true,
            usesAccessibilitySizes: true,
            isCompactLandscape: false
        )

        expect(accessibility.prefersStackedIcon,
               "Accessibility sizes must move the optional icon above text")
        expect(accessibility.minimumInlineTextWidth > regular.minimumInlineTextWidth,
               "Accessibility policy must reserve more text width")
        expect(accessibility.minimumScaleFactor > regular.minimumScaleFactor,
               "Accessibility type must resist downscaling more strongly")
        expect(accessibility.maximumLineCount == 2,
               "AX XXXL labels must still have a defined two-line bound")
    }

    private static func iconlessLabelsDoNotReserveIconWidth() {
        let metrics = ResilientActionLabelPolicy.metrics(
            hasIcon: false,
            usesAccessibilitySizes: true,
            isCompactLandscape: true
        )

        expect(metrics.minimumInlineTextWidth == 0,
               "An absent icon must not consume text width")
        expect(!metrics.prefersStackedIcon,
               "An absent icon must not trigger stacked icon layout")
        expect(metrics.minimumTargetHeight >= 44,
               "Iconless actions need the same minimum hit target")
    }

    private static func sourceKeepsRequiredSwiftUILayoutFallbacks() {
        let sourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("App/ResilientActionLabel.swift")
        guard let source = try? String(contentsOf: sourceURL, encoding: .utf8) else {
            fail("Unable to read ResilientActionLabel.swift")
        }

        expect(source.contains("ViewThatFits(in: .horizontal)"),
               "The label must choose a fitting composition before scaling")
        expect(source.contains(".layoutPriority(1)"),
               "Inline text must outrank its fixed-size icon")
        expect(source.contains(".fixedSize()") && source.contains(".accessibilityHidden(true)"),
               "The optional icon must neither compress nor duplicate its text label")
        expect(source.contains("@ScaledMetric(relativeTo: .body)"),
               "The minimum action height must grow with Dynamic Type")
        expect(source.contains("dynamicTypeSize.isAccessibilitySize"),
               "Accessibility Dynamic Type must select its dedicated policy")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fail(message) }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("ResilientActionLabelTests: \(message)\n".utf8))
        Foundation.exit(EXIT_FAILURE)
    }
}
