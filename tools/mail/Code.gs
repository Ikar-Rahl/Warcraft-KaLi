/**
 * The KaLi addons' bug reports by mail, filed as GitHub issues and kept in step both ways (Ikar 2026-11-24: "Can we
 * have a mail maybe instead? Can it be processed? A gmail for kali?", then "Do all the work"). For players without a
 * GitHub account. It runs in the KaLi Gmail account, as a Google Apps Script, every five minutes:
 *
 * - a new mail holding one of the keywords of a kind (a bug, a proposal, a question, in the four languages the
 *   addons speak), or a report pasted from the game, becomes an issue labelled "by mail" and its kind's label, and its
 *   sender gets the issue's link (Ikar: "for issue, let's make a filter of keywords like bugreport, proposal, issue
 *   etc."). The sender's address never goes to GitHub, nor any address the mail holds; the mail's attachments stay in
 *   Gmail, the issue saying how many;
 * - Gmail sorts them: a mail sent on to GitHub goes into the "GitHub" folder, out of the inbox, under the issue's own
 *   labels, "GitHub/bug", "GitHub/KaLi Quest", "GitHub/in French"... ("the mails that were forwarded should be put in
 *   a separate folder. Also, the labels in the Mail should match"); the others stay in the inbox under "No issue" ("so
 *   I can see the mail that got no GitHub issues"). One of those given a kind's label by hand, and an addon's if need
 *   be, is filed at the next run, so;
 * - the addon is found by itself, from a pasted report, its name or command, or the words of its features; the
 *   issue's labels say it, the mail's language and its attachments ("it should try to auto detect the addon and make
 *   good use of labels, as much as possible"), and "GitHub/closed" while the issue is closed;
 * - the sender's replies in the thread are added to the issue; the issue's comments, and its closing, are mailed to
 *   the sender in the same thread (Ikar: "And yes both ways").
 *
 * Setup, tests and limits: tools/mail/README.md. The offline test, tools/mail/test.js, runs this file on a fake Gmail
 * and a fake GitHub.
 */

