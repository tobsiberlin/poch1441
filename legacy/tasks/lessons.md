# Lessons - Poch 1441

## 6.7.2026 - Ein datiertes „FINAL/bindend" ist nicht eingefroren, wenn Tobsi neu zeigt

**Beobachtung:** Ich behandelte die 6.7.-Notiz „Design-Richtung FINAL: Premium-Edelholz-Tisch (JREF-N2)" als unumstößlich und stempelte den Mockup pauschal als „Abweichung/Cyber-Neon" ab - dabei wollte Tobsi genau den clean-digitalen Mockup-Look („wollte eigentlich gar kein holztisch"). Ich verteidigte die alte Notiz, statt die neue Richtung zurückzuspielen.

**Regel:** Ein in der CLAUDE.md/Kanon als „FINAL/bindend" markierter Design-Stand ist historisch, nicht sakrosankt. Zeigt Tobsi aktiv eine andere Richtung (Bild, „eigentlich wollte ich..."), sofort auf „Korrektur = Vollstop": neue Richtung wörtlich zurückspielen, Guardrail nur für harte Regel-/Positionierungs-Brüche setzen (All-in, Casino-Marketing), NICHT für den abgelösten Stil-Stand. Dann Canon aktualisieren, nicht die alte Notiz verteidigen.

## 5.7.2026 - Tobsi-Sichtbarkeit im autonomen Loop

**Beobachtung:** Tobsi musste fragen „welches Brett haben wir denn jetzt?" - der Arbeitsstand war über Chat-Iterationen verteilt und für ihn nicht greifbar; Entscheidungsbedarf ging beinahe unter.

**Regel:** `artifacts/status.html` ist das lebende Status-Cockpit: nach jeder Loop-Iteration aktualisieren, offene Tobsi-Entscheidungen IMMER als oberster Block, bei neuem Entscheidungsbedarf die Datei per `open` öffnen. Chat-Zusammenfassungen ersetzen das Cockpit nicht.

## 5.7.2026 - Hintergrund-Kommandos brauchen absolute Pfade

