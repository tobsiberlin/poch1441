/// Charakter-Tells (Präsentation, Phase 2) - beweisbar hand-unabhängig (Bluff-Integrität,
/// eiserne Regel, Spec §6b). Die Signatur von `TellGenerator.tell` bekommt AUSSCHLIESSLICH
/// öffentlichen Zustand + Profil + RNG - niemals die Karten. Damit ist es strukturell (zur
/// Compile-Zeit) unmöglich, einen Tell aus der echten Handstärke abzuleiten. Ein Test sichert
/// die Determinismus-Garantie zusätzlich ab.
public struct Tell: Equatable, Sendable {
    public enum Gesture: String, Equatable, Sendable, CaseIterable {
        case leanIn     // selbstsicher nach vorn
        case hesitate   // zögern
        case tapTable   // Tischklopfen
        case sitBack    // resigniert zurücklehnen
        case glance     // kurzer Blick
    }
    public let gesture: Gesture
    /// Denkpause in Sekunden (reine Präsentation, nie Regelwirkung).
    public let thinkSeconds: Double

    public init(gesture: Gesture, thinkSeconds: Double) {
        self.gesture = gesture
        self.thinkSeconds = thinkSeconds
    }
}

public enum TellGenerator {
    /// Der öffentliche Zustand, den ein Tell sehen DARF. Enthält bewusst KEINE Hand/Karten -
    /// so kann selbst ein künftiger Aufrufer keine verdeckte Info in den Tell schleusen.
    public struct PublicContext: Equatable, Sendable {
        public let currentBet: Int
        public let raiseHappened: Bool
        public let potChips: Int
        public init(currentBet: Int, raiseHappened: Bool, potChips: Int) {
            self.currentBet = currentBet
            self.raiseHappened = raiseHappened
            self.potChips = potChips
        }
    }

    /// Erzeugt einen Tell rein aus Profil + öffentlichem Kontext + Rauschen.
    /// Kein Parameter kann verdeckte Karten transportieren - das IST die Bluff-Garantie.
    public static func tell(profile: BotProfile, context: PublicContext,
                            rng: inout SeededRNG) -> Tell {
        let think = BotBrain.thinkSeconds(profile: profile, rng: &rng)
        let roll = rng.nextDouble01()
        let gesture: Tell.Gesture
        if context.raiseHappened {
            // Reaktion auf eine ÖFFENTLICHE Erhöhung - Persönlichkeit + Rauschen, nie die Hand.
            gesture = roll < 0.5 + 0.3 * profile.openAggression
                ? (profile.bluffFrequency > 0.3 ? .leanIn : .hesitate)
                : .sitBack
        } else if roll < 0.22 {
            gesture = .tapTable
        } else if roll < 0.5 {
            gesture = .glance
        } else {
            gesture = .leanIn
        }
        return Tell(gesture: gesture, thinkSeconds: think)
    }
}
