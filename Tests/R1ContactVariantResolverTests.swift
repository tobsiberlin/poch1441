import Foundation

@main
struct R1ContactVariantResolverTests {
    static func main() {
        avoidsImmediateRepeat()
        mapsStackDensityToRecordedClass()
        staysReplayStable()
        print("R1ContactVariantResolverTests: PASS")
    }

    private static func avoidsImmediateRepeat() {
        var previous: Int?
        for seed in 1_441...1_480 {
            let current = R1ContactVariantResolver.resolve(
                variantCount: 3,
                seed: seed,
                familySalt: 0xA17E_1441,
                previousIndex: previous
            )
            expect(current != previous, "Adjacent contacts must not clone one take")
            previous = current
        }
    }

    private static func mapsStackDensityToRecordedClass() {
        for count in 2...3 {
            let index = R1ContactVariantResolver.resolve(
                variantCount: 3,
                seed: 9,
                familySalt: 0x57AC_1441,
                semanticIndex: min(count - 1, 2),
                previousIndex: nil
            )
            expect(index == count - 1, "A stack transfer must use its density class")
        }
        let crowded = R1ContactVariantResolver.resolve(
            variantCount: 3,
            seed: 9,
            familySalt: 0x57AC_1441,
            semanticIndex: 2,
            previousIndex: nil
        )
        expect(crowded == 2, "Four or more chips must use the dense recording")
    }

    private static func staysReplayStable() {
        let first = R1ContactVariantResolver.resolve(
            variantCount: 3,
            seed: 88,
            familySalt: 0xCE17_1441,
            previousIndex: 1
        )
        let second = R1ContactVariantResolver.resolve(
            variantCount: 3,
            seed: 88,
            familySalt: 0xCE17_1441,
            previousIndex: 1
        )
        expect(first == second, "The same replay context must resolve identically")
    }

    private static func expect(_ condition: @autoclosure () -> Bool,
                               _ message: String) {
        guard condition() else {
            FileHandle.standardError.write(Data("R1ContactVariantResolverTests: \(message)\n".utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }
}