**Beobachtung:** Zwei Fehlschläge durch geerbtes Arbeitsverzeichnis (Generator-Script „No such file", Terms-PDFs in artifacts/-Unterordner gelandet, Commit im /tmp-Ordner).

**Regel:** Jeder Bash-Aufruf mit Datei-Seiteneffekten beginnt mit `cd /Users/tobsi/poch1441` oder nutzt absolute Pfade - besonders `run_in_background`-Kommandos.

## 5.7.2026 - Simulator-Screenshots erst nach dem Launch-Übergang

**Beobachtung:** Screenshot 2s nach Launch fing die weiße Launch-Überblendung ein und sah wie ein Rendering-Totalausfall aus.

**Regel:** Nach `simctl launch` mindestens 4-5s warten (oder zweimal schießen), bevor aus einem Screenshot Schlüsse gezogen werden.

## 5.7.2026 - Cockpit braucht kopierbare Antwort-Prompts

**Beobachtung:** Tobsi kam beim Status-Cockpit nicht mehr mit und wusste nicht, WIE er Entscheidungen zurückmelden soll ("falls ich was entscheiden soll, bitte jeweils kopierbaren prompt einbauen").

**Regel:** Jede offene Entscheidung im Cockpit bekommt 1-2 vorformulierte, kopierbare Antwort-Prompts (Copy-Button) - eine für die Empfehlung, eine als Vorlage für Abweichung. Status-Tabellen müssen den Stand JEDES Artefakt-Typs zeigen (Bretter, Karten-Decks, Porträts getrennt), nicht nur die aktuell heiße Entscheidung.

## 5.7.2026 - String(verbatim:) existiert nicht (2x passiert)

**Beobachtung:** Zweimal am selben Tag `String(verbatim: "...")` geschrieben (Button-/Picker-Label) - das ist kein Swift-API; `verbatim:` gibt es nur bei `Text(verbatim:)`.

**Regel:** Für nicht-lokalisierte Labels in SwiftUI immer `Text(verbatim:)` im label-Closure nutzen, nie `String(verbatim:)` als Titel-Parameter. DEBUG-only-Strings dürfen schlicht als String-Literal stehen.

## 5.7.2026 - Vision-QA nie im 1-Zeilen-Kompaktformat

**Beobachtung:** gemini-vision im "1 Zeile: Ja/Nein/Score"-Format lieferte verrauschte Widersprüche (R1 fälschlich "Schrift: Ja / Score 2", eigenes Auge: sauber) - fand aber echte KI-Signaturen in R6/R10.

**Regel:** Vision-Checks immer im 3-Zeilen-Format (Befund / Schwäche / Scores) UND bei Low-Scores eigener Read-Blick vor Retake-/Freigabe-Entscheidungen. "unsigned, no watermark" gehört in jede Scene-Basis.

## 5.7.2026 - Die cwd-Lesson wurde selbst verletzt (2. Vorfall)

**Beobachtung:** Trotz dokumentierter Regel liefen erneut zwei Kommandos mit relativem Pfad aus einem tiefen Unterordner (Lesson-Append ging ins Leere, Retake-Generierung crashte).

**Regel verschärft:** JEDES Bash-Kommando in diesem Projekt beginnt mit `cd /Users/tobsi/poch1441 &&` - ohne Ausnahme, auch Einzeiler.

## 5.7.2026 - Stil-Referenzen: Anker nutzen statt Prompt-Lotterie

**Beobachtung:** Drei Referenz-Runden in Folge von Tobsi verworfen („schrecklich, nicht authentisch") - jede Runde neue Prompt-Adjektive, aber Porträts/Requisiten drifteten bei FLUX stets in generischen Fantasy-Render.

**Regel:** Sobald ein Stil-Kandidat freigegeben ist, wird NUR noch an ihm geankert (Trainingsset aus der freigegebenen Bild-Familie; problematische Motivtypen wie Porträts raus aus dem Stil-Set und später einzeln mit der LoRA erzeugen). Nach 2 verworfenen Runden desselben Ansatzes: Hebelwechsel präsentieren, nicht Runde 3 generieren.

## 5.7.2026 - Entscheidungs-Überflutung im Loop

**Beobachtung:** Tobsi: „warum hängst du ständig? wo stehen wir? alles verwirrend" - zeitweise 3-4 offene Entscheidungen parallel, Wartephasen des Loops wirkten wie Hänger.

**Regel:** Immer nur EINE aktive Tobsi-Entscheidung; alle weiteren ausdrücklich als „geparkt" führen (Cockpit + Chat). Wenn der Loop auf Tobsi wartet, endet die letzte Chat-Nachricht mit „Ich warte auf: X - solange passiert nichts." Status-Zusammenfassungen: max. 3 Zeilen Fertig/In Arbeit/Geparkt.

## 5.7.2026 - Wachfenster maximal ausnutzen

**Beobachtung:** Tobsi (Caps): „WARUM STOPPST DU IMMER SELBSTÄNDIG?" - kleine Arbeitsblöcke mit Wakeup-Pausen wirkten wie eigenmächtiges Anhalten.

**Regel:** Pro Wachfenster so viele Queue-Punkte wie möglich am Stück abarbeiten; ScheduleWakeup NUR bei echtem externen Warten (Training, Tobsi-Sichtung) mit Delay = erwartete Restzeit. Nie nach einem einzelnen kleinen Block schlafen legen.

## 5.7.2026 - Cockpit: Antworten-zuerst-Struktur + Konsistenz nach Reverts

**Beobachtung:** Tobsi: „ich weiß nie was los ist... viele Fragen gestellt und keine Antworten" - ein git-Revert hatte eine alte Cockpit-Version zurückgeholt, in der seine getroffenen Entscheidungen wieder als offen standen; seine Antworten wirkten ignoriert.

**Regel:** Cockpit-Struktur fix: (1) JETZT GERADE oben, (2) WARTET AUF DICH (oder explizit „nichts"), (3) „Deine Entscheidungen - registriert ✓"-Tabelle, (4) Gesamtbild. Bei jedem Commit die Jetzt-Zeile erneuern. Nach jedem Revert sofort Cockpit-Konsistenz prüfen (Reverts erfassen auch Doku!).

## 5.7.2026 - Entscheidungen gehören in den Chat, nicht (nur) ins HTML

**Beobachtung:** Tobsi wusste erneut nicht, was zu tun ist - Entscheidungsprompts lebten primär im Cockpit-HTML.

**Regel:** Jede Frage/Entscheidung wird direkt im Chat gestellt, mit fertigen Antwortzeilen als Klartext. Cockpit ist Spiegel/Archiv. Jede Loop-Statusmeldung endet mit „Für dich zu tun: X" oder „Für dich zu tun: nichts".

## 5.7.2026 - Externe KI als Pflicht-Filter vor jeder Sichtung

**Beobachtung:** Tobsi musste selbst Slop finden (Ringe statt Münzen, Handwerker-Wirt, Schatten) - der Vision-Check war zu lasch bzw. kam nach ihm.

**Regel:** Kein Bild erreicht Tobsi ohne harte externe Kritik (gemini-vision, Was-ist-falsch-Frage) + selbständige Retakes. Konzepte regelmäßig mit gemini-review/gpt-review sparren. Tobsi sieht gebündelte, bereinigte Meilenstein-Chargen.

## 5.7.2026 - Atom-Prinzip: zusammengesetzte Motive nie als Ganzes generieren

**Beobachtung:** Kartenrücken (3x Ecken-Symbole/Signaturen trotz Verbot) und Münzschalen (Ringe, Schrift, Schatten) scheiterten wiederholt als Komplett-Generierung; "evenly lit"-Klausel sterilisierte erneut den Stil (bekannte Lesson wiederholt verletzt).

**Regel:** Generiert werden nur ATOME (nahtlose Muster-Kacheln, freistellbare Einzelobjekte, Porträts, Flächentexturen). Alles Zusammengesetzte (Kartenrücken = Kachel + Vektor-Rahmen, gefüllte Mulden = Schale + Münz-Sprites, Licht = Overlay) entsteht im Compositing. Licht-Vorgaben in Prompts nur minimal ("subject fully visible"), nie "evenly lit studio"-Vokabular.

## Cockpit bei jedem Zwischenstand aktualisieren (5.7., Tobsi-Zuruf "immer aktuell halten")
- Muster: status.html wurde nur an Entscheidungspunkten gepflegt und war einen halben Arbeitstag stale (zeigte "LoRA trainiert", während längst Brett v5 + Settings fertig waren).
- Regel: Das Cockpit wird bei JEDEM Commit/Zwischenstand mitgezogen (JETZT-GERADE-Block + Fortschrittsbalken), nicht nur bei neuen Tobsi-Entscheidungen. Es ist Tobsis einziges Live-Fenster in den Loop.

## Sichtungen als HTML öffnen, nicht nur ZIP (5.7. nachts, Tobsi: "mach doch die html dateien gleich auf")
- Muster: Sichtungs-Kandidaten lagen nur als ZIP in TEMP; Tobsi musste selbst entpacken und blättern.
- Regel: Jede Sichtung bekommt zusätzlich eine Auswahl-HTML in artifacts/ (Bilder nebeneinander + Copy-Antwortzeilen) und wird per `open` direkt aufgemacht - das ZIP bleibt fürs iPhone.

## Tobsi-Fragen sofort im Chat beantworten + bestätigen (5.7. nachts, eingefordert)
- Regel: Jede Frage von Tobsi wird unmittelbar im Terminal/Chat beantwortet, jede seiner Aussagen explizit bestätigt - bevor weitergearbeitet wird. Cockpit/HTML sind Spiegel, nie Antwortkanal.

## Entscheidungs-Standard: Räte vorab + Empfehlung + Cockpit-Log (5.7. nachts, eingefordert)
- Regel: Vor jeder Tobsi-Entscheidung: Gemini + GPT befragen, Meinungen bündeln, klare eigene Empfehlung. Jede Entscheidung als Eintrag im Cockpit-Entscheidungs-Log (Datum, Optionen, Räte, Empfehlung, Urteil).

## Keine Warp-Perspektive aus Top-down-Artwork (5.7. nachts, Tobsi: "sieht billig aus")
- Muster: Top-down-Brett per Homographie in ein Trapez gewarpt → matschig, Schrift klebt, wirkt billig.
- Regel: Perspektivische Ansichten kommen aus NATIV perspektivisch generiertem Artwork (LoRA kann es, Beleg Splash B4); Overlays (Zähler) dezent UNTER die Objekte, nie aufs Material geklebt.

## Parallel im Chat mitnehmen (5.7. nachts, ZWEIMAL eingefordert - Tobsi fühlte sich ignoriert)
- Regel verschärft: VOR jedem Arbeitsblock ein Satz im Chat, was jetzt passiert; NACH jedem Block ein Satz, was herauskam. Nie mehrere stumme Tool-Blöcke am Stück. HTML/Cockpit nur Archiv-Spiegel.
- Bei Wiederholung einer Anweisung durch Tobsi: zuerst direkt darauf antworten und bestätigen, nie kommentarlos weiterarbeiten.

## 5.7.2026 - Feel-Arbeit nie ohne Motion-/Audio-Externkritik live schalten

**Beobachtung:** Klang-Varianten + Melde-Münzflug wurden nach Frame-Verifikation der MECHANIK eingebaut - Tobsi stoppte mit „Animation schrecklich, Ton schrecklich, wirkt plump". Die Externkritik war erst NACH dem Einbau geplant; Standbilder belegen Zustände, aber nicht Bewegungsgefühl, und Audio kann ich gar nicht selbst hören.

**Regel:** Bei Animations-/Audio-Arbeit gilt der QA-Loop VOR dem Einbau in main: Bewegung als Frame-Serie/Video + Parameter-Beschreibung an die Räte (gemini-vision + gpt-review), Sound-Konzept (Varianten, Pitch, Layering) mitprüfen lassen. Eine einzelne Sample-Datei pro Ereignis und lineare Follow-Pfade sind bekannte Plumpheits-Marker - die stehen jetzt im GOTY-Review-Doc und dürfen nicht wieder vorkommen. Außerdem: gemini-review verliert stdin-Dokumente gelegentlich (generische Antworten = Warnsignal) - Dokument in den Prompt einbetten und Antwort auf Bezug zum Dokument prüfen.

## 6.7.2026 - Umlaut-Check als aktives Paket-Gate (Tobsi-Einschärfung)

**Beobachtung:** Tobsi hat die Umlaut-Regel (nie ae/oe/ue/ss, ß korrekt) vor der autonomen Nachtschicht ausdrücklich eingeschärft - die Regel existierte, aber nur passiv als CLAUDE.md-Text.

**Regel:** Vor jedem Commit läuft ein Ersatzformen-Grep über die geänderten Dateien (Swift, xcstrings, MD, HTML): `grep -rnoE "\b(fuer|ueber|koennen|muessen|zurueck|schoen|Muenze|grosser?|heisst|schliessen|ausserdem|Strasse)\b"` - Treffer = Fix vor Commit. Gilt besonders für generierte/Pipeline-Inhalte. Ausnahme bleiben Code-Identifier (ASCII).

## 6.7.2026 - Umlaut-Gate gilt auch für Commit-Messages (Selbstbefund, mehrfach)

**Beobachtung:** Wiederholt (autonomer Loop 6.7.: „gruen"; später „fuer/bloesses/schuetzbar/praezise") landeten Commit-Messages mit ASCII-Ersatzformen auf main - obwohl die Regel existierte. **Ursache:** (1) unnötige ASCII-Fizierung aus Vorsicht vorm Heredoc - dabei tragen `git commit -F - <<'MSG'`-Heredocs UTF-8 problemlos; (2) mein Pre-Commit-Grep prüfte nur Em-/En-Dashes im File-Diff, NIE die Message selbst.

**Regel:** Umlaute/ß direkt in die Commit-Message schreiben (Heredoc kann das). Der Pre-Commit-Grep läuft AUCH über den Message-Text, nicht nur den File-Diff: vor `git commit` gegen `\b(fuer|ueber|koennen|muessen|zurueck|gruen|schoen|Muenze|grosse|heisst|schliessen|ausserdem|bloesses|schuetzbar|praezise)\b` greppen. Amend nur solange ungepusht - für ein gepushtes Ein-Wort-Cosmetic keinen Force-Push (Prozess fixen statt Historie umschreiben).

## 6.7.2026 - Wirtshaus-Theme heißt 1441, nicht Klub
- **Korrektur (Tobsi, zweimal betont):** „das wirtshaus sollte nach 1441 aussehn" - meine erste Kandidaten-Runde (polierte Nussbaum-Klubtische mit Filz + Messing, 19. Jh.) war am Kern vorbei.
- **Regel:** Das Wirtshaus-Theme ist die 1441-Authentizitäts-Säule (CLAUDE.md §0, Säule 5): massives grobes Holz, handgehauen, Kerzen/Herdlicht, Gebrauchsspuren - NIE Klub-/Casino-/Salon-Ästhetik (die gehört dem Salon-Theme). Bei Wirtshaus-Assets immer zuerst fragen: „Würde das 1441 in einer Straßburger Schenke stehen?"
- **Prozess:** Wiederholt Tobsi eine Korrektur wortgleich, ist das ein „mach einfach"-Signal - nicht erneut präzisierend nachfragen, sondern die breiteste sinnvolle Deutung in EINER Sichtung abdecken.

## 6.7.2026 - Monolith-Skripte + gechainte Commits = halbe Zustände
- **Beobachtet:** Ein großes Python-Heredoc starb am Anführungszeichen-Syntaxfehler; der per && gechainte git-commit lief trotzdem mit einer VERALTETEN /tmp/commitmsg.txt durch (zweimal, inkl. Force-Push mit falscher Message).
- **Regel:** Auslieferungs-Pakete in kleine, einzeln verifizierte Schritte teilen (Assets → HTML → Message → Commit als getrennte Aufrufe). `git commit` nie im selben Shell-Block wie ein fehlbares Skript chainen. /tmp/commitmsg.txt vor jedem Commit per `head -1` gegenlesen. Deutsche Anführungszeichen in Python-Strings meiden oder Single-Quotes nutzen.

## 7.7.2026 - Keine ZIPs mehr: Sichtungen leben im Cockpit-HTML

**Beobachtung:** Tobsi (bei der Kartenrücken-/Charakterstil-Frage): „bitte nichts als zip, sondern immer in cockpit html einbauen und html öffnen" - die ZIP-Auslieferung nach iCloud-TEMP ist damit komplett abgelöst (Verschärfung der 5.7.-Lesson „Sichtungen als HTML öffnen").

**Regel:** Jede Sichtung (Stil-Kandidaten, Asset-Chargen) wird direkt ins Cockpit-HTML eingebettet (gelabelte Bilder, Base64), das Cockpit nach iCloud-TEMP gespiegelt und per `open` geöffnet. Keine ZIP-Pakete mehr, auch nicht zusätzlich.

## 7.7.2026 - Vision-QA misst "premium", übersieht aber Assoziations-Reads (Casino)

**Beobachtung:** Kartenrücken A (gebürstetes Radial-Metall, Goldrand, Chrom-Dom) bekam Gemini-Scores 8/6 - Tobsis externe Kritik erkannte sofort: Roulette-Rad/Uhren-Lünette = der Casino-/Crypto-Read, den der Kanon explizit verbietet. "Premium messen" und "verbotene Assoziation erkennen" sind zwei verschiedene Prüfungen.

**Regel:** Jede Vision-QA von Poch-Assets fragt EXPLIZIT nach verbotenen Reads als eigene Zeile: „Liest sich das als Casino/Roulette/Spielautomat, Uhren-Werbung, Crypto-Coin oder Mittelalter-Kitsch?" Score-Fragen ersetzen keine Assoziations-Fragen. Bei Marken-Kernelementen (Rücken, Icon, Splash) zusätzlich eine zweite unabhängige Vision-Frage nur auf Assoziationen.

## 7.7.2026 - Gestalt schlägt Material (Roulette-Read der Ring-Signets)

**Beobachtung:** Vier X-Varianten (Material, Füllung, Linienstärke, Skala variiert) - alle entweder Rad-Read (X1-X3) oder Marken-Verlust (X4, „casino-frei durch Verzicht"). Tobsis Reviewer benannte die Ursache: ein geschlossener Farbkreis um ein Zentrum IST die Rad-Gestalt - das Auge liest Roulette unabhängig vom Material. Drei Runden am selben Motiv gedreht (wörtlich: am Rad).

**Regel:** Besteht ein Motiv-Problem nach 2 Varianten-Runden, zuerst fragen: Material-Problem oder GESTALT-Problem? Gestalt-Probleme (Silhouette, Symmetrie, Anordnung) erfordern Kompositions-Wechsel - Achse kippen, Symmetrie brechen, Element verlagern - nie eine weitere Material-Runde. Dokumentierte Abbruchregel für den Rücken: Sitzt auch die Wappen/Brett-Runde nicht, wandert das Rücken-Signet auf ein anderes Marken-Element (Monogramm, 1441-Relief); der Mulden-Ring bleibt, wo er unschlagbar ist - als spielbares Brett.

## 8.7.2026 - ~20 $ in kurzer Zeit verbrannt: Kontext-Aufblähung ist der Kostentreiber

**Beobachtung:** Tobsi: „habe gerade innerhalb kürzester Zeit 20$ verfeuert." Muster der Sessions davor: Cockpit-HTML mit Base64-Bildern und andere große Artefakte wanderten in den Kontext, Loops liefen mit ausführlichem stdout, Screenshots in voller Auflösung, keine /clear-Schnitte - und alles davon wird bei jedem Folge-Turn erneut als Input bezahlt.

**Regel:** Neue globale Sektion „💸 Kontext- & Token-Disziplin" in `~/.claude/CLAUDE.md`: große generierte Dateien nie komplett per Read (grep/sed-Ausschnitte), Loops mit quiet-stdout + einem Sammel-Summary, Cockpit nur bei Commit/Zwischenstand regenerieren und nie zurücklesen, Bilder vor dem Read auf ~800px verkleinern, nach jeder Task Stand nach `tasks/todo.md` schreiben und den /clear-Schnittpunkt aktiv im Chat anbieten.
