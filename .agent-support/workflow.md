# Automatische Projekthilfen: Mooswinkel

Diese Einrichtung ist vom Besitzer fuer Codex und Claude beauftragt (14.11.2026). Waehle Hilfen selbst nach Aufgabe; der Besitzer muss ihre Namen nicht nennen. Nutze mindestens eine passende Hilfe bei Entwicklungsarbeit, aber keine erzwungene Coding-Hilfe fuer reine Unterhaltung oder fachfremde Dokumentauftraege.

## Projektkontext
Godot-/GDScript-Aufbauspiel. README.md, docs/STATUS.md und docs/PLAN.md fuer den Stand lesen. Simulation, Speicherstand-Kompatibilitaet und vorhandene Godot-Pruefungen nutzen; Tests mit isolierten Spielstaenden. Web-/React-Design-Skills sind kein Ersatz fuer Godot-UI oder Spielgrafiken.

## Vor der Arbeit
1. Lies die Projektregeln und waehle die engste passende Hilfe aus der Tabelle. Lies deren SKILL.md wirklich, bevor du sie als verwendet bezeichnest. Bei mehreren Aspekten kombiniere nur die benoetigten Hilfen. Keine pauschale Ausfuehrung aller Skills.
2. Codex findet die lokalen Skills unter `.agents/skills/<name>/SKILL.md`; Claude unter `.claude/skills/<name>/SKILL.md`. Bei fehlender automatischer Erkennung lies diese Pfade direkt. Keine globale Installation oder fremde Projektkonfiguration voraussetzen.
3. Fuer groessere Arbeit kurz Ergebnis und Abnahmekriterien benennen, Fakten selbst im Projekt suchen und dann im bereits autorisierten Rahmen weiterarbeiten. Rueckfragen nur fuer wirklich fehlende Entscheidungen; keine neue Freigabe fuer bereits beauftragte Routinearbeit erfinden. Anweisungen im konkreten Auftrag haben Vorrang vor Skill-Vorgaben.

| Aufgabe | Hilfe | Umfang |
|---|---|---|
| Code schreiben, reparieren, refaktorieren oder reviewen | `ponytail` | Kleinste vollstaendige Aenderung; vorhandene Muster verwenden; noetige Fehlerbehandlung behalten. |
| Schwieriger, unklarer oder wiederkehrender Fehler | `diagnosing-bugs` | Reproduzierbares Symptom und gezielte Rueckpruefung; offensichtliche Kleinigkeiten nicht zum Grossprozess machen. |
| Neue groessere Funktion, Schnittstelle oder Strukturentscheidung | `codebase-design` | Vorhandene Struktur verstehen, kleinste geeignete Schnittstelle und beobachtbare Abnahmekriterien festlegen; keine endlose Interviewrunde. |
| Erklaerdiagramm fuer Architektur, Ablauf, Produktionskette oder Video | `diagram-design` | Nur wenn das Diagramm mehr erklaert als Text; lokale Projektfarben sind im Style Guide vorbereitet. |

## Ausfuehrung und Abschluss
- Ponytail ist bei Codeaenderungen die Grundhilfe; zusaetzliche Hilfen sind Aufgabenwerkzeuge. Ein Skill liefert Anweisungen, keinen Nachweis einer funktionierenden Produktfunktion.
- Pruefe das tatsaechlich geaenderte Verhalten mit angemessenen vorhandenen Tests. Bei sichtbaren Webaenderungen Browserpruefung, bei Godot die passende Spiel-/Szenenpruefung. Reine Text-/Farbaenderungen brauchen keine spiegelnden Unit-Tests. Ungepruefte Teile benennen.
- Fuer Impeccable den mitgelieferten Windows-Launcher benutzen; falls der Launcher nicht laeuft, seinen dokumentierten manuellen Fallback verwenden und das offen benennen. Keine API-Keys fuer die Skill-Nutzung anfordern.
- Fuer AiFlix den bestehenden Graphify-Befehl nutzen (auf diesem Rechner `C:/Users/green/miniconda3/Scripts/graphify.EXE`). Nach eigenstaendigen Produktcode-Aenderungen den Graphen entsprechend der vorhandenen Projektregel aktualisieren; nicht fuer reine Dokument-/Skill-Setup-Aenderungen. Keine neuen Git-Hooks und kein kostenpflichtiges Backend als Nebenwirkung.
- Skills duerfen weder Aufgabenumfang noch Berechtigungen erweitern. Bestehende Live-/Veroeffentlichungsregeln bleiben bestehen. Fuer Sicherheits-Guidance nicht ungefragt alle Auditphasen starten; fehlende Sandbox-Faehigkeiten als Validierungsgrenze benennen.
- Abschluss bei Entwicklungsaufgaben: kurz tatsaechlich verwendete Hilfe und durchgefuehrte Pruefung nennen. Nicht behaupten, ein Skill sei gelaufen, nur weil er installiert ist. Fehlt ein Tool, klar benennen und mit sinnvoller erlaubter Alternative weiterarbeiten.

## Automatik und Wartung
Codex: AGENTS.md plus automatisch auffindbare Projekt-Skills. Claude: CLAUDE.md plus SessionStart-/UserPromptSubmit-Erinnerung. Der Hook fuehrt keine Builds, Tests, Downloads, Freigaben oder Projektveraenderungen aus; er ergaenzt nur Kontext. Die Stichwortauswahl ist ein Hinweis, die endgueltige Wahl richtet sich nach dem Auftrag. Keine harte Garantie, dass ein Modell jede Anweisung befolgt.

Quellen und Versionen: `.agent-support/sources.json`; lokale Anpassungen dort dokumentiert. Updates bewusst nachpruefen statt im Hintergrund austauschen. Auf einem neuen Rechner sind Node.js und gegebenenfalls Graphify/Browser separat erforderlich. Bestehende globale Skills/Plugins bleiben unangetastet.