const REPO = 'Ikar-Rahl/Warcraft-KaLi';
const ISSUE_LABEL = 'by mail';
// Gmail: a mail sent on to GitHub goes into this folder, out of the inbox, under the issue's own labels; one that
// isn't stays in the inbox under No issue.
const FOLDER = 'GitHub';
const NO_ISSUE = 'No issue';
// Each kind: the repository's label, and its keywords, looked for in the subject first, then in the
// text, the kinds in this order. A pasted report is a bug.
const KINDS = [
  {
    github: 'bug', words: [
      /\bbug(s|report|reports)?\b/i, /\bissues?\b/i, /\bproblems?\b/i, /\berrors?\b/i, /\bcrash(es|ed)?\b/i,
      /\bbroken\b/i, /\b(doesn'?t|does not|not|won'?t) work/i, /\bdoes nothing\b/i,
      /\bbogues?\b/i, /\bprobl[eè]mes?\b/i, /\berreurs?\b/i, /\bplant(e|age|ages)\b/i, /\bcass[ée]/i,
      /\bne (marche|fonctionne) (pas|plus)\b/i, /\bne fait rien\b/i,
      /\bfehler\b/i, /\babsturz\b/i, /\bstürzt\b/i, /\bfunktioniert nicht\b/i, /\bkaputt\b/i, /\btut nichts\b/i,
      /\bfallos?\b/i, /\bincidencias?\b/i, /\bno funciona\b/i, /\bno hace nada\b/i,
    ],
  },
  {
    github: 'enhancement', words: [
      /\bproposals?\b/i, /\bsuggestions?\b/i, /\bideas?\b/i, /\bfeature requests?\b/i, /\brequests?\b/i,
      /\b(please|could you|can you) add\b/i,
      /\bpropositions?\b/i, /\bid[ée]es?\b/i, /\bdemandes?\b/i, /\bsouhaits?\b/i, /\bfonctionnalit[ée]s?/i,
      /\bvorschl[äa]ge?\b/i, /\bideen?\b/i, /\bw[üu]nsche?\b/i,
      /\bpropuestas?\b/i, /\bsugerencias?\b/i, /\bpeticion(es)?\b/i, /\bpetición\b/i, /\bsolicitud(es)?\b/i,
    ],
  },
  {
    github: 'question', words: [
      /\bquestions?\b/i, /\bhow (do|can|to)\b/i, /\bhelp\b/i,
      /\bcomment (faire|on|je)\b/i, /\baide\b/i,
      /\bfragen?\b/i, /\bwie (kann|geht)\b/i, /\bhilfe\b/i,
      /\bpreguntas?\b/i, /\bc[oó]mo\b/i, /\bayuda\b/i,
    ],
  },
];
// In every comment this script writes, so the comments mailed to the sender are the others.
const MARK = '<!-- kali-mail -->';
// GitHub takes 65,536 characters in an issue or a comment.
const MAX_CHARS = 60000;
// A pasted report's first line, as shared/addon/Report.lua writes it.
const REPORT = /^(KaLi (?:Quest|Recipe|HUD)) bug report, \d{4}-\d\d-\d\d/m;
// Each addon, found by itself as much as can be (Ikar: "it should try to auto detect the addon and make good use of
// labels, as much as possible"): its names and its command, then the words of its own features in the four languages.
// The addons named are labelled, the one with the most of its words first; with none named, the one the words point
// to alone. A pasted report names its addon for sure. Its label, the same on GitHub and in Gmail's folder.
const ADDONS = [
  {
    title: 'KaLi Quest', github: 'KaLi Quest',
    names: [/\bkali[\s-]*quests?\b/i, /(^|\s)\/kq\b/i],
    words: [/\bquests?\b/i, /\btracker\b/i, /\bobjectives?\b/i, /\bjournal\b/i, /\bquest ?log\b/i,
      /\bqu[êe]tes?\b/i, /\bsuivi\b/i, /\bobjectifs?\b/i,
      /\bquestverfolgung\b/i, /\bziele?\b/i, /\bquestlog\b/i,
      /\bmisi(ón|on|ones)\b/i, /\bseguimiento\b/i, /\bobjetivos?\b/i],
  },
  {
    title: 'KaLi Recipe', github: 'KaLi Recipe',
    names: [/\bkali[\s-]*recipes?\b/i, /(^|\s)\/kr\b/i],
    words: [/\brecipes?\b/i, /\breceipts?\b/i, /\bnotebook\b/i, /\bprofessions?\b/i, /\bvendors?\b/i, /\btrainers?\b/i,
      /\bauction house\b/i, /\brecettes?\b/i, /\bcarnet\b/i, /\bm[ée]tiers?\b/i, /\bmarchands?\b/i,
      /\bh[ôo]tel des ventes\b/i, /\brezepte?\b/i, /\bnotizbuch\b/i, /\bberufe?\b/i, /\bh[äa]ndler\b/i,
      /\bauktionshaus\b/i, /\brecetas?\b/i, /\bcuaderno\b/i, /\bprofesi(ón|on|ones)\b/i, /\bvendedor(es)?\b/i,
      /\bcasa de subastas\b/i],
  },
  {
    title: 'KaLi HUD', github: 'KaLi HUD',
    names: [/\bkali[\s-]*hud\b/i, /(^|\s)\/kh\b/i],
    words: [/\bhud\b/i, /\bplate\b/i, /\bminimap\b/i, /\binfo ?bar\b/i, /\baction ?bars?\b/i, /\bfolders?\b/i,
      /\bmacros?\b/i, /\bcartouches?\b/i, /\bedit mode\b/i, /\bplaque\b/i, /\bminicarte\b/i, /\bbarre d'infos?\b/i,
      /\bdossiers?\b/i, /\bmode [ée]dition\b/i, /\bminikarte\b/i, /\binfoleiste\b/i, /\baktionsleisten?\b/i,
      /\bordner\b/i, /\bbearbeitungsmodus\b/i, /\bminimapa\b/i, /\bbarra de informaci(ón|on)\b/i,
      /\bcarpetas?\b/i, /\bmodo de edici(ón|on)\b/i],
  },
];
// The mail's language, from its most common small words, for a label saying which to answer in; none when unsure.
const LANGUAGES = [
  { github: 'in English', words: ['the', 'and', 'is', 'are', 'was', 'with', 'not', 'my', 'your', 'you', 'when', 'this',
    'but', 'it', 'i', 'to', 'of', 'for', 'or', 'after', 'have', 'does', 'can', 'what', 'from', 'would', 'be'] },
  { github: 'in French', words: ['le', 'les', 'est', 'pas', 'avec', 'je', 'une', 'des', 'et', 'quand', 'mais', 'dans',
    'du', 'sur', 'il', 'ne', 'mon', 'ma', 'mes', 'vous', 'pour', 'qui'] },
  { github: 'in German', words: ['der', 'die', 'das', 'und', 'ist', 'nicht', 'mit', 'ich', 'ein', 'eine', 'auf', 'wenn',
    'bei', 'es', 'mein', 'meine', 'sich', 'auch', 'wird', 'kann', 'nach'] },
  { github: 'in Spanish', words: ['el', 'los', 'las', 'y', 'con', 'pero', 'una', 'por', 'cuando', 'mi', 'está', 'del',
    'al', 'lo', 'se', 'mis', 'tu', 'para', 'muy', 'también'] },
];
// The pasted report's status line: the addon, its version, the client's language (Commands.lua's statusText).
const STATUS = /^(KaLi (?:Quest|Recipe|HUD)) (\d[\w.-]*), client [^\n]*?, interface \d+, ([a-z]{2}[A-Z]{2})\b/m;
const CLIENTS = { enUS: 'in English', enGB: 'in English', frFR: 'in French', deDE: 'in German', esES: 'in Spanish',
  esMX: 'in Spanish' };
