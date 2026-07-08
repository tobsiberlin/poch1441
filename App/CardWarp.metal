#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Physische Karton-Wölbung für Kartenvorderseiten (Feinschliff 8.7.2026):
// die oberen Ecken rollen subtil nach oben, das Licht folgt der gebogenen
// Fläche. Läuft als SwiftUI layerEffect - die Wölbung ist Render-Eigenschaft,
// nie ins Asset gebacken (Lesbarkeits-Licht-Regel, Projekt-CLAUDE.md §5).
//
// amp   = maximaler Eckenhub in Punkten (skaliert mit der Kartengröße)
// phase = deterministischer Karten-Seed - leichte Asymmetrie, damit der
//         Fächer nicht geklont wirkt
[[ stitchable ]] half4 cardWarp(float2 position, SwiftUI::Layer layer,
                                float2 size, float amp, float phase) {
    float2 uv = position / size;
    // Bogen: 0 in der Kartenmitte, 1 an den Seitenkanten, leicht asymmetrisch
    float xo = (uv.x - 0.5) * 2.0 - 0.12 * sin(phase);
    float bow = clamp(xo * xo, 0.0, 1.0);
    // Wölbung greift an der Oberkante und läuft nach unten aus
    float topness = pow(clamp(1.0 - uv.y, 0.0, 1.0), 1.7);
    float lift = amp * bow * topness;
    // Einroll-Zug: die hochgerollten Ecken ziehen die Seitenkanten leicht
    // nach innen - auch die Silhouette der Seiten wird dadurch gekrümmt
    float curl = 0.35 * amp * sign(xo) * bow * topness;
    half4 c = layer.sample(float2(position.x + curl, position.y + lift));
    // Gebogener Karton im Licht: gehobene Ecken fangen Licht, die flache
    // Mulde dazwischen liegt tiefer - das Licht erzählt die Krümmung
    float shade = 1.0 + 0.065 * bow * topness - 0.028 * (1.0 - bow) * topness;
    c.rgb *= half3(half(shade));
    return c;
}
