import SwiftUI

struct ResilientActionLabelMetrics: Equatable, Sendable {
    let maximumLineCount: Int
    let minimumScaleFactor: Double
    let minimumTargetHeight: Double
    let horizontalPadding: Double
    let iconSpacing: Double
    let minimumInlineTextWidth: Double
    let prefersStackedIcon: Bool
}

/// Pure layout policy shared by previews, tests and the SwiftUI label.
enum ResilientActionLabelPolicy {
    static let maximumLineCount = 2
    static let minimumTargetHeight = 44.0

    static func metrics(
        hasIcon: Bool,
        usesAccessibilitySizes: Bool,
        isCompactLandscape: Bool
    ) -> ResilientActionLabelMetrics {
        let horizontalPadding = isCompactLandscape
            ? CompactLandscape.horizontalPadding
            : Regular.horizontalPadding
        let iconSpacing = isCompactLandscape
            ? CompactLandscape.iconSpacing
            : Regular.iconSpacing
        let minimumScaleFactor = usesAccessibilitySizes
            ? Accessibility.minimumScaleFactor
            : Regular.minimumScaleFactor
        let minimumInlineTextWidth = usesAccessibilitySizes
            ? Accessibility.minimumInlineTextWidth
            : Regular.minimumInlineTextWidth

        return ResilientActionLabelMetrics(
            maximumLineCount: maximumLineCount,
            minimumScaleFactor: minimumScaleFactor,
            minimumTargetHeight: minimumTargetHeight,
            horizontalPadding: horizontalPadding,
            iconSpacing: iconSpacing,
            minimumInlineTextWidth: hasIcon ? minimumInlineTextWidth : 0,
            prefersStackedIcon: hasIcon && usesAccessibilitySizes
        )
    }

    private enum Regular {
        static let horizontalPadding = 14.0
        static let iconSpacing = 8.0
        static let minimumScaleFactor = 0.86
        static let minimumInlineTextWidth = 104.0
    }

    private enum CompactLandscape {
        static let horizontalPadding = 10.0
        static let iconSpacing = 6.0
    }

    private enum Accessibility {
        static let minimumScaleFactor = 0.94
        static let minimumInlineTextWidth = 148.0
    }
}

/// A resilient label for primary and secondary actions. It inherits foreground style
/// and button style from its caller, while owning text wrapping and hit-target geometry.
struct ResilientActionLabel: View {
    let title: String
    let systemImage: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @ScaledMetric(relativeTo: .body) private var scaledMinimumTargetHeight =
        ResilientActionLabelPolicy.minimumTargetHeight

    init(_ title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }

    private var metrics: ResilientActionLabelMetrics {
        ResilientActionLabelPolicy.metrics(
            hasIcon: systemImage != nil,
            usesAccessibilitySizes: dynamicTypeSize.isAccessibilitySize,
            isCompactLandscape: verticalSizeClass == .compact
        )
    }

    var body: some View {
        content
            .padding(.horizontal, metrics.horizontalPadding)
            .frame(maxWidth: .infinity, minHeight: scaledMinimumTargetHeight)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var content: some View {
        if let systemImage {
            if metrics.prefersStackedIcon {
                stackedLabel(systemImage: systemImage)
            } else {
                ViewThatFits(in: .horizontal) {
                    inlineLabel(systemImage: systemImage, lineLimit: 1, fixedTextWidth: true)
                    inlineLabel(
                        systemImage: systemImage,
                        lineLimit: metrics.maximumLineCount,
                        fixedTextWidth: false
                    )
                    stackedLabel(systemImage: systemImage)
                }
            }
        } else {
            ViewThatFits(in: .horizontal) {
                actionText(lineLimit: 1)
                    .fixedSize(horizontal: true, vertical: true)
                actionText(lineLimit: metrics.maximumLineCount)
            }
        }
    }

    private func inlineLabel(
        systemImage: String,
        lineLimit: Int,
        fixedTextWidth: Bool
    ) -> some View {
        HStack(spacing: metrics.iconSpacing) {
            actionIcon(systemImage: systemImage)
            actionText(lineLimit: lineLimit)
                .frame(minWidth: metrics.minimumInlineTextWidth)
                .fixedSize(horizontal: fixedTextWidth, vertical: true)
                .layoutPriority(1)
        }
    }

    private func stackedLabel(systemImage: String) -> some View {
        VStack(spacing: metrics.iconSpacing) {
            actionIcon(systemImage: systemImage)
            actionText(lineLimit: metrics.maximumLineCount)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func actionIcon(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.body.weight(.semibold))
            .imageScale(.medium)
            .fixedSize()
            .accessibilityHidden(true)
    }

    private func actionText(lineLimit: Int) -> some View {
        Text(title)
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .lineLimit(lineLimit)
            .minimumScaleFactor(metrics.minimumScaleFactor)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Convenience wrapper that preserves the environment's `ButtonStyle` and tint.
struct ResilientActionButton: View {
    let title: String
    let systemImage: String?
    let role: ButtonRole?
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            ResilientActionLabel(title, systemImage: systemImage)
        }
    }
}
