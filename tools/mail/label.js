// Labels for an issue opened on GitHub, from the game's link or by hand (Ikar 2026-11-24: "Yes" to labelling them as
// the mailed ones): its kind (bug, enhancement, question), its addons and its language, read the way the mail script
// reads a mail, by Code.gs itself, loaded as it is. Never "by mail", and nothing for the issues the mail script writes,
// which carry their labels already. It adds, never takes off.
// Run by .github/workflows/label-issues.yml when an issue is opened; tools/mail/test.js tries it.
const fs = require('fs');
const path = require('path');
const vm = require('vm');

// The mail script's functions and constants, without Gmail or GitHub: only what reads a text is called.
function script() {
  const context = {};
  vm.createContext(context);
  vm.runInContext(fs.readFileSync(path.join(__dirname, 'Code.gs'), 'utf8'), context, { filename: 'Code.gs' });
  return (code, values = {}) => {
    Object.assign(context, values);
    return vm.runInContext(code, context);
  };
}

// The labels an issue should have and hasn't: as for a mail whose subject is the title and whose text is the body.
function labelsForIssue(issue) {
  const run = script();
  const body = String(issue.body || '');
  if (body.includes(run('MARK'))) return [];
  const found = run(`(() => {
    const kind = kindOf(title, body);
    const language = languageOf(proseOf(body)) || clientLanguage(body);
    const addons = addonsOf(title, body).map((a) => a.github);
    return [...(kind ? [kind.github] : []), ...addons, ...(language ? [language] : [])];
  })()`, { title: String(issue.title || ''), body });
  const has = (issue.labels || []).map((l) => (typeof l === 'string' ? l : l.name));
  return [...found].filter((name) => !has.includes(name));
}

async function main() {
  const event = JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH, 'utf8'));
  const issue = event.issue;
  const labels = issue ? labelsForIssue(issue) : [];
  if (!labels.length) {
    console.log('No label to add.');
    return;
  }
  const url = `https://api.github.com/repos/${process.env.GITHUB_REPOSITORY}/issues/${issue.number}/labels`;
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.GH_TOKEN}`,
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'Content-Type': 'application/json',
      'User-Agent': 'kali-labels',
    },
    body: JSON.stringify({ labels }),
  });
  if (!response.ok) throw new Error(`GitHub answered ${response.status}: ${(await response.text()).slice(0, 500)}`);
  console.log(`#${issue.number}: ${labels.join(', ')}`);
}

if (require.main === module) {
  main().catch((e) => {
    console.error(e.message);
    process.exit(1);
  });
}

module.exports = { labelsForIssue };
