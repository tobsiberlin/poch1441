import SwiftUI
import UIKit

/// A reversible first contact with Poch's history. The gesture changes only
/// presentation and never mutates tutorial, game or persistence state.
struct FirstRunTimeSwipeOpening: View {
    let soundEnabled: Bool
    let hapticsEnabled: Bool
    let reduceMotion: Bool
    let onTakeSeat: () -> Void
    let onPlayWithoutGuide: () -> Void

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var hasEnteredTimeline = false
    @State private var interactiveTranslation: CGFloat = 0
    @State private var settledProgress = 0.0
    @State private var selectionFeedbackTick = 0
    @State private var settleTask: Task<Void, Never>?
    @State private var audioDirector = FirstRunTimeSwipeAudio()

    private var usesDiscretePresentation: Bool {
        reduceMotion || voiceOverEnabled || dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        GeometryReader { proxy in
            if hasEnteredTimeline {
                if usesDiscretePresentation {
                    discreteLayout(size: proxy.size,
                                   safeArea: proxy.safeAreaInsets)
                        .transition(.opacity)
                } else {
                    cinematicLayout(size: proxy.size,
                                    safeArea: proxy.safeAreaInsets)
                        .transition(.opacity)
                }
            } else {
                preludeLayout(size: proxy.size,
                              safeArea: proxy.safeAreaInsets)
                    .transition(.opacity)
            }
        }
        .background(Color(hex: 0x0D0C0B).ignoresSafeArea())
        .sensoryFeedback(trigger: selectionFeedbackTick) { previous, current in
            guard hapticsEnabled, previous != current else { return nil }
            return .selection
        }
        .onAppear {
            if applyDebugProgressOverride() {
                hasEnteredTimeline = true
                audioDirector.startIfEnabled(soundEnabled,
                                             progress: settledProgress)
            }
        }
        .onChange(of: soundEnabled) { _, enabled in
            if enabled, hasEnteredTimeline {
                audioDirector.startIfEnabled(true,
                                             progress: settledProgress)
            } else {
                audioDirector.stop()
            }
        }
        .onChange(of: usesDiscretePresentation) { _, isDiscrete in
            guard isDiscrete else { return }
            settleTask?.cancel()
            interactiveTranslation = 0
            settledProgress = FirstRunTimeSwipeProjection
                .nearestChapter(to: settledProgress).progress
        }
        .onDisappear {
            settleTask?.cancel()
            audioDirector.stop()
        }
    }

