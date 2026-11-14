# Mooswinkel – Dein kleines Walddorf

**Entwicklungsfassung 0.7.0 – Tiere**, 13. November 2026. Keine Vollversion; Stand und offene Punkte: [STATUS](docs/STATUS.md).

Das vollständige Projekt liegt jetzt unter **E:\Unternehmen\Spielerei\Mooswinkel**. Die frühere Projektkopie unter Maniac wurde nach einem Dateivergleich entfernt. Die editierbare Fassung 0.2 bleibt als ZIP unter `archive/0.2` erhalten.

## Starten

Im Windows-Spielordner **Mooswinkel.exe** starten. Das Spiel startet jetzt im Vollbild. F11 wechselt jederzeit zwischen Vollbild und Fenster; die Seitenleisten und Anzeigen passen sich an das Bildschirmformat an. **Mooswinkel.pck muss daneben bleiben.** Alternativ `Start-Mooswinkel.cmd` verwenden. ZIP-Dateien zuerst vollständig entpacken. Internet oder Installation sind nicht erforderlich.

- Direkt spielbar: `dist/Mooswinkel-Windows/Mooswinkel.exe`
- Windows-ZIP: `dist/Mooswinkel-Windows.zip`
- Editierbares Projekt-ZIP: `dist/Mooswinkel-Quellprojekt.zip`
- Godot-Projekt: `project.godot` in Godot importieren, F5 drücken.

Mit der vorhandenen Godot-Version **4.7.2 stable** unter Windows getestet. GDScript, GL Compatibility, keine Zusatzpakete oder kostenpflichtigen Abhängigkeiten. Da keine Exporttemplates installiert sind, enthält die portable Spielversion eine Kopie der vorhandenen Godot-Engine plus exportiertem PCK. Sie ist deshalb größer als ein regulärer Releaseexport.

## Neu in 0.7

- Tiere: Hühnerhof, Schafweide, Ziegenweide, Käserei; Wildtiere in der Welt.
- Jede Katalogkarte sagt, was das Gebäude herstellt oder wer einzieht; Infofeld mit Fähigkeiten, Kosten und Fehlbetrag.
- Genaue Meldungen, was zum Bauen oder Ausbauen fehlt; Direktverkauf je Ware im Reiter „Lager“.

## Neu in 0.6

- Lagergrenzen und Vorratsscheune; „voll“-Symbol an betroffenen Betrieben.
- Ackerbeete mit 8 Sorten (Sorte im Gebäude-Reiter wählen), überreife Beete geben halben Ertrag.
- Anglerhütte am Wasser mit Angel-Animationen und Räucherkate.
- Dorfwünsche sind Lieferwünsche aus dem Lager.

## Neu in 0.5

- Vier Jahreszeiten mit eigener Grafik: Blüten, Herbstlaub, Schnee, gefrorener Teich, Wetter, Winterschals. Winter lässt Beete und Bäume langsamer wachsen.
- Kein Endlevel: unbegrenzte Dorfstufen und immer neue Dorfwünsche nach den 14 Einführungsaufträgen.
- Lageransicht im Reiter „Lager“. Ausbauplan für die nächsten Phasen: [PLAN](docs/PLAN.md).

## Neu in 0.4

- **Waldlinge arbeiten sichtbar**: neues 2D-Skelett mit 8 Blickrichtungen, 8 Gehphasen und über 20 Aktionen (Hacken, Steinabbau, Säen, Gießen, Sichelernte, Beerenpflücken, Tragen, Absetzen, Sägen, Kneten, Rühren, Imkern, Ruhen …).
- **Aufgabensystem**: Holzfäller fällen Bäume und tragen das Holz zur Forsthütte, Kieselsammler holen Stein von Findlingen, freie Waldlinge säen, gießen und ernten, Werkstätten brauchen einen Waldling, der Rohstoffe holt und vor Ort arbeitet. Erträge zählen erst bei der Übergabe.
- Bäume wachsen nach (Stumpf → Setzling → Baum), Förster pflanzen neu, Jungbäume kann man selbst pflanzen.
- **Besondere Bewohnerhäuser** (Kategorie „Bewohner“): jedes bringt einen bestimmten Waldling mit eigener Fähigkeit ins Dorf.
- Gebäude per Klick auf ihr Bild auswählen; Waldlinge anklicken (Reiter „Bewohner“).
- **Beenden**-Knopf (speichert vorher), Strg+Q; Optionen mit Gesamt-, Atmosphären- und Effektlautstärke, Statussymbolen, Nachtlicht, Raster, Vollbild.
- Synthetisierte Arbeitsgeräusche, Holzsplitter, Funken, Staub, Ernte- und Wassereffekte.
- Bestehende Spielstände (0.2/0.3) werden übernommen.

## Bedienung

| Aktion | Bedienung |
| --- | --- |
| Bauen | Kategorie und Motiv links wählen, freien Bauplatz anklicken |
| Infos | Modus „Info“, Gebäude (auch Dach/Krone) oder Waldling anklicken; Rechtsklick geht immer |
| Ernten / Säen von Hand | Rechtsklick auf reifes bzw. leeres Beet |
| Wege zeichnen | Waldweg wählen, linke Maustaste halten und ziehen |
| Verschieben / Abriss | Modus wählen, Gebäude anklicken (beim Verschieben danach Zielplatz) |
| Ausbau / Pause | Gebäude anklicken, Reiter „Gebäude“ |
| Kamera / Zoom | WASD oder mittlere Maustaste / Mausrad |
| Pause / Tempo | Leertaste, Knöpfe 1×/2×/4× |
| Speichern / Beenden | F5 / „Beenden“ oder Strg+Q (speichert) |
| Vollbild, Raster, Leisten | F11, G, Tab |

