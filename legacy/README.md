# legacy/

Altes Projekt, nur Referenz, wird nicht gebaut.

- **Sicherung:** Der Stand vor dem Neustart liegt unter dem Git-Tag `legacy-snapshot`. Der Tag enthält nur versionierte Dateien. Ignorierte Inhalte wie `Assets_Raw/`, Videos und Build-Reste existieren weiterhin nur auf der Platte.
- **Altes README:** Das ursprüngliche Projekt-README heißt hier `README-alt.md`, sein Inhalt ist unverändert.
- **Release-Pipeline:** `fastlane/` ist bewusst im Repo-Root geblieben und wird vom neuen Projekt weiterverwendet.

## Alten Stand ansehen

Ein eigener Arbeitsbaum zeigt das alte Projekt in seiner ursprünglichen Ordnerstruktur, ohne das Root anzufassen:

```bash
git worktree add ../poch1441-legacy-snapshot legacy-snapshot
```

## Umbau zurückdrehen

Die Verschiebung umgekehrt ausführen: `git mv legacy/<Name> <Name>` für versionierte Einträge, ein normales `mv` für die ignorierten Einträge `Poch1441.xcodeproj`, `Assets_Raw`, `old-clip.wav`, `.poch-simulator-udid`, `.build` und `.derived-time-swipe`. Ein bloßes `git revert` oder ein Branch-Wechsel genügt nicht, weil ignorierte Dateien dabei unter `legacy/` liegen bleiben.
