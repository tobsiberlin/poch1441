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
    float2 srcp = float2(position.x + curl, position.y + lift);
    half4 c = layer.sample(srcp);
    // Gebogener Karton im Licht: gehobene Ecken fangen Licht, die flache
    // Mulde dazwischen liegt tiefer - das Licht erzählt die Krümmung
    float shade = 1.0 + 0.065 * bow * topness - 0.028 * (1.0 - bow) * topness;
    c.rgb *= half3(half(shade));

    // Kantenphysik im QUELL-Raum (SDF der ungewölbten Kartenform - die
    // Effekte wandern dadurch exakt mit der Wölbung mit). Geometrie ist an
    // CardFace gekoppelt: amp = 2.4*scale, pad = 3*scale, Eckradius = 8*scale.
    float sc = amp / 2.4;
    float rad = 8.0 * sc;
    float2 q = abs(srcp - size * 0.5) - (size * 0.5 - 3.0 * sc - rad);
    float d = length(max(q, float2(0.0))) + min(max(q.x, q.y), 0.0) - rad;

    // 1) Kartonstärke: an der Schnittkante schimmert die dunkle
    //    (schwarz-goldene) Rückseite minimal durch - feiner dunkler Saum
    float rim = smoothstep(-0.9 * sc, 0.1 * sc, d);
    c.rgb = mix(c.rgb, half3(0.10, 0.082, 0.058) * c.a, half(0.42 * rim));

    // 2) Lichtbrechung auf der Oberkante: hauchfeines 1px-Highlight direkt
    //    innerhalb des Saums, nur auf lichtzugewandten (oberen) Kanten
    float band = smoothstep(-2.0 * sc, -1.0 * sc, d) * (1.0 - smoothstep(-1.0 * sc, -0.2 * sc, d));
    float topEdge = (q.y > q.x) ? clamp(-sign(srcp.y - size.y * 0.5), 0.0, 1.0) : 0.0;
    c.rgb *= half(1.0 + 0.09 * band * topEdge);
    return c;
}
