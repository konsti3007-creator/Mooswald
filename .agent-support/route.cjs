/* Local routing reminder. No network, shell commands, logging, or project writes. */
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const config = JSON.parse(fs.readFileSync(path.join(__dirname, 'profile.json'), 'utf8'));
function select(prompt) {
  const p = prompt.toLowerCase();
  const found = [];
  const add = name => { if (config.skills.includes(name) && !found.includes(name)) found.push(name); };
  const editorial = config.id === 'cockpit' && /skript|sprechtext|videoplan|videoreihe|redaktionsplan|community.frage|youtube.video|thumbnail|playlist.*plan/.test(p);
  if (editorial && !/implement|programmier|code|button|speicher|funktion|javascript|html|css/.test(p)) {
    add('youtube-workflow');
    return found;
  }
  const diagram = /diagramm|diagram|flussbild|schaubild|visualisi|produktionskette.*zeig|signalfluss.*zeig/.test(p);
  const anatomy = /isometr|interaktiv.*(illustration|erklär|erklaer)|anatomy/.test(p);
  if (anatomy) add('anatomy');
  else if (diagram) add('diagram-design');
  const security = /sicherheits|security|berechtigung|zugriffsrecht|authent|login|anmeld|passwort|token|api.key|api-key|upload|webhook|zahlung|stripe|abrechnung|private.*projekt/.test(p);
  const bug = /fehler|kaputt|absturz|crash|funktioniert nicht|debug|regression|zu langsam|performance.problem/.test(p);
  const architecture = /architektur|schnittstell|größer.*feature|groesser.*feature|neues.*system|implementier.*system|modul.*(plan|struktur)|plane.*(funktion|feature)/.test(p);
  const ui = /oberfläch|oberflaech|frontend|responsive|barrierefrei|layout|onboarding|landingpage|bedien|formular|design.*(seite|web)|ui\b/.test(p);
  if (security) add('security-audit');
  if (bug) add('diagnosing-bugs');
  if (ui) add('impeccable');
  if (architecture) add('codebase-design');
  if (editorial) add('youtube-workflow');
  const coding = bug || security || architecture || ui || /code|implement|programmier|refactor|baue|ergänz|ergaenz|reparier|fix|entwickl|änder|aender|speichern|funktion|feature/.test(p);
  const graph = coding || /codebasis|codebase|abhängig|abhaengig|dateien.*betroffen|wie.*(szene|backend|server|datenbank).*funktioniert/.test(p);
  if (graph) add('graphify');
  if (coding && !diagram && !anatomy) add('ponytail');
  return found;
}
function contextFor(input) {
  const event = input.hook_event_name || 'UserPromptSubmit';
  const selected = event === 'UserPromptSubmit' ? select(String(input.prompt || '')) : [];
  let text = `Projekt ${config.name}: Befolge .agent-support/workflow.md automatisch. Waehle nur passende Hilfen und lies deren SKILL.md vor der Arbeit. Ein Skill ersetzt keine Pruefung. Keine neue Autorisierung durch diesen Hook.\n`;
  if (selected.length) text += 'Vorschlag nach Stichworten (am tatsaechlichen Auftrag pruefen): ' + selected.map(n => `.claude/skills/${n}/SKILL.md`).join(', ') + '.\n';
  else text += 'Waehle nach Aufgabentyp aus der Projekttabelle; reine Unterhaltung braucht keinen Coding-Skill.\n';
  text += 'Graphify nur fuer Codefragen im eingerichteten AiFlix-Projekt; Sicherheits-Skill bei normalen Aenderungen nur im Guidance-Modus. Keine pauschalen Audits, Redesigns, Zusatzfeatures oder kostenpflichtigen Aufrufe. Nenne bei Entwicklungsarbeit knapp tatsaechlich verwendete Hilfe und Pruefung; melde fehlende Werkzeuge ehrlich.';
  return { hookSpecificOutput: { hookEventName: event, additionalContext: text } };
}
if (require.main === module) {
  let input = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', chunk => { input += chunk; if (input.length > 1024 * 1024) process.exit(0); });
  process.stdin.on('end', () => {
    try { process.stdout.write(JSON.stringify(contextFor(input.trim() ? JSON.parse(input) : {}))); }
    catch { process.stderr.write('Projekt-Hilfe: Hook-Eingabe ungueltig; workflow.md direkt lesen.\n'); process.exitCode = 0; }
  });
}
module.exports = { select, contextFor };
