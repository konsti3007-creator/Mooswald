# Änderungen

## 0.8.0 – Neues Gesicht, Nachtlicht und eigene Häuser

- **Logo** (KI-generiert über AiFlix) im Spiel, als App-Symbol und Startbild.
- **Neue Oberfläche**: Kopfleiste mit Logo, Waren als Symbole mit Anzahl (rot bei vollem Lager, Tooltip mit Lagerplatz), Dorfstufe mit Fortschritt, Waldlinge, Jahreszeit und Uhrzeit, Tempo/Optionen/Hilfe/Beenden als Symbole. Links eine Werkzeugleiste mit Symbolen (Bauen, Info, Bewegen, Abriss, sieben Baukategorien, Ernten, Sammeln, Verkaufen, Speichern); das **Baumenü klappt aus** und wieder ein. Statusmeldungen erscheinen kurz unten. Laden und Neues Dorf liegen in den Optionen.
- **Individuelle Bewohnerhäuser**: alle acht besonderen Häuser haben eigene gemalte Bilder (Blockhütte, Gärtnerhaus mit Gewächshaus, Steinkate mit Kristall, Werkhaus mit Kran, Brotlaib-Bäckerei, Imkerhaus, Kräuterhütte, Händlerhaus).
- **Nachtlicht**: weicher Übergang in Dämmerung und Nacht; Fenster, Laternen und Öfen leuchten (Lichtpunkte je Bild per Farbanalyse ermittelt und von Hand geprüft), Waldlinge tragen nachts ein kleines Licht, Glühwürmchen.
- **Tiere im Stil der Waldlinge**: größere Köpfe, Glanzaugen, Wangen, heller Bauch, Fellstriche, weichere Farben.
- **Behoben: Verschieben/Abriss traf das falsche Objekt**, wenn man auf ein Dach klickte (Bodenzelle dahinter hatte Vorrang). Auswahl jetzt pixelgenau nach dem sichtbaren Bild; Prüfskript `tests/move_pick.gd`.

## 0.7.0 – Tiere und klare Hinweise (Phase 3)

- **Behoben: „Anglerhütte nicht baubar / Ausbau nicht möglich“**: Ursache war fehlendes Geld (geprüft am echten Spielstand: 22 Münzen, aber 2400 Holz und 618 Bretter). Meldungen nennen jetzt genau, was fehlt („Es fehlen 18 Münzen.“), auch direkt am Mauszeiger in der Bauvorschau; der Ausbauknopf zeigt Kosten oder Fehlbetrag. Gründe wie „Braucht Wasser in der Nähe“ oder „Kein freier Bauplatz“ erscheinen ebenfalls am Mauszeiger.
- **Direktverkauf im Reiter „Lager“**: je Ware „10“ oder „Überschuss“ (alles über halbem Lager), mit Stückpreis.
- **Was macht welches Gebäude?** Jede Katalogkarte zeigt die Leistung (z. B. „Angler: 4 Fisch je Fang“, „6 Holz → 4 Bretter“) bzw. welcher Bewohner einzieht; ein Infofeld unter dem Katalog erklärt Auswahl, Fähigkeit des Bewohners, Kosten und Fehlbetrag.
- **Tiere**: eigenes Tier-Skelett (Huhn, Ente, Schaf, Ziege, Reh, Hase, Eichhörnchen, Igel) in 8 Richtungen mit Gehen/Trab/Hoppeln, Grasen/Picken, Ruhe, Schlaf, Schwimmen.
- **Neue Kategorie „Tiere“**: Hühnerhof (2 Korn → 4 Eier), Schafweide (2 Korn → 3 Wolle), Ziegenweide (1 Korn → 3 Milch) als 3 × 3-Gehege mit Zaun, Unterstand und Heu; Käserei (3 Milch → 2 Käse + 3 Nahrung). Hirtin/Hirte holt Futter und füttert von außen; Tiere schlafen nachts, mehr Tiere je Ausbaustufe.
- **Wildtiere**: Hasen, Eichhörnchen, Rehe am Waldrand, Igel (Winterschlaf), Enten auf dem Teich (im Winter fort). Sie weichen gehenden Waldlingen aus; angeklickt (Info-Modus) gibt es Herzchen und einen kleinen Bonus mit Abklingzeit.
- Speicherschema 6.
- Tests: Hinweise/Verkauf und Tiere in `phase2_test` (51 Prüfungen); Langlauf baut einen Hühnerhof.

