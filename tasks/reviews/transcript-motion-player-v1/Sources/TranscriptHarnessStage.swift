import SwiftUI

struct TranscriptHarnessStage: View {
    let snapshot: TranscriptPlaybackSnapshot
    let elapsedSeconds: Double

    var body: some View {
        ZStack {
            Color(red: 0.055, green: 0.05, blue: 0.047)

            RoundedRectangle(cornerRadius: 112, style: .continuous)
                .fill(Color(red: 0.10, green: 0.18, blue: 0.15))
                .overlay {
                    RoundedRectangle(cornerRadius: 112, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
                .frame(width: 354, height: 638)
                .position(x: 201, y: 475)

            targetWell
            sourceDeck
            movingCard
            diagnostics
        }
        .frame(width: 402, height: 874)
        .clipped()
    }

    private var sourceDeck: some View {
        VStack(spacing: 5) {
            Text("SOURCE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.90, green: 0.66, blue: 0.42))
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.17, green: 0.09, blue: 0.075))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(red: 0.76, green: 0.58, blue: 0.33).opacity(0.6), lineWidth: 1)
                }
                .frame(width: 74, height: 106)
        }
        .position(x: 84, y: 166)
    }

    private var targetWell: some View {
        VStack(spacing: 5) {
            Text("REST")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.42, green: 0.82, blue: 0.63))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.22))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
                .frame(width: 98, height: 132)
        }
        .position(x: 319, y: 704)
    }

    private var movingCard: some View {
        let sample = snapshot.sample
        let x = 48 + sample.position.x * 300
        let y = 92 + sample.position.y * 724
        let scale = 1 + sample.depth * 0.075
        return RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.34, green: 0.12, blue: 0.10),
                        Color(red: 0.16, green: 0.055, blue: 0.05),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(red: 0.83, green: 0.67, blue: 0.40), lineWidth: 1.2)
            }
            .overlay {
                Text("W2")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(Color(red: 0.90, green: 0.78, blue: 0.56))
            }
            .frame(width: 74, height: 106)
            .rotationEffect(.degrees(sample.rotationDegrees))
            .scaleEffect(scale)
            .shadow(
                color: Color.black.opacity(sample.shadow.opacity),
                radius: sample.shadow.blurRadius,
                x: sample.shadow.offset.x,
                y: sample.shadow.offset.y
            )
            .position(x: x, y: y)
    }

    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("TRANSCRIPT PLAYER · V1")
                Spacer()
                Text(String(format: "%0.3f s", elapsedSeconds))
            }
            HStack(spacing: 12) {
                label("PHASE", snapshot.phase.rawValue.uppercased())
                label("MOVE", snapshot.isMoving ? "1" : "0")
                label("CONTACT", snapshot.contactDelivered ? "1" : "0")
                label("REST", snapshot.restDelivered ? "1" : "0")
            }
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(Color.white.opacity(0.86))
        .padding(14)
        .frame(width: 370)
        .background(Color.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 12))
        .position(x: 201, y: 60)
    }

    private func label(_ name: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(name).foregroundStyle(Color.white.opacity(0.48))
            Text(value)
        }
    }
}
