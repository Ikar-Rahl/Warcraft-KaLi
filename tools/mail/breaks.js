// Deliberate breaks of tools/mail/Code.gs: each must make tools/mail/test.js fail. Run with: node tools/mail/breaks.js
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const repo = process.argv[2] || path.resolve(__dirname, '../..');
const code = fs.readFileSync(path.join(repo, 'tools/mail/Code.gs'), 'utf8');
const test = fs.readFileSync(path.join(repo, 'tools/mail/test.js'), 'utf8');
const BREAKS = [
  ['an address left in the issue', ".replace(EMAIL, '[address removed]')", ''],
  ['an answer mailed at each run', '      if (comment.id <= known.c) continue;\n', ''],
  ['an absence reply added to the issue', "auto === 'no' && ", ''],
  ['an @name left to call someone', ".replace(/(^|[^\\w`])@(?=[A-Za-z0-9])/g, '$1@\\u200b')", ''],
  ['the closing mailed at each run', 'if (closed !== known.closed) {', 'if (closed) {'],
  ['the quote of the earlier mails kept', "    if (/^>/.test(line)) continue;\n", ''],
  ['a mail with no keyword filed as a bug', '    KINDS.find((k) => k.words.some((w) => w.test(told))) || null;',
    '    KINDS[0];'],
  ['the text\'s keywords before the subject\'s', 'k.words.some((w) => w.test(said))) ||',
    'k.words.some((w) => w.test(told))) ||'],
  ['a kind given by hand ignored', 'const kind = given || ', 'const kind = '],
  ['No issue left on a mail filed', '    if (labels.includes(NO_ISSUE)) thread.removeLabel(gmailLabel(NO_ISSUE));\n',
    ''],
  ['a mail sent on to GitHub left in the inbox',
    '    first.reply(filedReply(issue, language));\n    thread.moveToArchive();',
    '    first.reply(filedReply(issue, language));'],
  ['a reply\'s thread left in the inbox', '    else if (added) thread.moveToArchive();\n', ''],
  ['the folder without the issue\'s labels', 'for (const name of [FOLDER, ...tags.map(inFolder)])',
    'for (const name of [FOLDER])'],
  ['the addons left out of the issue\'s labels', '...addons.map((a) => a.github), ', ''],
  ['an addon named left out for another\'s words', '  if (named.length) return named.map((s) => s.addon);\n', ''],
  ['words torn between two addons giving one', 'scored[0].score > scored[1].score',
    'scored[0].score >= scored[1].score'],
  ['an addon given by hand ignored', 'byHand.length ? byHand : ', ''],
  ['the language never labelled', '...(language ? [language] : []),', ''],
  ['the attachments never labelled', '...(first.getAttachments().length ? [ATTACHED] : [])', ''],
  ['a closed issue\'s mail not under KaLi/Closed', 'if (closed) thread.addLabel(label);', 'if (closed) { /* */ }'],
  ['the repository\'s labels not made', 'if (!existing.includes(name))', 'if (false)'],
  ['a machine\'s mail taken for a player\'s', ' && !MACHINE.test(from)', ''],
  ['a list\'s mail taken for a player\'s', ' && !bulk', ''],
  ['the mails from before the start filed', ' || first.getDate().getTime() < start', ''],
  ['a subject saying nothing made the title', "return words.some((w) => !EMPTY_WORDS.has(w)) ? said : '';",
    'return said;'],
  ['the greeting kept in the title', "raw.replace(GREETING, '').trim()", 'raw.trim()'],
  ['the report\'s error not read', 'if (error) return', 'if (false) return'],
  ['the version left out of the title', 'const prefix = status && status[1] === name ?', 'const prefix = false ?'],
  ['the game\'s language not used', ' || clientLanguage(text)', ''],
  ['a reply to a deleted issue failing every run', '        }, true);\n        if (gone) break;',
    '        });\n        if (gone) break;'],
  ['a forgotten thread left in the GitHub folder',
    '    if (name === FOLDER || name.startsWith(`${FOLDER}/`)) thread.removeLabel(label);\n', ''],
  ['a mail Ikar archived filed anyway', '    if (!given && !thread.isInInbox()) continue;\n', ''],
  ['a kind given out of the inbox ignored', 'if (!given && !thread.isInInbox()) continue;',
    'if (!thread.isInInbox()) continue;'],
  ['a duplicate mailed as closed for another reason', "duplicate: 'a duplicate of another issue'",
    "duplicated: 'a duplicate of another issue'"],
  ['Ikar\'s answers from Gmail left out of the issue', 'const ikar = !fromSender(message) && byIkar(message);',
    'const ikar = false;'],
  ['the script\'s own mails taken for Ikar\'s', '!isScriptMail(message.getPlainBody())', 'true'],
  ['the thank-you not in the mail\'s language', 'first.reply(filedReply(issue, language));',
    'first.reply(filedReply(issue, null));'],
  ['the language not kept for the later mails', 'closed: false, lang: language }', 'closed: false }'],
  ['a French thank-you taken for Ikar\'s answer',
    '  /^Merci\\. Votre message est devenu le ticket n°\\s?\\d+/, ', '  '],
  ['a misspelt name after KaLi not read', 'word === w || (w.length >= 5', 'word === w || (false'],
  ['a name read whatever its first letters', 'word.slice(0, 3) === w.slice(0, 3)', 'true'],
  ['a problem the mail denies taken for a bug', '  const told = unsaid(text);', '  const told = text;'],
];
const dir =fs.mkdtempSync(path.join(require('os').tmpdir(), 'kali-mail-'));
fs.writeFileSync(path.join(dir, 'test.js'), test);
let missed = 0;
for (const [name, from, to] of BREAKS) {
  if (!code.includes(from)) {
    console.log(`STALE  ${name}`);
    missed += 1;
    continue;
  }
  fs.writeFileSync(path.join(dir, 'Code.gs'), code.replace(from, to));
  try {
    execFileSync('node', [path.join(dir, 'test.js')], { stdio: 'pipe' });
    console.log(`MISSED ${name}`);
    missed += 1;
  } catch (e) {
    const first = String(e.stdout).split('\n').find((l) => l.startsWith('FAIL'));
    console.log(`caught ${name}: ${first}`);
  }
}
fs.rmSync(dir, { recursive: true });
console.log(missed ? `${missed} not caught` : `${BREAKS.length}/${BREAKS.length} caught`);
