# Architektur – 0.4.0

## Überblick und Trennung

| Bereich | Datei | Verantwortung |
| --- | --- | --- |
| Wirtschaft / Welt | `scripts/village.gd` | Bauobjekte, Ressourcen, Belegung, Wege, Produktion, Aufträge, Handel, Spezialisten-Effekte, Speicherschema 3 und Migration |
| Bewohner-Aufgaben | `scripts/sim/residents.gd` | Zustände, Aufgabenwahl, Reservierungen, Aktionsereignisse, Warenübergabe, Abbruch, Speichern der Bewohner |
| Navigation | `scripts/sim/navigation.gd` | 8-Nachbarn-A* mit Binärheap, Wegevorliebe, Erreichbarkeitsregionen, Pfadglättung, Cache |
| Animations-Timing | `scripts/anim/anim_defs.gd` | Einzige Quelle für Bildanzahl, Bilddauer, Schrittzyklus und Ereignisbilder |
| Figur | `scripts/anim/woodling_rig.gd` | 2D-Skelett, Posen aller Aktionen, Projektion und Zeichnung |
| Darstellung | `scripts/view/world_view.gd`, `woodling_view.gd` | Ebenen, Y-Sortierung, Effekte, Statussymbole, Verdeckung, Bildauswahl |
| Klang | `scripts/audio/sfx.gd` | Synthetisierte Aktionsgeräusche und Atmosphäre, Busse „Ambience“ und „SFX“ |
| Spielhülle | `scripts/game.gd` | Oberfläche, Eingaben, Optionen, Speichern/Laden, Beenden |

Simulation und Navigation laufen ohne Renderer (headless testbar). Simulationsfunktionen sind statisch und halten ihren Zustand im Modell (keine Referenzzyklen).

## Bewohner: Zustände und Aufgaben

Ablauf: Ruht → sucht Aufgabe → geht zum Arbeitsplatz → richtet sich aus → arbeitet → trägt Waren → übergibt → ruht. Bei wenig Kraft geht ein Waldling nach Hause und sitzt (Ruheanimation).

Aufgaben sind Schrittlisten (`STEPS` in residents.gd), z. B. Holz: `go_work, draw, chop, stow, pickup, go_drop, putdown`. Weitere: Stein (Findling oder eigene Felswand), Pflanzen, Säen, Gießen, Korn ernten, Beeren pflücken, Waren holen, Werkstattarbeit, Ruhen, Leerlauf/Schlendern.

- **Arbeitsplätze**: Jede Werkstatt, Forsthütte und jeder Steinbruch hat so viele Plätze wie Ausbaustufen. Zuteilung automatisch, Spezialisten zuerst in ihr Handwerk. Pausieren gibt Plätze frei.
- **Helfer**: Waldlinge ohne Arbeitsplatz säen, gießen, ernten und tragen Körbe nach Hause.
- **Reservierungen** (`village.reserved`): Ziele (Baum, Felsen, Beet), Standzellen, Werkstatt-Holauftrag, Pflanzzelle. Sie werden beim Laden aus den Aufgaben neu aufgebaut, nicht gespeichert.
- **Arbeitsort**: begehbare Nachbarzelle des Ziels, Kameraseite bevorzugt (Arbeit bleibt sichtbar), Standpunkt 30–40 % zur Zielmitte gezogen, damit Werkzeug und Ziel sich berühren.
- **Änderungen der Welt** (`revision`): Bauen, Abriss, Verschieben, Ausbau, Pause und Laden erhöhen die Revision. Jeder Bewohner prüft dann Ziel, Standplatz und Weg; verschobene Ziele werden neu angelaufen, entfernte Ziele brechen die Aufgabe ab, überbaute Bewohner werden auf die nächste freie Zelle gesetzt.
- **Eingeschlossen**: Häuser ohne begehbaren Nachbarn markieren ihre Bewohner als eingeschlossen (Symbol „!“ am Haus, Hinweis im Infofeld); sie erscheinen, sobald ein Ausgang frei ist.
- **Blockiert**: Kein Weg zum Ziel → Aufgabe abgebrochen, Symbol „?“, neuer Versuch nach kurzer Wartezeit.

## Aktionsereignisse und Auszahlung

`anim_defs.gd` legt für jede Animation fest, an welchem Bild ein Ereignis stattfindet (Axt: Treffer an Bild 5; Ernte: Schnitt; Aufheben; Übergabe …). Die Simulation führt eine Animationsuhr pro Bewohner und meldet mit `events_between()` alle überschrittenen Ereignisse in Reihenfolge, auch wenn ein langer Zeitschritt mehrere Durchläufe überspringt. Die Darstellung wählt das Bild aus derselben Uhr. Dadurch stimmen Bild, Effekt und Spielregel bei Pause, 1×, 2× und 4× überein.

