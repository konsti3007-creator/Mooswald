# Ausbauplan Mooswinkel – endloses Dorf

Stand: 14. November 2026, nach Version 0.4.0. Dieser Plan wird Phase für Phase umgesetzt; jede Phase endet mit einer spielbaren, getesteten Fassung.

## 1. Was die APK zeigt (nur Prinzipien, nichts übernommen)

Untersucht wurden Hilfeseite, Texte im Programmcode, Dateiformate und die Fortschrittstabelle. Es werden **keine** Namen, Texte, Werte, Grafiken, Musik oder Daten übernommen – nur allgemeine Spielideen, die wir eigenständig umsetzen.

| Beobachtung in der APK | Was wir daraus machen |
| --- | --- |
| Beete mit Sortenwahl: über ein Dutzend Pflanzen (Beeren, Gemüse, Knollen, Kürbisse, Kirschen …), je mit eigener Wachstumszeit, Kosten, Ertrag und Mindeststufe | Kornbeet wird zum **Beet mit Sortenwahl**, 12+ eigene Pflanzen |
| Reife Pflanzen verderben, wenn man sie so lange stehen lässt, wie sie zum Wachsen brauchten; eine Sorte verdirbt nie | Sanftere Variante: **überreif** halbiert den Ertrag, nichts geht ganz verloren |
| Anzahl Beete an Zahl der arbeitenden Bewohner gekoppelt; jede Pflanze bindet einen Bewohner, bis sie reif ist | Bei uns schon über die Helfer gelöst; Beetzahl bleibt frei |
| Bauern-Figur gibt Ertragsbonus, wenn ihr Haus direkt an Beete grenzt | **Nachbarschaftsboni** für Spezialistenhäuser (Ilvi, später weitere) |
| Benannte Spezialisten mit wiederkehrendem Bonus (Symbol über dem Kopf, antippen) | Spezialisten erhalten **kleine Aufgaben/Belohnungen** mit Abklingzeit |
| Mini-Spiele: Backen (mehrere Schwierigkeitsstufen), Angeln, Bergbau (Goldnuggets, Edelsteine) | **Angeln, Schürfen, Backen** als optionale kurze Geschicklichkeitsspiele |
| Kleine Tiere (Schnecken, Raupen, Eichhörnchen, Frösche, Vögel) laufen herum und geben beim Antippen Erfahrung | **Wildtiere** als Leben in der Welt, antippbar mit kleinem Bonus |
| Labor mit Tränken in mehreren Farben, Forschungsgeschichten | Grundlage für **Forschung** (bei uns Schule/Universität) |
| Erfahrungskurve mit 34 Stufen, am Anfang stark (≈ ×2,3 je Stufe), später flach (≈ ×1,14) | Unsere **endlose Kurve**: früh zügig, später langsam, aber nie zu Ende |
| Hauszahl pro Stufe begrenzt, Häuser ausbaubar, Brücken erschließen neues Land | **Gebietserweiterungen ohne Ende** (neue Lichtungen, Flussufer, Berge) |
| Freunde besuchen, Geschenke (online) | Offline-Ersatz: **Handel mit erfundenen Nachbardörfern** |
| Echtgeldwährung für Abkürzungen | Bleibt bei uns ausgeschlossen |

## 2. Kein Endlevel – Aufbau des Endlos-Spiels

1. **Unbegrenzte Dorfstufen**: Erfahrung je Stufe nach einer Formel statt einer Tabelle (früh schnell, später langsam, z. B. `100 · Stufe^1,55`). Jede Stufe bringt etwas: neues Gebäude, Rezept, Pflanze, Bauplatz oder Forschungspunkt.
2. **Dorfwünsche statt fester Auftragsliste**: Nach der Einführungskampagne erzeugt das Spiel laufend neue Wünsche aus dem aktuellen Dorf („12 Kürbisse für das Herbstfest“, „Baue eine zweite Schmiede“), Schwierigkeit wächst mit der Stufe. Immer 3 zur Auswahl, einer darf getauscht werden.
3. **Gebiete ohne Ende**: Die Karte wächst in Abschnitten (Lichtungen, Flussaue, Moor, Hügel, Bergwerk-Tal). Jeder Abschnitt hat eigene Natur und Rohstoffe. Spätere Abschnitte werden aus festen Bausteinen erzeugt.
4. **Meisterforschung**: Nach dem Forschungsbaum gibt es wiederholbare Meisterstufen (z. B. +2 % Ertrag je Stufe).
5. **Jahreszeiten und Ereignisse**: Frühling bis Winter verändern Wachstum, Fischfang, Tierprodukte; Ereignisse wie Markttag, Sturm, Wanderhändler, Erntefest.
6. **Dorfchronik und Auszeichnungen**: Sammlungen (alle Pflanzen geerntet, alle Fische gefangen), Dorfruf in Sternen.
7. **Wachsende Ansprüche**: Bewohner wünschen sich ab bestimmten Größen Kleidung, Werkzeuge, Bildung, Feste – dadurch braucht ein großes Dorf immer neue Ketten.