## 0.6.0 – Vorräte, Ackerbeete und Angler (Phase 1b und 2)

- **Lagergrenzen**: 120 Stück je Ware (Münzen unbegrenzt). **Vorratsscheune** (ab Stufe 2) schafft 150 Platz je Ausbaustufe. Ist ein Lager voll, ruhen die zugehörigen Arbeiten (Symbol „voll“), statt Ware zu vernichten. Alte Spielstände mit größeren Beständen behalten sie.
- **Ackerbeete mit Sortenwahl**: Korn, Karotten, Kohl, Kartoffeln, Zwiebeln, Kürbisse, Flachs, Sonnenblumen – eigene Wachstumszeit, Ertrag, Saatkosten, Freischaltstufe und eigenes Aussehen in vier Wachstumsstufen. Sorte im Gebäude-Reiter wählen; Waldlinge säen die gewählte Sorte. Sichel-Ernte für Halmfrüchte und Kohl, kniendes Ausgraben für Knollen und Kürbisse.
- **Überreif**: Bleibt ein reifes Beet so lange stehen, wie es zum Wachsen brauchte, gibt es nur noch den halben Ertrag (nie gar nichts).
- **Anglerhütte** (ab Stufe 3, nur in Wassernähe): Angler gehen ans Ufer, werfen aus, warten auf den Biss (Sommer schneller, Winter langsamer), holen den Fisch ein und tragen ihn zur Hütte. Eigene Animationen mit Rute, Schnur, Schwimmer und Wasserringen.
- **Räucherkate** (ab Stufe 5): 3 Fisch + 2 Holz → 3 Räucherfisch + 3 Nahrung.
- Der Händler kauft jetzt bis zu 10 Stück der Ware, deren Lager am vollsten ist; Stückpreise für alle Waren.
- **Dorfwünsche sind jetzt Lieferwünsche**: Sie nehmen Ware aus dem Lager und sind nie größer als das Lager. (Der Langlauf hatte eine Sackgasse gezeigt: Herstellungswünsche konnten bei vollem Lager nie erfüllt werden.)
- Speicherschema 5 (Sorte, nächste Sorte, Reifezeit); neue Waren starten in alten Ständen bei 0.
- Neue Gebäude nutzen vorläufig vorhandene Bilder mit eigenem Schild (Fisch, Kiste, Rauch) und Zusatzdetails (Netze, Kisten).
- Tests: neue Suite `phase2_test` (36 Prüfungen); Komplettdurchlauf baut Scheunen, Anglerhütte und Räucherkate und baut verschiedene Sorten an.

## 0.5.0 – Jahreszeiten und endloses Dorf (Phase 1 des Ausbauplans)

- **Jahreszeiten**: Frühling, Sommer, Herbst, Winter (je 3 Spieltage, weicher Übergang). Wachstum und Nachwachsen der Bäume hängen von der Jahreszeit ab (Winter langsam).
- **Jahreszeitliche Grafik**: Shader färben alle gemalten Bäume, Sträucher, Beete und (schwächer) Gebäude um – Blüten im Frühling, Herbstlaub, Schnee auf Kronen- und Dachkanten im Winter. Boden, Ufer und Wege wechseln mit (goldener Herbst, Schneedecke, gefrorener Teich). Wetterteilchen: Blütenblätter, Schmetterlinge, fallendes Laub, Schneefall. Waldlinge tragen im Winter Schals.
- **Kein Endlevel**: Dorfstufen ohne Obergrenze nach einer Formel (früh zügig, später langsamer). Bestehende Spielstände behalten ihre Stufe.
- **Endlose Dorfwünsche** nach den 14 Einführungsaufträgen, erzeugt aus dem, was das Dorf herstellt und bauen kann, mit wachsenden Belohnungen; ein Wunsch kann alle 2 Minuten getauscht werden.
- **Inhalte als Datentabelle**: Waren, Gebäude, Rezepte, Aufträge, Spezialisten, Naturpositionen, Jahreszeiten und Wunschvorlagen liegen in `scripts/data/content.gd`.
- Lageransicht nach Gruppen (Reiter „Lager“); Jahreszeit und Tag in der Kopfzeile; Erfahrungsbalken zeigt den Fortschritt der aktuellen Stufe.
- Wartende Waldlinge suchen sich freie Plätze statt übereinander zu stehen.
- Verdeckungs-Transparenz im Baumodus nur noch, wenn tatsächlich hinter Gebäuden gebaut wird.
- Speicherschema 4 (Wunsch, Wunschzähler; Stufen-Migration).
- Tests: neue Suite `endless_test` (23 Prüfungen); Komplettdurchlauf spielt nach der Einführung weiter und erfüllt 6 Dorfwünsche.