- Holz/Stein: Bestand des Ziels sinkt beim letzten Treffer, die Ladung wird getragen, **gutgeschrieben nur im Übergabe-Ereignis**.
- Ernte: Pflanzenzustand ändert sich erst beim letzten Schnitt bzw. Pflücken; Ertrag einmal im Korb, gutgeschrieben bei Übergabe.
- Werkstatt: Rohstoffe verlassen das Lager beim Aufheben, werden bei Übergabe zum Werkstattvorrat (`supply`), pro Zyklus genau einmal verbraucht. Produktion läuft nur, solange ein Waldling am Ort arbeitet.
- Abbruch (Abriss, Umzug, manuelle Ernte, Entfernen eines Bewohners): Reservierungen werden frei, getragene Waren genau einmal ins Lager gebucht (Rohstoffe zurück, Erzeugnisse geliefert).
- Speichern während einer Aktion speichert Schritt, Animationsuhr, Trefferzahl und Ladung; nach dem Laden geht es exakt dort weiter.

## Navigation

8-Nachbarn-A* (Diagonalen nur, wenn beide Nachbarn frei sind), Wege kosten 1,0, Wiese 1,8. Erreichbarkeitsregionen werden einmal pro Revision gefüllt, unerreichbare Ziele kosten daher keine Suche. Pfade werden geglättet (Linien bleiben auf freien Zellen, auf Wegen bleiben sie auf Wegen) und pro Revision zwischengespeichert. Das 4-Nachbarn-`route()` des Modells bleibt für bestehende Tests erhalten.

## Figur und Animation

Gewählt wurde ein **prozedurales 2D-Skelett** statt Einzelbildfolgen: Gelenke (Füße, Hüfte, Becken, Rumpf, Schultern, Ellbogen, Hände, Kopf) liegen in einem kleinen lokalen 3D-Raum und werden pro Blickrichtung isometrisch projiziert. Körperteile (Stiefel, Beine, Tunika, Blattumhang aus 12 Segmenten, Arme, Kopf mit Gesicht, Haar, Blattohren, Eichelkappe, Werkzeuge, Lasten) werden nach Tiefe sortiert gezeichnet. Beine und Arme nutzen Zwei-Knochen-IK.

Folgen: identische Proportionen, Kleidung und Fußpunkt in allen Richtungen; das Werkzeug bleibt immer in der rechten Hand (nichts wird gespiegelt); 8 Blickrichtungen mit weichem Drehen über Zwischenrichtungen (Drehrate begrenzt). Gehen: 8 Phasen pro Zyklus, Standfuß bewegt sich linear mit Körpergeschwindigkeit zurück, Phase aus zurückgelegter Bodenstrecke → keine rutschenden Füße bei Wege-/Wiesentempo, Tragen und 1×–4×. Arbeitsanimationen: je 8 Bilder mit unterschiedlichen Bilddauern (Ausholen langsam, Schlag schnell).

`woodling_view.gd` zeichnet nur neu, wenn sich Animation, Bild, Richtung, Last oder Werkzeug ändern.

## Darstellung

- `ground`: Gelände, Ufer, Wege, Beetflächen, Grenzlinie des Baulandes – nur bei Weltänderung neu gezeichnet.
- `water`: Wellen und Schilf, jedes Bild.
- `objects`: Y-sortierte Knoten für Gebäude, Natur, Spezialistenhäuser (mit Schild) und Bewohner.
- `overlay`: Bauvorschau, Auswahl, Arbeitsradius, Partikel, Textanzeigen „+8 Holz“, Nacht, Vögel.
- Verdeckende Gebäude/Bäume vor Auswahl oder Baucursor werden transparent.
- Statussymbole: „?“ kein Arbeiter, „…“ wartet auf Waren, „II“ pausiert, „!“ kein Weg/eingeschlossen.
- Auswahl per Bild: Klick auf Dach, Wand oder Baumkrone wählt das Objekt (vorderstes gewinnt).

## Speichern und Migration

Schema 3 im bisherigen Dateinamen `village_v1.json`. Neu: Gebäude-IDs, Aussaat/Gießen, Bestände von Bäumen/Felsen, Werkstattvorrat, Bewohner (Position, Blickrichtung, Aufgabe, Schritt, Animationsuhr, Ladung, Kraft, Spezialist). Validierung wie bisher in ein temporäres Modell; ungültige Bewohnerzeilen werden verworfen und neu erzeugt, statt das Dorf abzulehnen. Schema 1/2 werden übernommen: IDs werden vergeben, Wald und Findlinge nur an Stellen ergänzt, die nichts blockieren, die Eigenproduktion alter Forsthütten/Steinbrüche wird durch Arbeitsgänge ersetzt. Getestet mit dem echten 0.3-Spielstand (`tests/fixtures`).

## Skalierung

Boden wird gecacht, Bewohner zeichnen nur bei Bildwechsel, Pfade werden gecacht, Erreichbarkeit vorab bestimmt. Eine gemessene Leistungsabnahme für sehr große Dörfer steht noch aus (siehe STATUS).
