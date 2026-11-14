# Ressourcen und Referenz – 0.3.0

Die aktuell verwendeten gemalten PNG-Atlanten sind eigenständige KI-generierte Ressourcen. Werkzeug, Motive, Dateipfade und vollständige Erzeugungs-/Bearbeitungsprompts stehen in [ART.md](ART.md). Keine Grafik, Figur, Musik oder Dialogdatei der APK wurde übernommen. Das Kornfeld und die dynamischen Effekte bleiben eigene Vektor-/Codegrafiken.

Die ursprünglichen Demo-PNGs unter assets/sprites bleiben unbenutzt und vom Windows-Paket ausgeschlossen. Die eigenen Vektorgrafiken aus 0.2 bleiben als frühere Ressourcen erhalten. Ein neues Atmosphärengeräusch wird im Spiel aus Rauschen und Chirp-Tönen synthetisiert, ohne fremde Audiodateien.

## APK-Prüfung

Bereitgestellt: `Smurfs_Village-NTE5OTUz.apk`, 24.538.228 Byte. Nur die ZIP-Inhaltsstruktur wurde gelesen, keine Originalressourcen extrahiert, eingebunden oder verändert.

- 672 Einträge unter `assets`, 147 unter `res`.
- Binäres Android-Manifest: 6.076 Byte.
- Android-Ressourcentabelle: 16.388 Byte.
- `classes.dex`: 448.964 Byte.
- Native ARM-Bibliothek `lib/armeabi/libSmurfsAndroid.so`: 1.159.520 Byte.

Das zeigt eine ältere Android-App mit Java/Dalvik- und nativen ARM-Komponenten, keine direkt editierbare Godot-Projektstruktur. Die APK wurde nicht ausgeführt oder vollständig dekompiliert. Aus diesen Dateilisten wurden keine konkreten Aussagen über interne Spielregeln, exakte Timer oder Balancewerte abgeleitet. Die Spielmechaniken dieser Kernversion folgen dem Entwicklungsauftrag und der gelieferten Demo.

## Engine

Godot 4.7.2 stable wurde aus dem vorhandenen Download verwendet. Die Windows-Spielversion bündelt eine unveränderte Kopie der vorhandenen Godot-Engine und das neu erzeugte Projektpaket. Lizenztext: `GODOT-LICENSE.txt`; mit `Engine.get_copyright_info()` und `Engine.get_license_info()` ermittelte Drittkomponentenhinweise: `GODOT-THIRD-PARTY.json`.



## Ergänzung 0.4.0

- **Waldlinge**: vollständig im Code gezeichnet (`scripts/anim/woodling_rig.gd`), eigenes Design nach dem bisherigen Mooswinkel-Waldling (Eichelkappe, Blattohren, Blattumhang). Das frühere Bildatlas `assets/painted/woodling-atlas.png` wird nicht mehr verwendet und bleibt nur als Referenz im Projekt.
- **Findlinge, Baumstümpfe, Setzlinge, Werkzeuge, Lasten, Hausschilder, Partikel**: Vektorzeichnung im Code. Waldbäume nutzen das vorhandene eigene Baum-Motiv.
- **Geräusche**: alle zur Laufzeit synthetisiert (`scripts/audio/sfx.gd`), keine Audiodateien.
- **Besondere Bewohner**: Namen (Birka, Ilvi, Kolbo, Zimmerling, Mehlwin, Summa, Salbei, Taler), Rollen und Effekte sind eigene Erfindungen.
- **APK-Analyse 0.4.0**: erneut nur Inhaltsverzeichnis und Dateiformate betrachtet. Die APK enthält 13 binäre Figurendefinitionen (überwiegend Animations-Bildtabellen), eine Fortschrittstabelle mit exponentiell steigender Erfahrungskurve und rund 230 Story-/Dialogdateien. Übernommen wurde nur das allgemeine Prinzip „einzelne benannte Figuren mit eigener Rolle, an Gebäude gebunden“. Keine Daten, Werte, Namen, Texte, Grafiken, Schriften oder Musik der APK wurden extrahiert oder eingebunden.