## 3. Natur und Rohstoffe

| Neue Natur | Liefert | Wer arbeitet |
| --- | --- | --- |
| Erzadern im Hügelland (Kupfer, Eisen, Zinn; selten Silber, Gold) | Erz | Bergleute |
| Lehmufer am Bach | Lehm | Lehmstecher |
| Sandbank | Sand | Sandsammler |
| Fischgründe in Teich, Bach, See | Fische (mehrere Arten, Jahreszeiten) | Angler |
| Pilzringe im Schatten | Pilze | Sammler |
| Kräuterwiesen | Kräuter | Kräuterkundige |
| Wilde Obstbäume, Haselsträucher | Äpfel, Nüsse | Sammler |
| Schilf am Ufer | Schilf (Dächer, Körbe) | Korbflechter |
| Kristallgrotte (spätes Gebiet) | Kristalle | Bergleute |

**Metalle und was daraus wird**: Holz → Holzkohle (Köhlerei); Erz + Holzkohle → Barren (Schmelze); Barren → Werkzeuge, Nägel, Beschläge (Schmiede); Silber/Gold → Schmuck (Goldschmied, teure Handelsware); Sand → Glas (Glashütte) für Laternen, Fenster, Gläser; Lehm → Ziegel und Krüge (Töpferei). Werkzeuge werden selbst zum Bedarf: Werkstätten arbeiten mit gutem Werkzeug schneller, Ausbauten brauchen Nägel und Ziegel.

## 4. Beete mit Sortenwahl

Beim Anlegen oder nach der Ernte wählt man die Sorte; die Helfer säen sie (Säen-, Gieß- und Ernteanimationen gibt es schon, je Pflanze eigene Pflanzenbilder):

Korn · Karotten · Zwiebeln · Kartoffeln · Kohl · Tomaten · Kürbisse · Erdbeeren · Flachs (→ Leinen) · Sonnenblumen (→ Öl) · Kräuter · Saatmohn/Linsen (Nahrung) · später Goldknolle (seltene Wertpflanze, eigener Name).

Je Sorte: Wachstumszeit (1–20 Minuten), Saatkosten, Ertrag, Erfahrung, Mindeststufe, Jahreszeit. Überreif nach der doppelten Wachstumszeit: halber Ertrag. Fruchtwechsel gibt einen kleinen Bonus.

## 5. Tiere

- **Wildtiere** (kein Nutzen außer Freude und kleinem Bonus beim Anklicken): Eichhörnchen, Igel, Schnecken, Raupen → Schmetterlinge, Frösche am Teich, Vögel, Rehe am Waldrand, springende Fische.
- **Hoftiere** (nur Produkte, niemand wird geschlachtet): Hühner → Eier, Schafe → Wolle, Ziegen → Milch → Käse, Esel → schnellere Transporte (tragen Lasten), Bienen (bereits Imkerei), Hofhund als Begleiter.
- Hoftiere brauchen Futter (Korn, Heu), Auslauf und eine Pflegekraft (Hirtin/Hirte). Eigene Bewegungen: grasen, laufen, schlafen, gemolken/geschoren werden – technisch ein **Vierbeiner-Rig** nach demselben Prinzip wie die Waldlinge.

## 6. Neue Berufe und Häuser

