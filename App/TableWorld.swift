import CoreGraphics
import Foundation
import PochKit

/// Die zwei kanonischen, regelidentischen Spieltische.
///
/// Die Tischwelt steuert ausschließlich Darstellung und physisches Feedback. Regeln,
/// Einsätze und verdeckte Information bleiben vollständig außerhalb dieses Typs.
enum TableWorld: String, CaseIterable, Identifiable, Sendable {
    case pochDisc = "poch-disc"
    case unterwegs = "unterwegs"

    static let storageKey = "tableWorld"

    var id: String { rawValue }

    var pieceMaterial: TablePieceMaterial {
        switch self {
        case .pochDisc: .r1Ceramic
        case .unterwegs: .oneCentCopper
        }
    }

    static func resolve(_ storedValue: String) -> TableWorld {
        TableWorld(rawValue: storedValue) ?? .pochDisc
    }
}

enum TablePieceMaterial: String, Sendable {
    case r1Ceramic = "r1-ceramic"
    case oneCentCopper = "one-cent-copper"
}

extension TravelCompartment {
    init(pool: Pool) {
        switch pool {
        case .king: self = .king
        case .queen: self = .queen
        case .mariage: self = .mariage
        case .jack: self = .jack
        case .ten: self = .ten
        case .sequence: self = .sequence
        case .poch: self = .poch
        case .ace: self = .ace
        case .center: self = .center
        }
    }
}

enum TableWorldBoardGeometry {
    static func wellCenter(for pool: Pool,
                           in size: CGFloat,
                           world: TableWorld) -> CGPoint {
        guard world == .unterwegs else {
            return PM49Geometry.wellCenter(for: pool, in: size)
        }
        let point = TravelTableGeometry.center(for: TravelCompartment(pool: pool))
        return CGPoint(x: size * point.x, y: size * point.y)
    }

    static func notationCenter(for pool: Pool,
                               in size: CGFloat,
                               world: TableWorld) -> CGPoint {
        guard world == .unterwegs else {
            return PM49Geometry.notationCenter(for: pool, in: size)
        }
        let well = wellCenter(for: pool, in: size, world: world)
        let x = size * 0.5 + (well.x - size * 0.5) * 1.16
        let y = size * 0.5 + (well.y - size * 0.5) * 1.16
        return CGPoint(x: min(max(x, size * 0.08), size * 0.92),
                       y: min(max(y, size * 0.08), size * 0.92))
    }
}