Symbole über Gebäuden: **?** kein Waldling frei · **…** wartet auf Waren · **II** pausiert · **!** kein Weg oder eingeschlossen.

## Wirtschaft

| Gebäude | Arbeit | Ergebnis |
| --- | --- | --- |
| Wurzelhäuschen | – | 2 Waldlinge je Ausbaustufe |
| Besondere Häuser | – | je 1 benannter Waldling mit Dorfeffekt, einmalig |
| Ackerbeet | Helfer säen die gewählte Sorte, gießen (+35 % Wachstum), ernten | Korn 6 + 2 Nahrung + 3 Münzen · Karotten 5 · Kohl 4 · Kartoffeln 6 · Zwiebeln 5 · Kürbisse 3 · Flachs 5 · Sonnenblumen 4 (je mit Nahrung/Münzen, siehe Spiel) |
| Anglerhütte | Angler am Ufer (nur in Wassernähe) | 4 Fisch pro Gang |
| Räucherkate | Waldling holt Fisch und Holz | 3 Fisch + 2 Holz → 3 Räucherfisch + 3 Nahrung, 16 s |
| Vorratsscheune | – | +150 Lagerplatz je Ware und Ausbaustufe (Grundlager 120) |
| Hühnerhof (3 × 3) | Hirtin füttert | 2 Korn → 4 Eier, 20 s |
| Schafweide (3 × 3) | Hirte füttert | 2 Korn → 3 Wolle, 30 s |
| Ziegenweide (3 × 3) | Hirtin füttert | 1 Korn → 3 Milch, 24 s |
| Käserei | Waldling holt Milch | 3 Milch → 2 Käse + 3 Nahrung, 20 s |
| Beerengarten | Helfer pflücken | 5 Beeren, 2 Nahrung |
| Forsthütte | Holzfäller, Umkreis 8 Felder | 8 Holz pro Gang, pflanzt nach |
| Kieselsammler | Steinsammler an Findlingen, sonst Felswand | 5 (bzw. 3) Stein pro Gang |
| Sägemühle | Waldling holt Holz | 6 Holz → 4 Bretter, 14 s |
| Kornmühle | Waldling holt Korn | 4 Korn → 3 Mehl, 12 s |
| Ofenstube | Waldling holt Mehl | 3 Mehl → 3 Brot + 3 Nahrung, 16 s |
| Sonnenimkerei | Waldling imkert | 3 Honig, 20 s |
| Marmeladenküche | Waldling holt Honig/Beeren | 2 Honig + 4 Beeren → 3 Marmelade, 18 s |
| Gasthaus | Waldling holt Brot/Marmelade | 30 Münzen + 2 Nahrung, 24 s |

Werkstätten arbeiten nur mit einem Waldling vor Ort; jede Ausbaustufe schafft einen weiteren Arbeitsplatz. Je zwei Waldlinge brauchen pro Spielminute eine Nahrung; fehlt sie, arbeiten alle langsamer (niemand stirbt). Der Waldspaziergang (alle 12 s) hilft immer aus einer Flaute.

## Speichern

Automatisch alle 60 realen Sekunden und beim normalen Schließen; zusätzlich per Button/F5. Temporäre Datei, Validierung, vorheriger Stand als `.bak`. Beschädigte Hauptdateien führen zum Versuch, die Sicherung zu laden. Ungültiges manuelles Laden verändert das Dorf nicht.

Windows-Speicherort: `%APPDATA%/Godot/app_userdata/Mooswinkel - Dein kleines Walddorf/village_v1.json`. Der Dateiname bleibt gleich, das interne Schema ist jetzt Version 3 (inkl. Bewohneraufgaben). Ältere Stände werden beim Laden übernommen; eine Sicherung des 0.3-Stands liegt unter `archive/0.3.1/spielstand`. Die APK und die ältere Deluxe-Demo werden nicht importiert. Kein Fortschritt bei geschlossenem Spiel.

## Entwicklungsstand

Automatisiert: 211 + 46 + 96 + 23 + 51 Regelprüfungen, Komplettdurchlauf aller 14 Aufträge plus 6 Dorfwünsche mit Bewohnersimulation, Laufzeitintegration mit der echten Hauptszene – alle bestanden. Dazu visuelle Prüfungen per Kontaktbogen und Spielaufnahmen. **Keine Vollversion**: Balance, weitere Inhalte, eigene Grafiken für neue Objekte, Leistungsmessung und menschliche Spieltests fehlen. Details: [Testbericht](docs/TESTBERICHT.md), [Architektur](docs/ARCHITEKTUR.md), [offene Aufgaben](docs/STATUS.md), [Ressourcen](docs/RESSOURCEN.md), [Änderungen](CHANGELOG.md).

## Neu bauen und testen

PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -GodotConsole 'C:\Users\green\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
```

Das setzt die Ausführungsrichtlinie nur für diesen einen PowerShell-Prozess und verändert keine Systemeinstellung. Das Skript isoliert Testspielstände, importiert Ressourcen, prüft Simulation und Laufzeit, exportiert das PCK und erstellt beide ZIPs. Protokolle: `build/*.log`. Grafische Prüfungen:

```powershell
$env:APPDATA = Join-Path $PWD '.runtime'
$godot = 'C:\Users\green\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . --script res://tests/road_atlas.gd
& $godot --path . --script res://tests/rig_sheet.gd -- --anims=walk,chop,mine,reap,pick
& $godot --path . --script res://tests/qa.gd
```

Die Tests erzeugen und entfernen Testspielstände: dafür stets ein isoliertes APPDATA benutzen. Für reguläres Spielen danach eine neue PowerShell öffnen. Engine-Lizenz und Drittkomponentenhinweise liegen dem Windows-Paket bei.

