# Testbericht – 0.7.0

Datum: 13. November 2026. Windows 11, Godot 4.7.2 stable, GL Compatibility, AMD Radeon RX 6700 XT. Alle Tests laufen im Buildskript mit isoliertem Profil (`.runtime`).

## Automatisiert – alle bestanden

| Suite | Ergebnis | Inhalt |
| --- | --- | --- |
| `tests/suite.gd` | 211 Prüfungen, 0 Fehler | Alle 16 Wegmasken, Bauen/Kollision/Erstattung, Wachstum, Werkstattkette mit Waldlingen, Markt, Erholung aus leeren Lagern, Speichern/fehlerhafte Daten, 4-Nachbarn-Wegsuche |
| `tests/expansion.gd` | 46 Prüfungen, 0 Fehler | Ausbau, Pause, Beeren/Imkerei/Marmelade/Gasthaus mit Arbeitern, Gebietserweiterungen, Handel, Nahrung, Migration Schema 1 |
| `tests/residents_test.gd` | 96 Prüfungen, 0 Fehler | siehe unten |
| `tests/endless_test.gd` | 23 Prüfungen, 0 Fehler | Endlose Stufenkurve (bis Stufe 150 geprüft), Stufenerhalt bei alten Spielständen, Jahreszeitenfolge und Übergang, Winter bremst Wachstum, Speichern der Jahreszeit, Dorfwünsche (Erscheinen, einmalige Belohnung, Abwechslung, Wachstum mit Stufe, Tauschen mit Abklingzeit, Speichern), wartende Waldlinge stehen nicht übereinander |
| `tests/phase2_test.gd` | 36 Prüfungen, 0 Fehler | Lagergrenze und Erhalt alter Übermengen, Scheune und Ausbau, Holzfäller ruht bei vollem Lager, Händler verkauft die vollste Ware, Aussaat der gewählten Sorte mit Saatkosten, Ausgraben statt Sichel bei Karotten, einmaliger Ertrag, überreif = halber Ertrag, Wachstumszeiten je Sorte, Saat von Hand, Anglerhütte nur in Wassernähe, Auswerfen/Warten/Einholen, je Fang genau eine Auszahlung, Winter fängt weniger, Speichern während des Wartens, Räucherkate, Migration Schema 4 |
| `tests/campaign.gd` | 14/14 Aufträge + 8 Lieferwünsche, 0 Fehler | Spieler-Bot mit echter Bewohnersimulation, nur erwirtschaftete Waren, beide Erweiterungen, kein eingeschlossener Bewohner |
| `tests/runtime.gd` | 0 Fehler | Echte Hauptszene: Katalog, Hausbau per Maus, **Hausauswahl über Klick aufs Dach**, Rechtsklick-Info, Wegeziehen, Geräusche, Beenden-Dialog, 60 s Bewohnerarbeit auf erlaubtem Boden, Speichern/Laden/Sicherung/Wiederherstellung |

`residents_test.gd` prüft u. a.:
- Holz wird nur im Übergabe-Ereignis gutgeschrieben, genau eine Ladung pro Gang; jeder Gang braucht seine Treffer; Bäume werden gefällt und wachsen nach.
- Bildschritte für 1×, 2×, 4×: keine doppelte Belohnung; Pause verändert nichts.
- Speichern mitten im Hacken (nach dem 2. Treffer) und während des Tragens: gleiche Erträge, keine wiederholten oder ausgelassenen Treffer, Ladung genau einmal geliefert.
- Abriss der Forsthütte während des Tragens: Ladung einmal gebucht, keine verwaisten Reservierungen, Arbeiter frei. Verschieben während der Arbeit: Arbeit geht weiter. Gebäude auf einem Bewohner: Bewohner wird befreit. Eingeschlossenes Haus wird erkannt.
- Beete: Aussaat durch Helfer, mehrere Sichelschläge, Zustand ändert sich erst beim Abschluss, Ertrag einmal; manuelle Ernte eines reservierten Beets ohne Doppelertrag; Beeren mit eigener Pflückanimation.
- Werkstatt: Waldling holt Rohstoffe, Produktion nur mit Arbeiter, Pause gibt den Platz frei.
- Geglättete Pfade bleiben auf freiem Boden, blockierte Ziele werden abgelehnt, Wege werden bevorzugt.
- Spezialisten: einmalig baubar, genau ein Bewohner, Identität gespeichert, Holzmeisterin +2 Holz pro Gang.
- **Echter 0.3-Spielstand** des Spielers wird übernommen; Bestände und Häuser unverändert, Bewohner und Wald ergänzt, Neuspeicherung im Schema 3.

Während der Prüfungen gefundene und behobene Fehler: Abklingzeiten (Waldspaziergang, Händler, Aufträge) wurden durch Rundung in kleinen Zeitschritten nie ganz null; Waldlinge schnitten auf dem ersten/letzten Wegstück diagonal über Beet-Ecken.

## Visuelle Prüfung (echtes OpenGL, keine Headless-Bilder)