## 0.4.0 – Waldlinge bei der Arbeit

- Neues prozedurales 2D-Skelett für alle Waldlinge (8 Richtungen, 8 Gehphasen, bewegungsgekoppelt, über 20 Aktionsanimationen, Werkzeuge immer in derselben Hand).
- Bewohner-Aufgabensystem mit Reservierungen, Aktionsereignissen, Auszahlung genau bei Übergabe, sauberem Abbruch bei Abriss, Verschieben und Laden.
- 8-Nachbarn-Navigation mit Wegevorliebe, Pfadglättung, Erreichbarkeitsregionen und Cache.
- Waldbäume und Findlinge mit Bestand und Nachwachsen; Förster pflanzen; Beete brauchen Aussaat; Werkstätten brauchen Arbeiter und Rohstofftransport.
- 8 besondere Bewohnerhäuser mit benannten Waldlingen und Dorfeffekten.
- Renderer auf Y-sortierte Knoten umgestellt, Bodenebene gecacht, Verdeckungs-Transparenz, Statussymbole, Partikel, Textmeldungen.
- Gebäudeauswahl über das Bild; Waldlinge anklickbar; Reiter „Bewohner“.
- Beenden-Dialog (speichert), Strg+Q; Optionen mit drei Lautstärken; synthetisierte Arbeitsgeräusche.
- Speicherschema 3 mit Migration von 0.2/0.3 (geprüft mit echtem Spielstand); Sicherung von 0.3.1 unter `archive/0.3.1`.
- Behoben: Abklingzeiten wurden bei kleinen Zeitschritten nie null; überbaute Bewohner sprangen in die linke obere Kartenecke.
- Tests: neue Suiten `residents_test` und `campaign`, überarbeitete `runtime`; visuelle Werkzeuge `rig_sheet` und `qa`.

## 0.3.1 – Vollbild

- Start im randlosen Vollbild; F11 schaltet zurück ins Fenster.
- Anzeige füllt unterschiedliche Bildschirmformate ohne schwarze Balken.
- Kopfzeile, Seitenleisten und Statusleiste werden bei Größenänderungen neu positioniert.


## 0.3.0 – Waldleben

- Projekt aus Maniac nach `E:\Unternehmen\Spielerei\Mooswinkel` verlegt; 0.2-Quellprojekt archiviert.
- Neue KI-generierte, eigenständige gemalte Atlanten für 16 Bau-/Naturmotive und acht Waldling-Posen integriert; keine APK-Grafiken verwendet.
- Glattere Bodenfarben, dichterer Wald, Vögel, Laternenlicht und Glühwürmchen.
- Sieben zusätzliche Bauobjekte, drei zusätzliche Ressourcen, sieben zusätzliche Dorfaufträge.
- Ausbau, Produktionspause, Arbeitswege mit Anwesenheitsbonus, Nahrungsverbrauch, Handelsaufträge und zwei Gebietserweiterungen.
- Lückenloses Wegezeichnen mit der Maus, Vollbild, Seitenleisten ausblenden, Kamera zentrieren.
- Gespeicherte Anzeige-/Klangoptionen, Migration von Speicherformat 1 nach 2.
- Produktionszeit bei langen Frames in kleinen Simulationsschritten berechnet; Rundungsfehler an Ernte-/Produktionsgrenzen beseitigt.
- Automatisierte Modellprüfung: 223 bisherige + 67 neue Prüfungen; erweiterte Laufzeitprüfungen.
- Mausbedienung für Kategorieauswahl, Hausbau, Questbelohnung, Infos, Ernte und Handelslieferung kontrolliert.

## 0.2 – Kernversion

Isometrische Vektorgrafiken, automatische 4-Bit-Wege, Grundwirtschaft, sieben Quests, Bau-/Verschiebe-/Abrisssystem, A*-Wege und lokale Spielstände. Archiv im Projekt unter `archive/0.2`.

