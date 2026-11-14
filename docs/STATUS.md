# Stand und offene Aufgaben – 0.7.0

**Entwicklungsfassung. Keine Vollversion.** Etappen A–D sind im Spiel umgesetzt und automatisiert geprüft; Etappe E (Wirtschaft, Inhalte, Oberfläche, Veröffentlichung) ist begonnen, aber nicht abgeschlossen.

## Etappen

| Etappe | Stand |
| --- | --- |
| A Bewohner mit überzeugendem Laufen | Umgesetzt: 2D-Skelett, 8 Richtungen, 8 Gehphasen, bewegungsgekoppelt, weiches Drehen, Ruhe/Umschauen/Sitzen, Y-Sortierung. Visuell geprüft über Kontaktbögen und Spielbilder. Feinschliff offen (s. u.). |
| B Holzabbau | Umgesetzt: Waldbäume mit Bestand, Arbeitsort am Baum, Ausrichten, Axt ziehen, 4 Schläge mit Splittern/Wackeln/Geräusch, Fällen, Stumpf → Setzling → Baum, Förster pflanzen nach, Holz erst bei Übergabe. |
| C Steinabbau und Ernte | Umgesetzt: Findlinge (nachwachsend) bzw. eigene Felswand, Spitzhacke mit Funken/Staub; Säen, Gießen, Sichelernte, Beerenpflücken mit Korb, Transport nach Hause. |
| D Warentransport und Werkstätten | Umgesetzt: Rohstoffe holen und bringen, Arbeit an Sägemühle, Kornmühle, Ofenstube, Imkerei, Marmeladenküche, Gasthaus mit eigenen Animationen; Produktion nur mit Arbeiter. |
| E Wirtschaft, Inhalte, Oberfläche, Veröffentlichung | Teilweise: 8 besondere Bewohnerhäuser, Optionen mit drei Lautstärken, Beenden-Dialog, Bildauswahl, Statussymbole, Bewohner-Infos. Offen: siehe Liste. |

## Neu auf Wunsch: besondere Bewohnerhäuser

Kategorie „Bewohner“, je Haus genau einmal baubar, jedes bringt einen bestimmten Waldling mit Effekt:
Birka (Holzmeisterin, +2 Holz/Gang) · Ilvi (Gärtnerin, Beete +20 %) · Kolbo (Steinkundiger, +2 Stein, Findlinge schneller) · Zimmerling (Baumeister, Ausbau −20 %) · Mehlwin (Bäcker, +1 Brot) · Summa (Imkerin, +1 Honig) · Salbei (Kräuterkundige, doppelte Erholung, −25 % Nahrung) · Taler (Händler, +30 % Verkauf, +20 % Auftragslohn).
Die Häuser nutzen vorerst das Wurzelhäuschen-Motiv mit eigenem Schild; eigene Hausgrafiken fehlen.

## Ausbauplan

Der weitere Ausbau folgt [PLAN.md](PLAN.md). Stand der Phasen:

| Phase | Stand |
| --- | --- |
| 1 Fundament | Erledigt (0.5/0.6): Inhaltsdaten ausgelagert, endlose Stufen, Lieferwünsche, Warteplätze, Lageransicht, Lagergrenzen und Vorratsscheune. Offen: Balance der Einführung (in ~22 Spielminuten durch). |
| Jahreszeiten-Grafik (aus Phase 8 vorgezogen) | Erledigt in 0.5. Offen: mehr Schnee auf Dächern, eigene Wintergrafik für Beete. |
| 2 Felder und Angeln | Erledigt in 0.6: 8 Sorten, überreif, Anglerhütte, Räucherkate. Offen: Angel-Minispiel (optional), mehrere Fischarten, eigene Bilder für Anglerhütte/Scheune/Räucherkate. |
| 3 Tiere | Erledigt in 0.7: Tier-Skelett mit 8 Arten, drei Gehege, Käserei, Wildtiere mit Ausweichen, Winterruhe und Klick-Bonus. Offen: Esel als Lastenträger, Hofhund, Scheren/Melken als eigene Animationen, Wolle/Milch weiterverarbeiten (Weberei folgt in Phase 4). |
| 4–9 | Noch nicht begonnen. Nächste Phase: 4 Rohstoffe und Metall. |

## Bekannte Fehler und Mängel

1. Wartende Waldlinge weichen jetzt aus; Träger können sich an Abladestellen kurz überlappen.
2. Einführung in ca. 22 Spielminuten durch; danach Stufen deutlich langsamer (Stufe 8 nach ca. 57 Minuten). Langzeitbalance offen.
3. Neue Gebäude (Anglerhütte, Vorratsscheune, Räucherkate) nutzen vorhandene Bilder mit Schild; eigene Grafiken fehlen. Feldfrüchte färben sich im Herbst mit dem Laub um.
4. Rechte Reiterleiste ist bei 4 Reitern knapp; kleine Bildschirme nicht geprüft.
5. Im Winter liegt auf Gebäudedächern nur wenig Schnee; im Schnee bleiben vereinzelt grünlich-graue Grasflecken.
6. Spezialisten-, Wildbaum- und Findlingsgrafik: Spezialisten nur durch Farbe/Schild unterscheidbar; Findlinge und Stümpfe sind Vektorgrafik und etwas flacher als die gemalten Gebäude.
7. Kein Zurück-Weg für Bewohner, die dauerhaft blockiert sind, außer Neuversuch; keine Benachrichtigung über die Statusleiste.
8. Nach dem Laden eines migrierten Standes kann die erste Statusmeldung von einer anderen Meldung überdeckt werden.

## Noch notwendig für eine Vollversion

1. Langzeitbalance mit menschlichen Spieltests; Erfahrungskurve, Kosten, Erträge, Lagergrenzen, Nachfrage.
2. Mehr Inhalte nach den 14 Aufträgen: weitere Produktionsketten, Ereignisse, Gebiete mit eigenem Charakter, Aufträge für die Spezialisten.
3. Eigene gemalte Grafiken für Spezialistenhäuser, Findlinge, Werkstatt-Requisiten; Rig-Feinschliff (Hände, Gesichtsausdruck, Übergänge zwischen Aktionen).
4. Ausweichen und Warteplätze für Bewohner; Anzeige „wer arbeitet wo“ in der Welt.
5. Einführung als geführtes Tutorial statt nur Hilfefenster; Kontexthilfe.
6. Leistungsmessung mit großem Dorf; ggf. Bewohner-Bilder vorrendern (SpriteFrames-Cache).
7. Hörprüfung, Musik.
8. Auflösungen/Schriftgrößen, UI-Skalierung.
9. Regulärer Export mit Templates, Installer, Signierung; danach Android/Touch.