- **Rig-Kontaktbögen** (`tests/rig_sheet.gd`, Ergebnisse in `build/qa/sheet_*.png`): alle 8 Richtungen × alle Bilder für Gehen, Ruhe, Umschauen, Sitzen, Tragen, Axt ziehen/verstauen, Hacken, Steinabbau, Säen, Gießen, Korn ernten, Beeren pflücken, Aufheben, Absetzen, Sägen, Sack ausgießen, Kneten, Rühren, Waben heben, Bedienen, Pflanzen. Geprüft: gleiche Figur und Fußlinie in allen Richtungen, Axt immer rechts, Seitenprofil mit Auge/Nase, Rückansicht mit Umhang und Haar. In der ersten Fassung gefundene Mängel (Umhang als Streifen, Haar als Scheibe, Nase verdeckte Auge, kaputte Stiefelpolygone) wurden behoben und erneut gerendert.
- **Spielaufnahmen** (`tests/qa_scene.gd`): Übersicht und Nahaufnahmen tatsächlicher Aktionen im laufenden Spiel – Hacken am Baum, Tragen zur Sägemühle, Sichelernte, Säen, Steinabbau am Findling, Sägen. Sortierung vor/hinter Gebäuden und Bäumen sichtbar korrekt.
- **Auslieferung**: Die gebaute `dist/Mooswinkel-Windows/Mooswinkel.exe` wurde eigenständig mit einer Kopie des echten 0.3-Spielstands gestartet und hat ihn übernommen (`build/qa/release_migrated.png`).

## Jahreszeiten – visuelle Prüfung (0.5)

`tests/seasons.gd` rendert dasselbe Dorf in allen vier Jahreszeiten (`build/qa/season_*.png`, Übersicht `seasons_grid.png`). Erste Fassung: Herbstlaub kaum sichtbar (gelbgrünes Laub fiel durch die Farberkennung), Frühlingsboden zu grell, grelle Grasflecken im Schnee, Gebäude unter dem Mauszeiger transparent. Nach Umstellung auf Farbton-Erkennung erneut gerendert: Blüten, kräftiges Herbstlaub, Schnee auf Kronen und Boden, gefrorener Teich sichtbar.

Messwerte des Komplettdurchlaufs (Bot, 0.5): Einführung nach 22 Spielminuten (Stufe 6), Stufe 7 nach 41, Stufe 8 nach 57 Minuten, 6 Dorfwünsche erfüllt.

## Phase 2 – visuelle Prüfung (0.6)

`tests/qa2.gd` erzeugt Übersicht und Nahaufnahmen (`build/qa/p2_*.png`, Übersicht `p2_grid.png`): Beete aller Sorten in verschiedenen Wachstumsstufen (Sommer und Herbst), Angler beim Auswerfen, Warten und Einholen mit Schnur, Schwimmer und Wasserringen. Gefunden und behoben: Angler stand hinter dem Dach der eigenen Hütte (Uferplätze dahinter werden jetzt gemieden); Karotten wurden zunächst mit der Sichel statt kniend geerntet.

Langlauf: Mit Lagergrenzen und Herstellungswünschen blieb der Bot 4,5 Stunden ohne erfüllten Wunsch stecken (Wunschware konnte bei vollem Lager nicht hergestellt werden; Bot ohne Korn konnte kein Brot liefern). Behoben durch Lieferwünsche aus dem Lager mit Obergrenze; der Bot tauscht außerdem festsitzende Wünsche wie ein Spieler. Ergebnis 0.6: Einführung nach 22 Minuten, 8 Lieferwünsche bis Minute 50.

## Phase 3 und Hinweise – Prüfung (0.7)

Fehlerbericht „Anglerhütte nicht baubar, manche Häuser nicht ausbaubar“ am echten Spielstand untersucht: Mit genug Waren sind Anglerhütte (81 Stellen am Wasser) und alle ausbaufähigen Gebäude baubar; Ursache war Geldmangel (22 Münzen) bei sehr großen Holz-/Bretterbeständen, ohne dass das Spiel das klar sagte. Behoben durch genaue Meldungen, Hinweis am Mauszeiger und Direktverkauf; geprüft mit einer Kopie des Spielstands (`build/qa/info_catalog.png`, `info_bewohner.png`) und automatisch (`phase2_test`, hints).

Tiere: `tests/animal_sheet.gd` rendert alle 8 Arten in 8 Richtungen und alle Bewegungen (`build/qa/animals_*.png`); gefunden und behoben: Ente beim Schwimmen unsichtbar (Zeichenverschiebung zurückgesetzt). `tests/qa3.gd` zeigt Gehege mit Tieren, fütternde Hirtinnen, Wildtiere und schlafende Tiere am Abend (`p3_*.png`); gefunden und behoben: Absturz beim Vorderzaun, Hirtin stand auf dem Zaun.

## Grenzen dieser Prüfung – ehrlich

- Kein menschlicher Spieltest der neuen Abläufe; keine Prüfung durch eine zweite Person.
- Die Animationen wurden anhand von Einzelbildern und Bildfolgen beurteilt, nicht als Video. Gehen ist bewegungsgekoppelt (rechnerisch rutschfrei), aber bei 8 festen Phasen wandert der Standfuß innerhalb eines Bildes um rund einen Bildpunkt – üblich bei Bildfolgen, nicht weiter gemessen.
- Wartende Waldlinge können am selben Eingang übereinander stehen.
- Keine Leistungsmessung mit sehr großem Dorf (z. B. 100+ Bewohner), keine schwächere Hardware.
- Keine Hörprüfung der synthetisierten Geräusche; nur technisch erzeugt und abgespielt.
- Keine Prüfung unterschiedlicher Monitorformate über 1600×900/1920×1080 hinaus in dieser Fassung.
- Balance: Einführung weiterhin schnell (22 Spielminuten); Waren stapeln sich ohne Lagergrenzen. Übergänge der Jahreszeiten nur als Standbilder geprüft.
- Kein Android/Touch.