| Gebäude | Beruf | Herstellung | ab Stufe (Vorschlag) |
| --- | --- | --- | --- |
| **Anglerhütte** | Anglerin/Angler (wirft aus, wartet, holt ein) | Fische | 4 |
| Räucherkate | Räucherer | Fisch + Holz → Räucherfisch (Nahrung, Handel) | 6 |
| Hühnerhof | Hirtin | Korn → Eier | 5 |
| Schafweide + Scherhütte | Hirte | Futter → Wolle | 7 |
| Ziegenstall + Käserei | Käserin | Milch → Käse | 9 |
| Köhlerei | Köhler | Holz → Holzkohle | 8 |
| Bergwerk | Bergleute | Erz, Kristalle | 10 |
| Schmelze | Schmelzer | Erz + Kohle → Barren | 10 |
| Schmiede | Schmiedin | Barren → Werkzeug, Nägel | 11 |
| Goldschmiede | Goldschmied | Silber/Gold → Schmuck | 16 |
| Lehmgrube + Töpferei | Töpfer | Lehm → Ziegel, Krüge | 8 |
| Glashütte | Glasbläserin | Sand + Kohle → Glas | 12 |
| Weberei | Weber | Wolle/Flachs → Stoff | 12 |
| Schneiderei | Schneiderin | Stoff → Kleidung (Bewohnerwunsch) | 13 |
| Ölmühle | Müller | Sonnenblumen → Öl (Laternen, Küche) | 9 |
| Kräuterkate | Kräuterkundige | Kräuter → Heiltee, Salben | 7 |
| Konditorei | Konditor | Mehl + Eier + Beeren → Kuchen | 10 |
| Lagerhaus | Lagerist | Lagergrenzen erhöhen | 6 |
| Wagnerei | Wagner | Holz + Nägel → Handkarren (schnellere Träger) | 12 |
| Rathaus / Gemeindekasse | Kämmerer | Haushalt, Steuern, Kredite | 8 |
| Handelskontor + Bootssteg | Händler | Handel mit Nachbardörfern | 9 |
| Schule → Bibliothek → Universität → Akademie | Lehrer, Gelehrte | Forschung | 8 / 12 / 15 / 22 |

Weitere besondere Bewohnerhäuser (je ein benannter Waldling mit Effekt): Anglerin, Schmiedin, Hirtin, Gelehrter, Kämmerin.

## 7. Forschung: Schule, Universität, Akademie

- **Schule** (ab Stufe 8): Lehrkraft unterrichtet; erzeugt Wissen, verbraucht Papier (aus Holz/Leinen) und Tinte (Beeren).
- **Bibliothek** (ab 12): mehr Wissen, schaltet höhere Forschungen frei.
- **Universität** (ab 15): Gelehrte forschen an mehreren Themen gleichzeitig.
- **Akademie** (ab 22): Meisterforschungen ohne Ende.

Forschungszweige: Landwirtschaft (Sorten, Bewässerung, Fruchtwechsel) · Forst und Bergbau (Erzarten, tiefere Stollen, Nachpflanzen) · Handwerk (Rezepte, schnellere Werkstätten) · Tiere (Zucht, Futter) · Logistik (Karren, Wegebonus, Lager) · Finanzen (Zinsen, Kreditrahmen, Steuern) · Kultur (Feste, Zufriedenheit). Forschung läuft sichtbar: Bewohner sitzen an Pulten, lesen, schreiben.

## 8. Staatsfinanzen: Gemeindekasse und Schulden

- **Gemeindehaushalt**: Einnahmen (Verkäufe, Aufträge, Abgabe pro Haushalt nach Zufriedenheit) und Ausgaben (kleiner Unterhalt pro Gebäude, Löhne der Lehrkräfte, Zinsen). Tagesübersicht im Rathaus.
- **Kredite** bei der „Waldsparkasse“: drei Größen, Zins pro Spieltag, Laufzeit, automatische Tilgung. Kreditrahmen hängt von Einnahmen und Bonität ab.
- **Bonität**: pünktlich zahlen hebt sie, Verzug senkt sie. Bei Überschuldung: keine neuen Kredite, Zufriedenheit sinkt, Pfändung entbehrlicher Waren – **nie ein Spielende**.
- Forschung „Finanzen“ senkt Zinsen und erweitert den Rahmen; Schuldverschreibungen der Gemeinde als spätes Werkzeug.

## 9. Handel mit anderen Dörfern (offline)