// What a subject says nothing with: the kinds, greetings, small words, the addons' names and commands.
const EMPTY_WORDS = new Set(['bug', 'bugs', 'report', 'reports', 'bugreport', 'problem', 'problems', 'issue',
  'issues', 'error', 'errors', 'help', 'question', 'questions', 'idea', 'ideas', 'suggestion', 'proposal', 'feedback',
  'test', 'hello', 'hi', 'rapport', 'bogue', 'problème', 'probleme', 'erreur', 'aide', 'idée', 'idee', 'retour',
  'bonjour', 'salut', 'fehler', 'frage', 'hilfe', 'vorschlag', 'bericht', 'hallo', 'informe', 'problema', 'ayuda',
  'pregunta', 'sugerencia', 'hola', 'addon', 'add', 'on', 'mod', 'wow', 'a', 'an', 'the', 'my', 'le', 'la', 'un',
  'une', 'mon', 'ein', 'eine', 'el', 'una', 'mi', 'de', 'du', 'des', 'of', 'in', 'with', 'for', 'and', 'et', 'und',
  'y', 'kali', 'quest', 'recipe', 'hud', 'kq', 'kr', 'kh']);
const GREETING = /^(hello|hi|hey|dear \S+|bonjour|salut|hallo|guten tag|hola|buenos d[ií]as)\b[\s,!.:-]*/i;
const ATTACHED = 'attachments in mail';
// In Gmail's folder only: GitHub has the issue's state.
const CLOSED = 'closed';
// The repository's labels this script adds beyond bug, enhancement and question, made by setup() when missing.
const GITHUB_LABELS = {
  [ISSUE_LABEL]: ['c5def5', "Reported by mail, through KaLi's mailbox (tools/mail)"],
  'KaLi Quest': ['1d76db', 'About KaLi Quest'],
  'KaLi Recipe': ['0e8a16', 'About KaLi Recipe'],
  'KaLi HUD': ['5319e7', 'About KaLi HUD'],
  'in English': ['ededed', 'Mailed in English: answer in it'],
  'in French': ['ededed', 'Mailed in French: answer in it'],
  'in German': ['ededed', 'Mailed in German: answer in it'],
  'in Spanish': ['ededed', 'Mailed in Spanish: answer in it'],
  [ATTACHED]: ['fbca04', "The mail holds attachments, kept private in KaLi's Gmail"],
};
const EMAIL = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g;
// Where a reply's quote of the earlier mails begins: "On … wrote:", in the languages the addons speak, and Outlook's.
const QUOTE_END = /(wrote|a écrit|schrieb|escribió)\s*:\s*$/i;
const QUOTE_START = /^(On|Le|Am|El)\s/;
const ORIGINAL = /^\s*(-{2,}\s*(Original Message|Message d'origine|Ursprüngliche Nachricht|Mensaje original)|_{10,})/i;

// Once, by hand, from the script editor: checks the token, makes the labels, starts the five-minute run.
function setup() {
  const repo = github('get', `/repos/${REPO}`);
  Logger.log(`GitHub: ${repo.full_name}, the token works.`);
  const tags = [...KINDS.map((k) => k.github), ...ADDONS.map((a) => a.github), ...LANGUAGES.map((l) => l.github),
    ATTACHED, CLOSED];
  for (const name of [NO_ISSUE, FOLDER, ...tags.map(inFolder)]) gmailLabel(name);
  const existing = github('get', `/repos/${REPO}/labels?per_page=100`).map((l) => l.name);
  for (const [name, [color, description]] of Object.entries(GITHUB_LABELS)) {
    if (!existing.includes(name)) github('post', `/repos/${REPO}/labels`, { name, color, description });
  }
  for (const trigger of ScriptApp.getProjectTriggers()) {
    if (trigger.getHandlerFunction() === 'run') ScriptApp.deleteTrigger(trigger);
  }
  ScriptApp.newTrigger('run').timeBased().everyMinutes(5).create();
  // A second, every hour, in case Google stops firing the first: it did on 2026-11-24, the trigger still listed with
  // no error and no run after 21:24 (Ikar: "add a secondary, just in case"). The lock keeps the two from overlapping.
  ScriptApp.newTrigger('run').timeBased().everyHours(1).create();
  const props = PropertiesService.getScriptProperties();
  if (!props.getProperty('since')) props.setProperty('since', new Date().toISOString());
  if (!props.getProperty('start')) props.setProperty('start', String(Date.now()));
  Logger.log('Labels made, and run() every five minutes, and every hour in case the first stops.');
}

// Every five minutes. One run at a time; a failure (an expired token) is mailed to the account by Google.
function run() {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(1000)) return;
  try {
    fileNewMail();
    addReplies();
    mailAnswers();
  } finally {
    lock.releaseLock();
  }
}

// The threads of the last 30 days not filed yet. Which are filed is kept in the script's properties, and the labels
// are read from each thread, never through Gmail's search, so a label's name can be anything.
// Only what came after the mailbox was started: what the account held before is not a player's.
function fileNewMail() {
  const props = PropertiesService.getScriptProperties();
  if (!props.getProperty('start')) props.setProperty('start', String(Date.now()));
  const start = Number(props.getProperty('start'));
  for (const thread of GmailApp.search('newer_than:30d', 0, 100)) {
    if (load(`t:${thread.getId()}`)) continue;
    const first = thread.getMessages().find((m) => fromSender(m));
    if (!first || first.getDate().getTime() < start) continue;
    const labels = thread.getLabels().map((l) => l.getName());
    // A kind and addons given by hand, in the GitHub folder's labels, win over what the mail says; given to a mail
    // out of the inbox too. Otherwise only the inbox's mails are read: one Ikar archived is left alone.
    const given = KINDS.find((k) => labels.includes(inFolder(k.github)));
    if (!given && !thread.isInInbox()) continue;
    const subject = (thread.getFirstMessageSubject() || '').trim();
    const text = clean(first.getPlainBody());
    const kind = given || (labels.includes(NO_ISSUE) ? null : kindOf(subject, text));
    if (!kind) {
      if (!labels.includes(NO_ISSUE)) thread.addLabel(gmailLabel(NO_ISSUE));
      continue;
    }
    const byHand = ADDONS.filter((a) => labels.includes(inFolder(a.github)));
    const addons = byHand.length ? byHand : addonsOf(subject, text);
    const language = languageOf(proseOf(text)) || clientLanguage(text);
    const tags = [kind.github, ...addons.map((a) => a.github), ...(language ? [language] : []),
      ...(first.getAttachments().length ? [ATTACHED] : [])];
    const issue = github('post', `/repos/${REPO}/issues`, {
      title: titleOf(addons, subject, text),
      body: `${MARK}\nSent by mail on ${day(first.getDate())}; the sender's address stays private.\n\n` +
        cut(publish(text) + attachments(first)),
      labels: [ISSUE_LABEL, ...tags],
    });
    save(`t:${thread.getId()}`, { n: issue.number, last: first.getDate().getTime() });
    save(`i:${issue.number}`, { t: thread.getId(), c: 0, closed: false, lang: language });
    // Into the GitHub folder, under the issue's own labels ("the mails that were forwarded should be put in a separate
    // folder. Also, the labels in the Mail should match"), out of the inbox.
    for (const name of [FOLDER, ...tags.map(inFolder)]) thread.addLabel(gmailLabel(name));
    if (labels.includes(NO_ISSUE)) thread.removeLabel(gmailLabel(NO_ISSUE));
    first.reply(filedReply(issue, language));
    thread.moveToArchive();
  }
}

// A Gmail label by its name, made when missing: a new one in the lists needs no new setup().
function gmailLabel(name) {
  return GmailApp.getUserLabelByName(name) || GmailApp.createLabel(name);
}

function inFolder(name) {
  return `${FOLDER}/${name}`;
}

function addReplies() {
  const threads = GmailApp.search('newer_than:30d', 0, 100);
  for (const thread of threads) {
    const key = `t:${thread.getId()}`;
    const known = load(key);
    if (!known) continue;
    let added = false;
    let gone = false;
    for (const message of thread.getMessages()) {
      const at = message.getDate().getTime();
      // The sender's replies, and Ikar's own answers written from this account rather than on GitHub (Ikar 2026-11-24:
      // "Yes" to copying them into the issue); never the script's own mails. An answer of Ikar's is already in the
      // sender's mailbox, and its comment carries MARK, so it isn't mailed to them again.
      const ikar = !fromSender(message) && byIkar(message);
      if (at <= known.last || !(fromSender(message) || ikar)) continue;
      const text = clean(message.getPlainBody());
      if (text || message.getAttachments().length) {
        const said = ikar ? 'Answered by mail' : 'Reply by mail';
        gone = !github('post', `/repos/${REPO}/issues/${known.n}/comments`, {
          body: cut(`${MARK}\n${said} on ${day(message.getDate())}:\n\n${publish(text)}${attachments(message)}`),
        }, true);
        if (gone) break;
      }
      known.last = at;
      save(key, known);
      added = true;
    }
    // A reply brings its thread back to the inbox; once on GitHub, it goes back to the folder.
    if (gone) forget(thread, known.n);
    else if (added) thread.moveToArchive();
  }
}

// An issue deleted on GitHub, its sender writing again: the thread is forgotten, out of the GitHub folder and back in
// the inbox under No issue, for Ikar to read. Without it, each run failed on the comment GitHub refused.
function forget(thread, n) {
  const props = PropertiesService.getScriptProperties();
  props.deleteProperty(`t:${thread.getId()}`);
  props.deleteProperty(`i:${n}`);
  for (const label of thread.getLabels()) {
    const name = label.getName();
    if (name === FOLDER || name.startsWith(`${FOLDER}/`)) thread.removeLabel(label);
  }
  thread.addLabel(gmailLabel(NO_ISSUE));
  thread.moveToInbox();
}

function mailAnswers() {
  const props = PropertiesService.getScriptProperties();
  const started = new Date();
  // Ten minutes back from the last run: a change GitHub lists late is still seen; the comment ids keep each one once.
  const since = new Date(new Date(props.getProperty('since') || started).getTime() - 10 * 60 * 1000).toISOString();
  const issues = github('get', `/repos/${REPO}/issues?labels=${encodeURIComponent(ISSUE_LABEL)}&state=all` +
    `&since=${encodeURIComponent(since)}&per_page=100`);
  for (const issue of issues) {
    const key = `i:${issue.number}`;
    const known = load(key);
    if (!known) continue;
    const thread = GmailApp.getThreadById(known.t);
    const sender = thread && lastFromSender(thread);
    if (!sender) continue;
    const comments = github('get', `/repos/${REPO}/issues/${issue.number}/comments?since=${encodeURIComponent(since)}` +
      '&per_page=100');
    for (const comment of comments) {
      if (comment.id <= known.c) continue;
      if (!String(comment.body || '').includes(MARK)) {
        sender.reply(answerReply(comment, issue.number, known.lang));
      }
      known.c = comment.id;
    }
    const closed = issue.state === 'closed';
    if (closed !== known.closed) {
      if (closed) sender.reply(closedReply(issue, known.lang));
      // In Gmail too: what is done, under GitHub/closed, until the issue is opened again.
      const label = gmailLabel(inFolder(CLOSED));
      if (closed) thread.addLabel(label);
      else thread.removeLabel(label);
      known.closed = closed;
    }
    save(key, known);
  }
  props.setProperty('since', started.toISOString());
}

// What can't come from the sender: this account's own mails, and automatic ones (an absence reply, a bounce).
// Also no machine's mail: a no-reply sender, a notification, a list or a newsletter. Google's own mail to the new
// account, its "recovery contact request", was filed as a proposal on 2026-11-24 (issue #1).
const MACHINE = /no-?reply|do-?not-?reply|mailer-daemon|postmaster|notifications?@|@accounts\.google\.com/i;
function fromSender(message) {
  const from = String(message.getFrom()).toLowerCase();
  const me = String(Session.getEffectiveUser().getEmail()).toLowerCase();
  const auto = String(message.getHeader('Auto-Submitted') || 'no').toLowerCase();
  const bulk = /bulk|list|junk/i.test(message.getHeader('Precedence') || '') || !!message.getHeader('List-Unsubscribe');
  return !from.includes(me) && auto === 'no' && !bulk && !MACHINE.test(from);
}

// A mail of this account's that the script didn't write: Ikar answering from Gmail. The script's own open one of these
// ways, in each language (filedReply, answerReply, closedReply); the first ones held the four languages, English first,
// and said "Your report is" before the 24th's wording. A test holds each reply of SAY against them.
const SCRIPT_OPENINGS = [
  /^Thank you\. Your (mail is now|report is) issue #\d+/, /^\S+ on GitHub, issue #\d+:/, /^Issue #\d+ is closed:/,
  /^Merci\. Votre message est devenu le ticket n°\s?\d+/, /^\S+ sur GitHub, ticket n°\s?\d+\s?:/,
  /^Le ticket n°\s?\d+ est fermé\s?:/,
  /^Danke\. Eure Mail ist jetzt das Issue Nr\.\s?\d+/, /^\S+ auf GitHub, Issue Nr\.\s?\d+:/,
  /^Das Issue Nr\.\s?\d+ ist geschlossen:/,
  /^Gracias\. Tu correo es ahora la incidencia n\.º\s?\d+/, /^\S+ en GitHub, incidencia n\.º\s?\d+:/,
  /^La incidencia n\.º\s?\d+ está cerrada:/,
];
function isScriptMail(body) {
  const first = String(body).trim().split('\n')[0];
  return SCRIPT_OPENINGS.some((opening) => opening.test(first));
}

function byIkar(message) {
  const from = String(message.getFrom()).toLowerCase();
  const me = String(Session.getEffectiveUser().getEmail()).toLowerCase();
  return from.includes(me) && !isScriptMail(message.getPlainBody());
}

function lastFromSender(thread) {
  const messages = thread.getMessages().filter((m) => fromSender(m));
  return messages[messages.length - 1];
}

// An addon's name as players write it after "KaLi": its word in the four languages, or one a letter or two off from
// it, its first three letters right, as "kali receip" (Ikar 2026-11-24: "it did not detect kali receipt"). HUD, too
// short to tell, only as it is.
const SPELLINGS = {
  'KaLi Quest': ['quest', 'quete', 'quête', 'mision', 'misión'],
  'KaLi Recipe': ['recipe', 'receipt', 'recette', 'rezept', 'receta'],
  'KaLi HUD': ['hud'],
};
function namedAfterKali(text) {
  const named = new Set();
  for (const m of String(text).matchAll(/\bkali[\s-]*(\p{L}+)/giu)) {
    const word = m[1].toLowerCase().replace(/s$/, '');
    for (const [title, words] of Object.entries(SPELLINGS)) {
      if (words.some((w) => word === w || (w.length >= 5 && word.length >= 4 && word.slice(0, 3) === w.slice(0, 3)
        && distance(word, w) <= 2))) named.add(title);
    }
  }
  return named;
}

// How many letters to add, take off or change to make one word the other.
function distance(a, b) {
  let row = Array.from({ length: b.length + 1 }, (_, j) => j);
  for (let i = 1; i <= a.length; i++) {
    const next = [i];
    for (let j = 1; j <= b.length; j++) {
      next[j] = Math.min(row[j] + 1, next[j - 1] + 1, row[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
    }
    row = next;
  }
  return row[b.length];
}

// The addons the mail is about, the likeliest first: the pasted report's; else each one named, by its score; else the
// one its features' words point to, when one alone has the most. None when the words say nothing or are torn.
function addonsOf(subject, text) {
  const report = REPORT.exec(text);
  if (report) return ADDONS.filter((a) => a.title === report[1]);
  const words = `${subject}\n${text}`;
  const afterKali = namedAfterKali(words);
  const scored = ADDONS.map((a) => ({
    addon: a,
    named: a.names.some((w) => w.test(words)) || afterKali.has(a.title),
    score: a.words.filter((w) => w.test(words)).length,
  })).sort((x, y) => y.score - x.score);
  const named = scored.filter((s) => s.named);
  if (named.length) return named.map((s) => s.addon);
  return scored[0].score > 0 && scored[0].score > scored[1].score ? [scored[0].addon] : [];
}

// The sender's own words: the mail without the report pasted in it, which is English whatever the sender writes.
function proseOf(text) {
  const report = REPORT.exec(text);
  return report ? text.slice(0, report.index) : text;
}

// The language most of the mail's small words are in, when at least two are and no other has as many.
function languageOf(text) {
  const tokens = String(text).toLowerCase().match(/[\p{L}']+/gu) || [];
  const counts = LANGUAGES.map((l) => ({ l, n: tokens.filter((t) => l.words.includes(t)).length }))
    .sort((x, y) => y.n - x.n);
  return counts[0].n >= 2 && counts[0].n > counts[1].n ? counts[0].l.github : null;
}

// The kind a pasted report or a keyword says, the subject's words first; none when neither says one. A problem the
// mail says there isn't doesn't count: "One of the best addon kali hud, no issue at all !" was filed as a bug on
// 2026-11-24 (issue #4; Ikar: "I was mean but I think it is good enough").
function kindOf(subject, text) {
  if (REPORT.test(text)) return KINDS[0];
  const said = unsaid(subject);
  const told = unsaid(text);
  return KINDS.find((k) => k.words.some((w) => w.test(said))) ||
    KINDS.find((k) => k.words.some((w) => w.test(told))) || null;
}

// The problems a mail denies, in the four languages, taken out before its keywords are read.
const DENIED = [
  /\b(no|not an?y?|never an?y?|without( an?y)?|zero)\s+(issues?|problems?|bugs?|errors?|crash(es)?)\b/gi,
  /\b(aucune?|pas d[eu'’]|sans|jamais d[eu'’])\s*(probl[eè]mes?|bugs?|bogues?|erreurs?|soucis?|plantages?)\b/gi,
  /\b(kein(e|en|er)?|ohne|nie)\s+(probleme?|fehler|bugs?|abst[üu]rze?)\b/gi,
  /\b(ning[uú]n|ninguna|sin|no hay|nunca)\s+(problemas?|errores|error|fallos?|bugs?)\b/gi,
];
function unsaid(text) {
  return DENIED.reduce((left, denied) => left.replace(denied, ' '), String(text || ''));
}

// The title (Ikar: "And what is the title? Or should we guess by the content see if there is our logs"): what the
// subject says, else the sender's first sentence, else what the pasted report shows went wrong; after the addon's name,
// with its version when the report gives it, as the game's own link titles an issue ("KaLi Quest 0.9.0: "), or KaLi's
// when the mail names no addon. Left as it is when it names the addon already.
function titleOf(addons, subject, text) {
  const status = STATUS.exec(text);
  const name = addons.length ? addons[0].title : 'KaLi';
  const prefix = status && status[1] === name ? `${name} ${status[2]}` : name;
  const said = sayingOf(subject) || firstSentence(proseOf(text)) || fromReport(text) || '(no subject)';
  const title = said.toLowerCase().includes(name.toLowerCase()) ? said : `${prefix}: ${said}`;
  return title.replace(EMAIL, '[address]').slice(0, 200);
}

// The subject when it says something: a "Re:" taken off, nothing kept when only kinds, greetings and names remain.
function sayingOf(subject) {
  const said = String(subject || '').replace(/^\s*((re|fwd?|tr|aw|wg|rv)\s*:\s*)+/i, '').trim();
  const words = said.toLowerCase().match(/[\p{L}\p{N}]+/gu) || [];
  return words.some((w) => !EMPTY_WORDS.has(w)) ? said : '';
}

// The first thing the sender says, a greeting left out: its first sentence, at most a hundred characters.
function firstSentence(prose) {
  for (const raw of String(prose).split('\n')) {
    const line = raw.replace(GREETING, '').trim();
    const sentence = ((line.match(/^.*?[.!?](?=\s|$)/) || [line])[0]).replace(/[.!]$/, '').trim();
    if (!sentence) continue;
    const short = sentence.length > 100 ? `${sentence.slice(0, 97).replace(/\s+\S*$/, '')}…` : sentence;
    return short.charAt(0).toUpperCase() + short.slice(1);
  }
  return '';
}

// What the pasted report shows went wrong: its first error, from the addon's own folder on; else what the API check
// found missing; else that it's a report.
function fromReport(text) {
  const report = REPORT.exec(text);
  if (!report) return '';
  const body = text.slice(report.index);
  const error = /== errors ==\n(?!\(none\))x\d+[^\n]*\n([^\n]+)/.exec(body);
  if (error) return `error in ${error[1].replace(/^.*?KaLi\w+[\\/]/, '').trim()}`.slice(0, 120);
  const missing = /^\s+missing: (.+)$/m.exec(body);
  if (missing) return `the game lacks ${missing[1].trim()}`;
  return 'bug report';
}

// The game's language, from the pasted report's status line, for a mail with too few words of its own to tell.
function clientLanguage(text) {
  const status = STATUS.exec(text);
  return status ? CLIENTS[status[3]] || null : null;
}

// The mail's own text: the quote of the earlier mails and the signature left out, any address taken away.
function clean(body) {
  const lines = String(body || '').replace(/\r\n?/g, '\n').split('\n');
  const out = [];
  for (const line of lines) {
    if (/^-- ?$/.test(line) || ORIGINAL.test(line)) break;
    if (QUOTE_END.test(line)) {
      if (!QUOTE_START.test(line) && out.length && QUOTE_START.test(out[out.length - 1])) out.pop();
      break;
    }
    if (/^>/.test(line)) continue;
    out.push(line);
  }
  return out.join('\n').replace(EMAIL, '[address removed]').trim();
}

// As GitHub shows it: the pasted report in a block of its own, and no @name outside it that would call someone.
function publish(text) {
  const report = REPORT.exec(text);
  const prose = (report ? text.slice(0, report.index) : text).replace(/(^|[^\w`])@(?=[A-Za-z0-9])/g, '$1@\u200b');
  return report ? `${prose.trim()}\n\n\`\`\`text\n${text.slice(report.index).trim()}\n\`\`\`` : prose;
}

function attachments(message) {
  const count = message.getAttachments().length;
  return count ? `\n\n_${count} attachment${count > 1 ? 's' : ''} in the mail, kept private._` : '';
}

function cut(text) {
  return text.length > MAX_CHARS ? `${text.slice(0, MAX_CHARS)}\n\n(cut at ${MAX_CHARS} characters)` : text;
}

function day(date) {
  return date.toISOString().slice(0, 10);
}

// The replies, in the sender's language alone (Ikar 2026-11-24: "never multiples languages"), English when it
// couldn't be told: the mail's own, or the game's from a pasted report, as its label says. Each language with its own
// typography; the no-break spaces made from their code, as no editor can turn that into an ordinary space.
const NBSP = String.fromCharCode(160);
const SAY = {
  'in English': {
    filed: (n, url) => `Thank you. Your mail is now issue #${n} of the KaLi addons, published without your address: ` +
      `${url}\nAnswer this mail to add to it; the answers given there come back to you here.`,
    answer: (who, n) => `${who} on GitHub, issue #${n}:`,
    closed: (n, how) => `Issue #${n} is closed: ${how}.`,
    how: { completed: 'resolved', not_planned: 'not planned', duplicate: 'a duplicate of another issue',
      other: 'closed' },
    hint: 'Answer this mail to reply.',
  },
  'in French': {
    filed: (n, url) => `Merci. Votre message est devenu le ticket n°${NBSP}${n} des addons KaLi, publié sans votre ` +
      `adresse${NBSP}: ${url}\nRépondez à ce message pour le compléter${NBSP}; les réponses données là-bas vous ` +
      'reviennent ici.',
    answer: (who, n) => `${who} sur GitHub, ticket n°${NBSP}${n}${NBSP}:`,
    closed: (n, how) => `Le ticket n°${NBSP}${n} est fermé${NBSP}: ${how}.`,
    how: { completed: 'résolu', not_planned: 'non prévu', duplicate: 'un doublon d’un autre ticket', other: 'fermé' },
    hint: 'Répondez à ce message pour répondre.',
  },
  'in German': {
    filed: (n, url) => `Danke. Eure Mail ist jetzt das Issue Nr.${NBSP}${n} der KaLi-Addons, veröffentlicht ohne ` +
      `Eure Adresse: ${url}\nAntwortet auf diese Mail, um sie zu ergänzen; die Antworten dort kommen hier zu ` +
      'Euch zurück.',
    answer: (who, n) => `${who} auf GitHub, Issue Nr.${NBSP}${n}:`,
    closed: (n, how) => `Das Issue Nr.${NBSP}${n} ist geschlossen: ${how}.`,
    how: { completed: 'erledigt', not_planned: 'nicht geplant', duplicate: 'ein Duplikat eines anderen Issues',
      other: 'geschlossen' },
    hint: 'Antwortet auf diese Mail, um zu antworten.',
  },
  'in Spanish': {
    filed: (n, url) => `Gracias. Tu correo es ahora la incidencia n.º${NBSP}${n} de los addons KaLi, publicada sin ` +
      `tu dirección: ${url}\nResponde a este correo para completarla; las respuestas que se den allí te llegarán aquí.`,
    answer: (who, n) => `${who} en GitHub, incidencia n.º${NBSP}${n}:`,
    closed: (n, how) => `La incidencia n.º${NBSP}${n} está cerrada: ${how}.`,
    how: { completed: 'resuelta', not_planned: 'no prevista', duplicate: 'un duplicado de otra incidencia',
      other: 'cerrada' },
    hint: 'Responde a este correo para contestar.',
  },
};

function say(language) {
  return SAY[language] || SAY['in English'];
}

function filedReply(issue, language) {
  return say(language).filed(issue.number, issue.html_url);
}

function answerReply(comment, n, language) {
  const s = say(language);
  return `${s.answer(comment.user.login, n)}\n\n${comment.body}\n\n${comment.html_url}\n\n${s.hint}`;
}

// As GitHub closed it: done, not planned, or a duplicate of another; any other reason, closed.
function closedReply(issue, language) {
  const s = say(language);
  return `${s.closed(issue.number, s.how[issue.state_reason] || s.how.other)} ${issue.html_url}\n\n${s.hint}`;
}

function load(key) {
  const value = PropertiesService.getScriptProperties().getProperty(key);
  return value ? JSON.parse(value) : null;
}

function save(key, value) {
  PropertiesService.getScriptProperties().setProperty(key, JSON.stringify(value));
}

// The token: a fine-grained one of Ikar's, for this repository alone, Issues read and write. In the script's
// properties (Project Settings), never in this file.
function github(method, path, payload, missingOk) {
  const token = PropertiesService.getScriptProperties().getProperty('GITHUB_TOKEN');
  if (!token) throw new Error('No GITHUB_TOKEN in the script properties: see tools/mail/README.md');
  const options = {
    method,
    muteHttpExceptions: true,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    },
  };
  if (payload) {
    options.contentType = 'application/json';
    options.payload = JSON.stringify(payload);
  }
  const response = UrlFetchApp.fetch(`https://api.github.com${path}`, options);
  const code = response.getResponseCode();
  // Asked so, a thing GitHub no longer has (a deleted issue) is null, not a failure.
  if (missingOk && (code === 404 || code === 410)) return null;
  if (code >= 300) {
    throw new Error(`GitHub answered ${code} to ${method} ${path}: ${response.getContentText().slice(0, 500)}`);
  }
  return JSON.parse(response.getContentText() || 'null');
}
