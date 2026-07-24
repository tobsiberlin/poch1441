import Foundation

@main
struct ImpactFlightContractTests {
    private static let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    static func main() throws {
        let source = try String(
            contentsOf: root.appendingPathComponent("App/ImpactFlight.swift"),
            encoding: .utf8
        )
        let flight = try section(
            in: source,
            from: "struct ImpactFlight<Content: View>: View",
            through: "private struct FlightPathEffect: GeometryEffect"
        )

        expect(flight.contains("onCancel: (() -> Void)? = nil"),
               "Cancellation must remain opt-in and source-compatible")
        expect(flight.contains("active = true"),
               "A zero-duration flight must become active before its completion can run")
        expect(flight.contains(".onDisappear {\n                cancelOnce()"),
               "Disappearing flights must enter the cancellation gate")

        let impact = try section(
            in: flight,
            from: "private func impactOnce()",
            through: "private func cancelOnce()"
        )
        expect(impact.contains("guard active, !impacted, !cancelled"),
               "Impact must reject inactive, duplicate, and cancelled completions")
        expect(precedes("impacted = true", "onImpact()", in: impact),
               "Impact must become terminal before invoking caller code")

        let cancellation = try section(
            in: flight,
            from: "private func cancelOnce()",
            through: "\n}\n\nprivate struct FlightPathEffect"
        )
        expect(cancellation.contains("guard let onCancel,"),
               "Legacy callers without a cancellation callback must retain prior behavior")
        expect(cancellation.contains("active,"),
               "Only an active flight may cancel")
        expect(cancellation.contains("!impacted,"),
               "A contacted flight must never cancel")
        expect(cancellation.contains("!cancelled else"),
               "Cancellation must be exactly once")
        expect(precedes("cancelled = true", "onCancel()", in: cancellation),
               "Cancellation must become terminal before invoking caller code")

        FileHandle.standardOutput.write(Data("ImpactFlightContractTests: PASS\n".utf8))
    }

    private static func section(
        in source: String,
        from startMarker: String,
        through endMarker: String
    ) throws -> String {
        guard let start = source.range(of: startMarker)?.lowerBound,
              let end = source.range(
                of: endMarker,
                range: start..<source.endIndex
              )?.upperBound else {
            fail("Unable to locate source section \(startMarker)")
        }
        return String(source[start..<end])
    }

    private static func precedes(_ first: String, _ second: String, in source: String) -> Bool {
        guard let firstRange = source.range(of: first),
              let secondRange = source.range(of: second) else { return false }
        return firstRange.lowerBound < secondRange.lowerBound
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) {
        guard condition() else { fail(message) }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("ImpactFlightContractTests: \(message)\n".utf8))
        Foundation.exit(EXIT_FAILURE)
    }
}