- **Landkarte** mit 6–8 erfundenen Nachbardörfern (eigene Namen, eigener Charakter: Fischerdorf, Bergdorf, Weindorf ohne Wein, Marktstadt …).
- Jedes Dorf hat **Angebot und Nachfrage**; Preise ändern sich mit Menge und Jahreszeit.
- **Karawanen und Boote**: Händler bringen Waren hin (Reisezeit, sichtbar losziehend), kommen mit Münzen oder Tauschwaren zurück.
- **Beziehung** zu jedem Dorf: steigt mit Lieferungen, schaltet Sonderwaren, bessere Preise, Handelsrouten (wiederkehrende Lieferungen) frei.
- Aufträge der Nachbarn ersetzen und erweitern die heutigen Handelsaufträge.

## 10. Reihenfolge der Umsetzung

Jede Phase ist für sich spielbar, wird getestet (Regeltests, Komplettdurchlauf, Bildprüfung) und dokumentiert.

| Phase | Inhalt | Abnahme |
| --- | --- | --- |
| **1 Fundament** (✓ 0.5, Lagergrenzen offen) | Waren, Rezepte, Gebäude und Pflanzen als Datentabellen statt im Code; Lageransicht mit Kategorien; endlose Stufenkurve; generierte Dorfwünsche; Balance-Korrektur der 0.4; Warteplätze für Bewohner | Bot spielt 3 Stunden ohne Ende und ohne Sackgasse; Stufenzeiten im Zielkorridor |
| **2 Felder und Angeln** (✓ 0.6, Minispiel offen) | Beete mit Sortenwahl (8 Pflanzen), überreif, Anglerhütte mit Auswerfen/Drill-Animation, Fischarten, Räucherkate, Angel-Minispiel optional | Jede Sorte einmal gepflanzt/geerntet; Angler fängt sichtbar |
| **3 Tiere** (✓ 0.7, Esel/Hund offen) | Wildtiere; Vierbeiner-Rig; Hühnerhof, Schafweide, Ziegen/Käserei; Hirtenberuf | Tiere laufen, grasen, liefern Produkte; Sortierung mit Gebäuden korrekt |
| **4 Rohstoffe und Metall** | Hügelland-Gebiet; Erz, Lehm, Sand; Köhlerei, Bergwerk, Schmelze, Schmiede, Töpferei, Glashütte, Goldschmied; Werkzeug als Bedarf | Vollständige Kette Erz → Werkzeug im Spiel sichtbar |
| **5 Forschung** | Schule, Bibliothek, Universität, Akademie; Forschungsbaum; Meisterforschung | Forschung schaltet Inhalte frei; Bewohner forschen sichtbar |
| **6 Gemeindekasse** | Haushalt, Unterhalt, Abgaben, Kredite, Bonität, Überschuldung ohne Spielende | Bot nimmt Kredit, tilgt, gerät testweise in Verzug und erholt sich |
| **7 Nachbardörfer** | Landkarte, Kontor, Karawanen/Boote, Preise, Beziehungen, Handelsrouten | Handel über mehrere Spieltage stabil, keine Geldmaschine |
| **8 Endloser Inhalt** | Jahreszeiten (✓ 0.5 inkl. Grafik), Ereignisse, erzeugte Gebietsabschnitte, Chronik, weitere Spezialisten | Bot spielt 10 Stunden; Dorf wächst ohne Leerlauf |
| **9 Veröffentlichung** | Grafiken aller neuen Objekte, Leistung großer Dörfer, Tutorial je System, Installer; danach Android | Abnahme durch menschliche Spieltests |

## 11. Offene Entscheidungen

1. **Grafiken**: Für rund 30 neue Gebäude, 13 Pflanzen und 10 Tiere braucht es Bilder. Optionen: (a) KI-generierte Atlanten im bestehenden Stil (Prompt-Vorlage in ART.md), Erzeugung durch dich oder ein Bildwerkzeug; (b) im Code gezeichnet wie die Waldlinge (einheitlich, aber schlichter); (c) gemischt: Tiere und Pflanzen im Code, Gebäude als Atlas.
2. **Verderben**: Ertrag halbieren (Vorschlag) oder ganz verlieren wie im Vorbild?
3. **Unterhaltskosten** für Gebäude einführen? Ohne laufende Ausgaben sind Schulden kaum sinnvoll.
4. **Härte bei Überschuldung**: nur Einschränkungen (Vorschlag) oder auch Verlust von Gebäuden?
5. **Hoftiere** nur mit Produkten, ohne Schlachtung (Vorschlag)?
6. **Minispiele** (Angeln, Schürfen, Backen) gewünscht oder lieber alles automatisch?