    private func preludeLayout(size: CGSize,
                               safeArea: EdgeInsets) -> some View {
        ZStack {
            Image("FirstRunPresentTable")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .offset(y: -size.height * 0.045)

            LinearGradient(colors: [
                Color.black.opacity(0.56),
                Color.clear,
                Color.clear,
                Color.black.opacity(0.94)
            ], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("POCH")
                        .font(.system(size: 21, weight: .heavy))
                    Text("1441")
                        .font(.system(size: 21, weight: .light))
                        .foregroundStyle(Color(hex: 0xD8B466))
                }
                .foregroundStyle(Color(hex: 0xF4F0E8))
                .padding(.top, safeArea.top + 10)

                Spacer()

                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "firstRun.timeSwipe.prelude.eyebrow",
                                defaultValue: "EINE RUNDE, DREI CHANCEN"))
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.9)
                        .foregroundStyle(Color(hex: 0xE5C374))

                    Text(String(localized: "firstRun.timeSwipe.prelude.title",
                                defaultValue: "Ein Tisch. Drei Duelle."))
                        .font(.system(size: 34, weight: .heavy))
                        .tracking(-0.8)
                        .foregroundStyle(Color(hex: 0xF4F0E8))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(String(localized: "firstRun.timeSwipe.prelude.body",
                                defaultValue: "Räum mit Trumpf ab, poch um den Einsatz und werde deine Karten zuerst los."))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xF4F0E8).opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: enterTimeline) {
                        HStack(spacing: 9) {
                            Text(String(localized: "firstRun.timeSwipe.prelude.primary",
                                        defaultValue: "Poch entdecken"))
                            Image(systemName: "arrow.right")
                                .font(.subheadline.weight(.bold))
                        }
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Color(hex: 0x16130D))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Capsule().fill(Color(hex: 0xE0BC69)))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(TimeSwipePressStyle(reduceMotion: reduceMotion))
                    .accessibilityIdentifier("firstRun.timeSwipe.prelude.primary")

                    Button(action: onPlayWithoutGuide) {
                        Text(String(localized: "firstRun.timeSwipe.withoutGuide",
                                    defaultValue: "Ich kenne Poch schon"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xF4F0E8).opacity(0.72))
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("firstRun.timeSwipe.prelude.secondary")
                }
                .padding(.bottom, max(14, safeArea.bottom + 6))
            }
            .padding(.horizontal, 24)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("firstRun.timeSwipe.prelude")
    }

    private func cinematicLayout(size: CGSize,
                                 safeArea: EdgeInsets) -> some View {
        let progress = FirstRunTimeSwipeProjection.progress(
            settledProgress: settledProgress,
            translation: Double(interactiveTranslation),
            width: Double(size.width)
        )
        let chapter = FirstRunTimeSwipeProjection.chapter(for: progress)
        let showsFinalActions = FirstRunTimeSwipeProjection.isFinalEndpoint(progress)

        return ZStack {
            historicalLayer(size: size, progress: progress)

            presentLayer(size: size, progress: progress)

            LinearGradient(colors: [
                Color.black.opacity(0.42),
                Color.clear,
                Color.black.opacity(0.12),
                Color.black.opacity(0.88)
            ], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            timeSeam(size: size, progress: progress)

            Color.clear
                .frame(width: size.width, height: size.height * 0.68)
                .position(x: size.width / 2, y: size.height * 0.34)
                .contentShape(Rectangle())
                .gesture(timeDrag(width: size.width))
                .accessibilityHidden(true)

            header(safeArea: safeArea, showsFinalActions: showsFinalActions)

            VStack {
                Spacer()
                copyPanel(chapter: chapter,
                          progress: progress,
                          showsFinalActions: showsFinalActions)
                    .padding(.horizontal, 20)
                    .padding(.bottom, max(12, safeArea.bottom - 4))
            }

            progressProbe(progress: progress, chapter: chapter)
        }
        .contentShape(Rectangle())
        .onChange(of: progress) { _, value in
            audioDirector.update(progress: value)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("firstRun.timeSwipe.stage")
    }

    private func historicalLayer(size: CGSize,
                                 progress: Double) -> some View {
        Image("FirstRunTimeBridge")
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: size.width, height: size.height * 1.14)
            .offset(y: -size.height * 0.10)
            .saturation(0.82)
            .contrast(1.08)
            .brightness(-0.06)
            .frame(width: size.width, height: size.height)
            .clipped()
            .accessibilityHidden(true)
    }

    private func presentLayer(size: CGSize,
                              progress: Double) -> some View {
        ZStack {
            Image("FirstRunPresentTable")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: size.width, height: size.height * 1.14)
                .offset(y: -size.height * 0.10)
                .saturation(0.92 + progress * 0.08)

        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .mask(alignment: .leading) {
            HStack(spacing: 0) {
                Rectangle()
                    .frame(width: max(0, size.width * CGFloat(progress)))
                Spacer(minLength: 0)
            }
        }
        .accessibilityHidden(true)
    }

    private func timeSeam(size: CGSize,
                          progress: Double) -> some View {
        let x = FirstRunTimeSwipeProjection.handleCenterX(
            progress: progress,
            width: Double(size.width)
        )
        let handleSymbol = FirstRunTimeSwipeProjection
            .handleSymbolName(progress: progress)
        return ZStack {
            Capsule()
                .fill(Color(hex: 0xD8B466).opacity(0.64))
                .frame(width: 2, height: size.height * 0.66)
                .rotationEffect(.degrees(7))

            Image(systemName: handleSymbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: 0xF4EBD7))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color(hex: 0x171512).opacity(0.88))
                        .overlay(Circle().strokeBorder(Color(hex: 0xD8B466).opacity(0.55)))
                )
                .shadow(color: .black.opacity(0.36), radius: 12, y: 6)
        }
        .position(x: CGFloat(x), y: size.height * 0.42)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func header(safeArea: EdgeInsets,
                        showsFinalActions: Bool) -> some View {
        VStack {
            HStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("POCH")
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(Color(hex: 0xF3EFE7))
                    Text("1441")
                        .font(.system(size: 19, weight: .light))
                        .foregroundStyle(Color(hex: 0xD8B466))
                }
                .accessibilityElement(children: .combine)

                Spacer()

                if !showsFinalActions {
                    Button(action: skipToToday) {
                        Text(String(localized: "firstRun.timeSwipe.skip",
                                    defaultValue: "Überspringen"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xF3EFE7).opacity(0.82))
                            .padding(.horizontal, 13)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(Color.black.opacity(0.30)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("firstRun.timeSwipe.skip")
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, safeArea.top + 8)
            Spacer()
        }
    }

    private func copyPanel(chapter: FirstRunTimeChapter,
                           progress: Double,
                           showsFinalActions: Bool) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            timeline(chapter: chapter, progress: progress)

            VStack(alignment: .leading, spacing: 4) {
                Text(copy(for: chapter).eyebrow)
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.8)
                    .foregroundStyle(Color(hex: 0xD8B466))

                Text(copy(for: chapter).title)
                    .font(.system(size: 25, weight: .heavy))
                    .tracking(-0.55)
                    .foregroundStyle(Color(hex: 0xF4F0E8))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("firstRun.timeSwipe.title")

                Text(copy(for: chapter).body)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xF4F0E8).opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("firstRun.timeSwipe.body")
            }

            Spacer(minLength: 0)

            if showsFinalActions {
                seatActions
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "hand.draw")
                    Text(String(localized: "firstRun.timeSwipe.hint",
                                defaultValue: "Streiche nach rechts durch die Zeit"))
                }
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(Color(hex: 0xF4F0E8).opacity(0.82))
                .frame(minHeight: 36)
                .accessibilityHidden(true)
            }
        }
        .padding(14)
        .frame(maxWidth: 390, alignment: .leading)
        .frame(height: 272, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color(hex: 0x12110F).opacity(0.91))
                .overlay(RoundedRectangle(cornerRadius: 26)
                    .strokeBorder(Color.white.opacity(0.10)))
                .shadow(color: .black.opacity(0.44), radius: 24, y: 12)
        )
        .animation(.easeOut(duration: 0.18), value: chapter)
    }

    private func timeline(chapter: FirstRunTimeChapter,
                          progress: Double) -> some View {
        HStack(spacing: 8) {
            timeMarker("1441", active: chapter == .origin)
            timelineLine(fill: min(1, progress / 0.55))
            timeMarker("POQUE", active: chapter == .branch)
            timelineLine(fill: max(0, (progress - 0.55) / 0.45))
            timeMarker(String(localized: "firstRun.timeSwipe.today.eyebrow",
                              defaultValue: "HEUTE"), active: chapter == .today)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "firstRun.timeSwipe.accessibility.timeline",
                                   defaultValue: "Zeitlinie von 1441 über Poque bis heute"))
    }

    private func timeMarker(_ text: String, active: Bool) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy))
            .tracking(1.2)
            .foregroundStyle(active ? Color(hex: 0xE5C374) : Color.white.opacity(0.46))
    }

    private func timelineLine(fill: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.16))
                Capsule()
                    .fill(Color(hex: 0xD8B466))
                    .frame(width: proxy.size.width * CGFloat(min(max(fill, 0), 1)))
            }
        }
        .frame(height: 2)
    }

    private var seatActions: some View {
        VStack(spacing: 4) {
            Button {
                if hapticsEnabled {
                    UIImpactFeedbackGenerator(style: .medium)
                        .impactOccurred(intensity: 0.72)
                }
                onTakeSeat()
            } label: {
                HStack(spacing: 9) {
                    Text(String(localized: "firstRun.timeSwipe.takeSeat",
                                defaultValue: "An den Tisch"))
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.bold))
                }
                .font(.headline.weight(.heavy))
                .foregroundStyle(Color(hex: 0x16130D))
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(Capsule().fill(Color(hex: 0xE0BC69)))
                .contentShape(Capsule())
            }
            .buttonStyle(TimeSwipePressStyle(reduceMotion: reduceMotion))
            .accessibilityIdentifier("firstRun.intro.primary")

            Button(action: onPlayWithoutGuide) {
                Text(String(localized: "firstRun.timeSwipe.withoutGuide",
                            defaultValue: "Ich kenne Poch schon"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xF4F0E8).opacity(0.72))
                    .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("firstRun.intro.secondary")
        }
    }

    private func discreteLayout(size: CGSize,
                                safeArea: EdgeInsets) -> some View {
        let chapter = FirstRunTimeSwipeProjection.chapter(for: settledProgress)
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("POCH")
                        .font(.system(size: 22, weight: .heavy))
                    Text("1441")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(Color(hex: 0xD8B466))
                    Spacer()
                    Button(String(localized: "firstRun.timeSwipe.skip",
                                  defaultValue: "Überspringen"), action: skipToToday)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(minHeight: 44)
                        .opacity(chapter == .today ? 0 : 1)
                        .disabled(chapter == .today)
                        .accessibilityHidden(chapter == .today)
                }
                .foregroundStyle(Color(hex: 0xF4F0E8))
                .padding(.top, safeArea.top + 10)

                discreteImage(chapter: chapter, size: size)

                Picker("", selection: Binding(
                    get: { chapter },
                    set: { settle(on: $0) }
                )) {
                    Text("1441").tag(FirstRunTimeChapter.origin)
                    Text("Poque").tag(FirstRunTimeChapter.branch)
                    Text(String(localized: "firstRun.timeSwipe.today.eyebrow",
                                defaultValue: "Heute"))
                        .tag(FirstRunTimeChapter.today)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(String(localized: "firstRun.timeSwipe.accessibility.timeline",
                                            defaultValue: "Zeitlinie von 1441 über Poque bis heute"))

                VStack(alignment: .leading, spacing: 8) {
                    Text(copy(for: chapter).eyebrow)
                        .font(.caption.weight(.heavy))
                        .tracking(1.8)
                        .foregroundStyle(Color(hex: 0xD8B466))
                    Text(copy(for: chapter).title)
                        .font(.largeTitle.weight(.heavy))
                        .foregroundStyle(Color(hex: 0xF4F0E8))
                        .accessibilityIdentifier("firstRun.timeSwipe.title")
                    Text(copy(for: chapter).body)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(hex: 0xF4F0E8).opacity(0.78))
                        .accessibilityIdentifier("firstRun.timeSwipe.body")
                }

                if chapter == .today {
                    seatActions
                } else {
                    Button {
                        moveChapter(forward: true)
                    } label: {
                        HStack {
                            Text(String(localized: "firstRun.timeSwipe.next",
                                        defaultValue: "Weiter"))
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color(hex: 0x16130D))
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Capsule().fill(Color(hex: 0xE0BC69)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("firstRun.timeSwipe.next")
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, max(24, safeArea.bottom + 12))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("firstRun.timeSwipe.discrete")
        .accessibilityAdjustableAction { direction in
            moveChapter(forward: direction == .increment)
        }
        .overlay { progressProbe(progress: settledProgress, chapter: chapter) }
    }

    private func discreteImage(chapter: FirstRunTimeChapter,
                               size: CGSize) -> some View {
        let imageName = chapter == .today ? "FirstRunPresentTable" : "FirstRunTimeBridge"
        let imageHeight = min(300, max(190, size.height * 0.34))
        return ZStack {
            Image(imageName)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: max(1, size.width - 44),
                       height: imageHeight)

        }
            .frame(width: max(1, size.width - 44), height: imageHeight)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .accessibilityHidden(true)
    }

    private func timeDrag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                settleTask?.cancel()
                interactiveTranslation = value.translation.width
            }
            .onEnded { value in
                let current = FirstRunTimeSwipeProjection.progress(
                    settledProgress: settledProgress,
                    translation: Double(value.translation.width),
                    width: Double(width)
                )
                let remainingProjection = value.predictedEndTranslation.width
                    - value.translation.width
                let target = FirstRunTimeSwipeProjection.target(
                    currentProgress: current,
                    predictedTranslation: Double(remainingProjection),
                    width: Double(width)
                )
                interactiveTranslation = 0
                settledProgress = current
                animateSettle(to: target)
            }
    }

    private func settle(on chapter: FirstRunTimeChapter) {
        guard chapter.progress != settledProgress else { return }
        if usesDiscretePresentation {
            settleTask?.cancel()
            interactiveTranslation = 0
            settledProgress = chapter.progress
            selectionFeedbackTick += 1
        } else {
            animateSettle(to: chapter)
        }
    }

    private func animateSettle(to chapter: FirstRunTimeChapter) {
        settleTask?.cancel()
        let start = settledProgress
        let destination = chapter.progress
        guard start != destination else { return }

        settleTask = Task { @MainActor in
            let frameCount = 24
            for frame in 1...frameCount {
                guard !Task.isCancelled else { return }
                let linear = Double(frame) / Double(frameCount)
                let eased = 1 - pow(1 - linear, 3)
                settledProgress = start + (destination - start) * eased
                try? await Task.sleep(for: .milliseconds(16))
            }
            guard !Task.isCancelled else { return }
            settledProgress = destination
            selectionFeedbackTick += 1
        }
    }

    private func enterTimeline() {
        selectionFeedbackTick += 1
        let transition: Animation = reduceMotion
            ? .linear(duration: 0.12)
            : .easeInOut(duration: 0.36)
        withAnimation(transition) {
            hasEnteredTimeline = true
        }
        audioDirector.startIfEnabled(soundEnabled,
                                     progress: settledProgress)
    }

    private func skipToToday() {
        settle(on: .today)
    }

    private func moveChapter(forward: Bool) {
        let current = FirstRunTimeSwipeProjection.chapter(for: settledProgress)
        let raw = min(max(current.rawValue + (forward ? 1 : -1), 0), 2)
        settle(on: FirstRunTimeChapter(rawValue: raw) ?? current)
    }

    private func copy(for chapter: FirstRunTimeChapter) -> TimeSwipeCopy {
        switch chapter {
        case .origin:
            return TimeSwipeCopy(
                eyebrow: String(localized: "firstRun.timeSwipe.origin.eyebrow",
                                 defaultValue: "1441"),
                title: String(localized: "firstRun.timeSwipe.origin.title",
                              defaultValue: "Pokers älterer Bruder. Seit 1441."),
                body: String(localized: "firstRun.timeSwipe.origin.body",
                             defaultValue: "Drei Phasen, drei Wege zum Gewinn - und eine Spur, die bis ins 15. Jahrhundert führt.")
            )
        case .branch:
            return TimeSwipeCopy(
                eyebrow: String(localized: "firstRun.timeSwipe.branch.eyebrow",
                                 defaultValue: "DIE SPUR ZIEHT WEITER"),
                title: String(localized: "firstRun.timeSwipe.branch.title",
                              defaultValue: "Über Poque führt die Spur weiter."),
                body: String(localized: "firstRun.timeSwipe.branch.body",
                             defaultValue: "Poque gilt als möglicher Vorläufer des Pokers. Poch selbst blieb ein eigenes Spiel.")
            )
        case .today:
            return TimeSwipeCopy(
                eyebrow: String(localized: "firstRun.timeSwipe.today.eyebrow",
                                 defaultValue: "HEUTE"),
                title: String(localized: "firstRun.timeSwipe.today.title",
                              defaultValue: "Drei Chancen. Eine Runde."),
                body: String(localized: "firstRun.timeSwipe.today.body",
                             defaultValue: "Die richtigen Trumpfkarten räumen Bonus-Töpfe ab. Beim Pochen riskierst du Chips. Wer zuerst alle Karten los ist, holt das Finale.")
            )
        }
    }

    private func progressProbe(progress: Double,
                               chapter: FirstRunTimeChapter) -> some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement()
            .accessibilityLabel(String(format: "%.2f:%@", progress,
                                       String(describing: chapter)))
            .accessibilityIdentifier("firstRun.timeSwipe.progress")
            .allowsHitTesting(false)
    }

    @discardableResult
    private func applyDebugProgressOverride() -> Bool {
        #if DEBUG
        let prefix = "-firstRunTimeProgress="
        guard let argument = ProcessInfo.processInfo.arguments.first(where: {
            $0.hasPrefix(prefix)
        }),
        let value = Double(argument.dropFirst(prefix.count)) else { return false }
        settledProgress = FirstRunTimeSwipeProjection.clamped(value)
        return true
        #else
        return false
        #endif
    }
}

private struct TimeSwipeCopy {
    let eyebrow: String
    let title: String
    let body: String
}

private struct TimeSwipePressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
