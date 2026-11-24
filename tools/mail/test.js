// The mail script (Code.gs) played offline, on a fake Gmail and a fake GitHub: a report filed, a mail naming no addon
// left to read, a reply added, an answer and a closing mailed back, each once, and no address reaching GitHub.
// Run with: node tools/mail/test.js
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert');

const ME = 'kali.reports@gmail.com';
const PLAYER = 'Jean Dupont <player@example.com>';
const REPO = 'Ikar-Rahl/Warcraft-KaLi';
let failures = 0;

function makeWorld() {
  const threads = [];
  const sent = [];
  const props = new Map();
  const triggers = [];
  const labels = new Map();
  let ids = 0;
  const slug = (name) => name.toLowerCase().replace(/[\s/]+/g, '-');

  function message(thread, m) {
    const msg = {
      from: m.from, date: m.date || new Date(), body: m.body, attachments: m.attachments || 0, headers: m.headers || {},
      getFrom: () => msg.from,
      getDate: () => msg.date,
      getPlainBody: () => msg.body,
      getAttachments: () => new Array(msg.attachments).fill({}),
      getHeader: (name) => msg.headers[name] || '',
      reply: (body) => {
        const answer = message(thread, { from: `KaLi <${ME}>`, body, date: new Date(Date.now() + 1) });
        thread.messages.push(answer);
        sent.push({ to: msg.from, thread: thread.id, body });
        return answer;
      },
    };
    return msg;
  }

  function mail(m) {
    const thread = {
      id: `thread-${++ids}`, subject: m.subject, labels: new Set(), inbox: true, messages: [],
      getId: () => thread.id,
      getMessages: () => thread.messages.slice(),
      getFirstMessageSubject: () => thread.subject,
      addLabel: (label) => thread.labels.add(label.name),
      removeLabel: (label) => thread.labels.delete(label.name),
      moveToArchive: () => { thread.inbox = false; },
      moveToInbox: () => { thread.inbox = true; },
      isInInbox: () => thread.inbox,
      getLabels: () => [...thread.labels].map((name) => ({ name, getName: () => name })),
    };
    thread.messages.push(message(thread, m));
    threads.push(thread);
    return thread;
  }

  function replyFrom(thread, m) {
    thread.messages.push(message(thread, m));
    thread.inbox = true;
  }

  function search(query) {
    const terms = query.split(/\s+/);
    return threads.filter((t) => terms.every((term) => {
      if (term === 'in:inbox') return t.inbox;
      let m = /^(-?)label:(.+)$/.exec(term);
      if (m) return [...t.labels].some((l) => slug(l) === m[2]) !== (m[1] === '-');
      m = /^newer_than:(\d+)d$/.exec(term);
      if (m) return t.messages.some((x) => Date.now() - x.date.getTime() < m[1] * 86400000);
      throw new Error(`the fake Gmail doesn't know ${term}`);
    }));
  }

  // GitHub, as far as the script uses it.
  const issues = [];
  let commentIds = 1000;
  const github = {
    issues,
    // The repository's own, before setup().
    labels: ['bug', 'enhancement', 'question'].map((name) => ({ name })),
    // Deleted on GitHub: gone from the lists, a comment on it refused.
    remove(n) {
      issues.find((i) => i.number === n).deleted = true;
    },
    comment(n, body, login = 'Ikar-Rahl') {
      const issue = issues.find((i) => i.number === n);
      const c = { id: ++commentIds, body, user: { login },
        html_url: `https://github.com/${REPO}/issues/${n}#c${commentIds}`,
        created_at: new Date().toISOString(), updated_at: new Date().toISOString() };
      issue.comments.push(c);
      issue.updated_at = c.updated_at;
      return c;
    },
    close(n, reason) {
      const issue = issues.find((i) => i.number === n);
      Object.assign(issue, { state: 'closed', state_reason: reason, updated_at: new Date().toISOString() });
    },
  };
  function fetch(url, options) {
    assert.strictEqual(options.headers.Authorization, 'Bearer the-token', 'the token is sent');
    const u = new URL(url);
    const method = (options.method || 'get').toLowerCase();
    const body = options.payload ? JSON.parse(options.payload) : null;
    const base = `/repos/${REPO}`;
    let out;
    let m;
    if (method === 'get' && u.pathname === base) {
      out = { full_name: REPO };
    } else if (method === 'post' && u.pathname === `${base}/issues`) {
      const n = issues.length + 1;
      out = { number: n, html_url: `https://github.com/${REPO}/issues/${n}`, title: body.title, body: body.body,
        labels: body.labels, state: 'open', state_reason: null, comments: [], updated_at: new Date().toISOString() };
      issues.push(out);
    } else if (method === 'get' && u.pathname === `${base}/issues`) {
      const since = u.searchParams.get('since');
      out = issues.filter((i) => !i.deleted && i.labels.includes(u.searchParams.get('labels'))
        && i.updated_at >= since);
    } else if ((m = new RegExp(`^${base}/issues/(\\d+)/comments$`).exec(u.pathname))) {
      if (method === 'post') {
        if (issues.find((i) => i.number === Number(m[1])).deleted) {
          return { getResponseCode: () => 404, getContentText: () => '{"message":"Not Found"}' };
        }
        out = github.comment(Number(m[1]), body.body);
      } else {
        const since = u.searchParams.get('since');
        out = issues.find((i) => i.number === Number(m[1])).comments.filter((c) => c.updated_at >= since);
      }
    } else if (u.pathname === `${base}/labels`) {
      if (method === 'post') {
        github.labels.push(body);
        out = body;
      } else {
        out = github.labels;
      }
    } else {
      throw new Error(`the fake GitHub doesn't know ${method} ${url}`);
    }
    const text = JSON.stringify(out);
    return { getResponseCode: () => 200, getContentText: () => text };
  }

  const context = {
    GmailApp: {
      getUserLabelByName: (name) => labels.get(name) || null,
      createLabel: (name) => labels.set(name, { name }).get(name),
      search,
      getThreadById: (id) => threads.find((t) => t.id === id) || null,
    },
    Session: { getEffectiveUser: () => ({ getEmail: () => ME }) },
    PropertiesService: { getScriptProperties: () => ({
      getProperty: (k) => (props.has(k) ? props.get(k) : null),
      setProperty: (k, v) => props.set(k, String(v)),
      deleteProperty: (k) => props.delete(k),
    }) },
    LockService: { getScriptLock: () => ({ tryLock: () => true, releaseLock: () => {} }) },
    ScriptApp: {
      getProjectTriggers: () => triggers.slice(),
      deleteTrigger: (t) => triggers.splice(triggers.indexOf(t), 1),
      newTrigger: (fn) => ({ timeBased: () => ({ everyMinutes: (n) => ({ create: () => {
        triggers.push({ fn, n, getHandlerFunction: () => fn });
      } }) }) }),
    },
    UrlFetchApp: { fetch },
    Logger: { log: () => {} },
    URL, encodeURIComponent, JSON, Date,
  };
  vm.createContext(context);
  vm.runInContext(fs.readFileSync(path.join(__dirname, 'Code.gs'), 'utf8'), context, { filename: 'Code.gs' });
  props.set('GITHUB_TOKEN', 'the-token');
  return { context, run: (code) => vm.runInContext(code, context), threads, sent, props, triggers, labels, github,
    mail, replyFrom };
}

function check(name, fn) {
  try {
    fn();
    console.log(`ok    ${name}`);
  } catch (e) {
    failures += 1;
    console.log(`FAIL  ${name}\n      ${e.message}`);
  }
}

const REPORT_TEXT = [
  'KaLi Quest bug report, 2026-11-24 13:05:12',
  '',
  '== status ==',
  'KaLi Quest 0.9.0, client 1.60.1 (71037), interface 16001, frFR',
  '',
  '== errors ==',
  '(none)',
].join('\n');

const w = makeWorld();
const minutesAgo = (n) => new Date(Date.now() - n * 60000);
// A thread's Gmail labels, and those of a mail sent on to GitHub: the folder and the issue's own labels.
const gmail = (thread) => [...thread.labels].sort();
const filed = (...tags) => ['GitHub', ...tags.map((tag) => `GitHub/${tag}`)].sort();

check('setup: the labels on both sides, made once, one five-minute trigger, the starting point', () => {
  w.run('setup()');
  w.run('setup()');
  assert.deepStrictEqual([...w.labels.keys()], ['No issue', 'GitHub', 'GitHub/bug', 'GitHub/enhancement',
    'GitHub/question', 'GitHub/KaLi Quest', 'GitHub/KaLi Recipe', 'GitHub/KaLi HUD', 'GitHub/in English',
    'GitHub/in French', 'GitHub/in German', 'GitHub/in Spanish', 'GitHub/attachments in mail', 'GitHub/closed']);
  assert.deepStrictEqual(w.github.labels.map((l) => l.name), ['bug', 'enhancement', 'question', 'by mail',
    'KaLi Quest', 'KaLi Recipe', 'KaLi HUD', 'in English', 'in French', 'in German', 'in Spanish',
    'attachments in mail']);
  assert.ok(w.github.labels.slice(3).every((l) => /^[0-9a-f]{6}$/.test(l.color) && l.description));
  assert.strictEqual(w.triggers.length, 1);
  assert.strictEqual(w.triggers[0].n, 5);
  assert.ok(w.props.get('since'));
  w.props.set('since', minutesAgo(30).toISOString());
  assert.ok(Number(w.props.get('start')) > minutesAgo(1).getTime(), 'no starting point');
  w.props.set('start', String(minutesAgo(60).getTime()));
});

const report = w.mail({
  from: PLAYER, subject: 'My groups vanish', date: minutesAgo(20), attachments: 2,
  body: `Hello, after a reload my groups are gone. Ask @someone, or mail jean@example.com.\n\n${REPORT_TEXT}` +
    '\n\n-- \nJean Dupont\n+33 6 00 00 00 00',
});
const hello = w.mail({ from: 'Someone <fan@example.com>', subject: 'Hi', body: 'Love your work!',
  date: minutesAgo(19) });
const hud = w.mail({ from: 'Ann <ann@example.com>', subject: 'Plate gone', body: '/kh does nothing since today.',
  date: minutesAgo(18) });

check('a run files the report and the mail saying /kh does nothing as bugs, sorts the hello under No issue', () => {
  w.run('run()');
  assert.strictEqual(w.github.issues.length, 2);
  assert.deepStrictEqual(gmail(report), filed('bug', 'KaLi Quest', 'in English', 'attachments in mail'));
  assert.deepStrictEqual(gmail(hello), ['No issue']);
  assert.deepStrictEqual(gmail(hud), filed('bug', 'KaLi HUD'));
  assert.ok(!report.inbox && !hud.inbox && hello.inbox,
    'the mails sent on to GitHub are in the inbox, or the hello isn\'t');
  assert.strictEqual(w.github.issues[1].title, 'KaLi HUD: Plate gone');
  assert.deepStrictEqual(w.github.issues[1].labels, ['by mail', 'bug', 'KaLi HUD']);
});

const issue = w.github.issues[0];
check('the issue: its title, its label, the report in a block, no address, no signature, no call to @someone', () => {
  assert.strictEqual(issue.title, 'KaLi Quest 0.9.0: My groups vanish');
  assert.deepStrictEqual(issue.labels, ['by mail', 'bug', 'KaLi Quest', 'in English', 'attachments in mail']);
  assert.ok(issue.body.includes('```text\nKaLi Quest bug report, 2026-11-24 13:05:12'), issue.body);
  assert.ok(issue.body.includes('== errors ==\n(none)\n```'), issue.body);
  for (const secret of ['player@example.com', 'jean@example.com', 'Jean Dupont', '+33']) {
    assert.ok(!issue.body.includes(secret), `the issue holds ${secret}`);
  }
  assert.ok(issue.body.includes('@\u200bsomeone') && !issue.body.includes(' @someone'));
  assert.ok(issue.body.includes('2 attachments in the mail, kept private'));
});

check('the sender is told the issue, in the language of the mail alone', () => {
  const told = w.sent.filter((s) => s.thread === report.id);
  assert.strictEqual(told.length, 1);
  assert.strictEqual(told[0].to, PLAYER);
  assert.ok(told[0].body.includes('issue #1') && told[0].body.includes(issue.html_url), told[0].body);
  for (const other of ['ticket n°', 'Issue Nr.', 'incidencia', 'Merci', 'Danke', 'Gracias']) {
    assert.ok(!told[0].body.includes(other), `another language in it: ${other}`);
  }
  assert.ok(!w.sent.some((s) => s.thread === hello.id), 'the hello got an answer');
});

check('a second run changes nothing', () => {
  const sent = w.sent.length;
  w.run('run()');
  assert.strictEqual(w.github.issues.length, 2);
  assert.strictEqual(w.sent.length, sent);
  assert.strictEqual(issue.comments.length, 0);
});

check('the sender\'s reply is added, without the quote of the earlier mails', () => {
  w.replyFrom(report, {
    from: PLAYER, date: new Date(),
    body: 'It also happens in dungeons.\n\nOn Mon, Nov 24, 2026 at 1:20 PM KaLi <kali.reports@gmail.com>\nwrote:\n' +
      '> Thank you. Your report is issue #1',
  });
  w.replyFrom(report, { from: PLAYER, date: new Date(Date.now() + 5), body: 'I am away until Monday.',
    headers: { 'Auto-Submitted': 'auto-replied' } });
  w.run('run()');
  assert.strictEqual(issue.comments.length, 1);
  const c = issue.comments[0].body;
  assert.ok(c.includes('It also happens in dungeons.'), c);
  assert.ok(!c.includes('Thank you') && !c.includes('kali.reports') && !c.includes('On Mon'), c);
  assert.ok(!w.sent.some((s) => s.body.includes('It also happens')), 'the script mailed its own comment back');
  assert.ok(!report.inbox, 'the thread the reply brought back to the inbox stays there');
});

check('an answer on GitHub is mailed to the sender, once', () => {
  w.github.comment(1, 'Thanks! Does it happen without other addons?');
  w.run('run()');
  w.run('run()');
  const mailed = w.sent.filter((s) => s.body.includes('Does it happen without other addons?'));
  assert.strictEqual(mailed.length, 1);
  assert.strictEqual(mailed[0].to, PLAYER);
  assert.strictEqual(mailed[0].thread, report.id);
});

check('an answer written between quoted lines is added alone', () => {
  w.replyFrom(report, { from: PLAYER, date: new Date(),
    body: '> Thanks! Does it happen without other addons?\nYes, even with KaLi Quest alone.' });
  w.run('run()');
  const c = issue.comments[issue.comments.length - 1].body;
  assert.ok(c.includes('Yes, even with KaLi Quest alone.'), c);
  assert.ok(!c.includes('Does it happen'), c);
});

check('Ikar answering from Gmail: his answer is added to the issue, without its quote, and not mailed again', () => {
  const sent = w.sent.length;
  w.replyFrom(report, { from: `KaLi <${ME}>`, date: new Date(Date.now() + 10),
    body: 'Thanks, it is fixed for the next version.\n\nOn Mon, Nov 24, 2026 at 2:00 PM Jean Dupont ' +
      '<player@example.com>\nwrote:\n> Yes, even with KaLi Quest alone.' });
  w.run('run()');
  const c = issue.comments[issue.comments.length - 1].body;
  assert.ok(c.includes('Answered by mail') && c.includes('Thanks, it is fixed for the next version.'), c);
  assert.ok(!c.includes('player@example.com') && !c.includes('Yes, even'), c);
  assert.strictEqual(w.sent.length, sent, 'Ikar\'s answer was mailed to the sender again');
  assert.ok(!issue.comments.some((x) => /Thank you\. Your mail|on GitHub, issue #/.test(x.body)),
    'one of the script\'s own mails was taken for Ikar\'s');
});

check('the closing is mailed once, and a reopening mails nothing', () => {
  w.github.close(1, 'completed');
  w.run('run()');
  w.run('run()');
  const closed = w.sent.filter((s) => s.body.includes('is closed'));
  assert.strictEqual(closed.length, 1);
  assert.ok(closed[0].body.includes('is closed: resolved') && !closed[0].body.includes('fermé'), closed[0].body);
  assert.ok(report.labels.has('GitHub/closed'), 'the closed issue\'s mail isn\'t under GitHub/closed');
  const issueOne = w.github.issues[0];
  Object.assign(issueOne, { state: 'open', state_reason: 'reopened', updated_at: new Date().toISOString() });
  const before = w.sent.length;
  w.run('run()');
  assert.strictEqual(w.sent.length, before);
  assert.ok(!report.labels.has('GitHub/closed'), 'the reopened issue\'s mail is still under GitHub/closed');
});

check('a report pasted under a subject naming no addon is still filed, under its addon', () => {
  const t = w.mail({ from: 'Bo <bo@example.com>', subject: 'bug', date: new Date(),
    body: REPORT_TEXT.replace(/KaLi Quest/g, 'KaLi Recipe') });
  w.run('run()');
  assert.ok(t.labels.has('GitHub/bug'));
  assert.strictEqual(w.github.issues[w.github.issues.length - 1].title, 'KaLi Recipe 0.9.0: bug report');
  assert.ok(w.github.issues[w.github.issues.length - 1].labels.includes('in French'), 'no language from the client');
});

const last = () => w.github.issues[w.github.issues.length - 1];

check('a proposal: the subject\'s word first, even with a bug\'s in the text', () => {
  const t = w.mail({ from: 'Cy <cy@example.com>', subject: 'Idea for KaLi Recipe', date: new Date(),
    body: 'A sound option would be nice. No problem otherwise!' });
  w.run('run()');
  assert.deepStrictEqual(gmail(t), filed('enhancement', 'KaLi Recipe', 'in English'));
  assert.strictEqual(last().title, 'KaLi Recipe: A sound option would be nice');
  assert.deepStrictEqual(last().labels, ['by mail', 'enhancement', 'KaLi Recipe', 'in English']);
});

check('a question in German, and a bug naming no addon, under KaLi\'s name', () => {
  const question = w.mail({ from: 'Dora <dora@example.com>', subject: 'Frage', date: new Date(),
    body: 'Wie kann ich in KaLi Quest eine Gruppe umbenennen?' });
  w.run('run()');
  assert.deepStrictEqual(gmail(question), filed('question', 'KaLi Quest', 'in German'));
  assert.strictEqual(last().title, 'Wie kann ich in KaLi Quest eine Gruppe umbenennen?');
  assert.deepStrictEqual(last().labels, ['by mail', 'question', 'KaLi Quest', 'in German']);
  const bug = w.mail({ from: 'Eli <eli@example.com>', subject: 'Bug after the patch', date: new Date(),
    body: 'Everything flickers since the patch.' });
  w.run('run()');
  assert.deepStrictEqual(gmail(bug), filed('bug'));
  assert.strictEqual(last().title, 'KaLi: Bug after the patch');
  assert.deepStrictEqual(last().labels, ['by mail', 'bug']);
});

check('the addon found by its features\' words, a name over them, two named both labelled', () => {
  const tracker = w.mail({ from: 'Fay <fay@example.com>', subject: 'Bug in the tracker', date: new Date(),
    body: 'It flickers.' });
  w.run('run()');
  assert.deepStrictEqual(gmail(tracker), filed('bug', 'KaLi Quest'));
  assert.strictEqual(last().title, 'KaLi Quest: Bug in the tracker');
  const named = w.mail({ from: 'Gil <gil@example.com>', subject: 'KaLi Recipe problem', date: new Date(),
    body: 'In the quest journal, the tracker objectives flicker.' });
  w.run('run()');
  assert.strictEqual(last().title, 'KaLi Recipe: In the quest journal, the tracker objectives flicker');
  assert.deepStrictEqual(gmail(named), filed('bug', 'KaLi Recipe', 'in English'));
  const both = w.mail({ from: 'Hal <hal@example.com>', subject: 'KaLi HUD hides KaLi Quest\'s tracker',
    date: new Date(), body: 'Problem: the plate covers the tracker.' });
  w.run('run()');
  assert.deepStrictEqual(last().labels, ['by mail', 'bug', 'KaLi Quest', 'KaLi HUD', 'in English']);
  assert.deepStrictEqual(gmail(both), filed('bug', 'KaLi Quest', 'KaLi HUD', 'in English'));
  const torn = w.mail({ from: 'Jo <jo@example.com>', subject: 'Bug: the tracker and the plate flicker',
    date: new Date(), body: 'Both.' });
  w.run('run()');
  assert.deepStrictEqual(gmail(torn), filed('bug'), 'words torn between two addons gave one');
  assert.strictEqual(last().title, 'KaLi: Bug: the tracker and the plate flicker');
});

check('a mail under No issue given a kind and an addon by hand is filed so, and leaves No issue', () => {
  const count = w.github.issues.length;
  w.run('run()');
  assert.strictEqual(w.github.issues.length, count, 'No issue was filed with no kind given');
  hello.labels.add('GitHub/enhancement');
  hello.labels.add('GitHub/KaLi HUD');
  w.run('run()');
  assert.strictEqual(w.github.issues.length, count + 1);
  assert.deepStrictEqual(gmail(hello), filed('enhancement', 'KaLi HUD'));
  assert.ok(!hello.inbox);
  assert.strictEqual(last().title, 'KaLi HUD: Love your work');
  assert.deepStrictEqual(last().labels, ['by mail', 'enhancement', 'KaLi HUD']);
  assert.ok(w.sent.some((s) => s.thread === hello.id && s.body.includes(last().html_url)));
});

let lou;
check('a title from the report\'s first error, the language from the game\'s, a greeting left out', () => {
  const error = w.mail({ from: 'Kim <kim@example.com>', subject: 'help', date: new Date(),
    body: REPORT_TEXT.replace(/KaLi Quest/g, 'KaLi Recipe').replace('== errors ==\n(none)',
      '== errors ==\nx2  first 2026-11-24 13:00  last 2026-11-24 13:04  v0.9.0\n' +
      'Interface/AddOns/KaLiRecipe/UI/Notebook.lua:42: attempt to index a nil value\n[stack]') });
  w.run('run()');
  assert.ok(error.labels.has('GitHub/bug'));
  assert.strictEqual(last().title, 'KaLi Recipe 0.9.0: error in UI/Notebook.lua:42: attempt to index a nil value');
  assert.deepStrictEqual(last().labels, ['by mail', 'bug', 'KaLi Recipe', 'in French']);
  lou = w.mail({ from: 'Lou <lou@example.com>', subject: 'Re: KaLi Quest', date: new Date(),
    body: 'Bonjour,\nle suivi des quêtes disparaît après un rechargement, c\'est un bug. Merci' });
  w.run('run()');
  assert.strictEqual(last().title, 'KaLi Quest: Le suivi des quêtes disparaît après un rechargement, c\'est un bug');
  assert.ok(last().labels.includes('in French'));
});

check('a machine\'s mail, a list\'s, and one from before the start are left alone', () => {
  const count = w.github.issues.length;
  const google = w.mail({ from: 'Google <no-reply@accounts.google.com>', subject: 'Security alert', date: new Date(),
    body: 'A request to add a recovery contact. If this was a bug, check your settings.' });
  const list = w.mail({ from: 'News <news@example.com>', subject: 'Bug fixes this week', date: new Date(),
    body: 'Our ideas and bug fixes.', headers: { 'List-Unsubscribe': '<mailto:off@example.com>' } });
  const old = w.mail({ from: 'Max <max@example.com>', subject: 'KaLi HUD bug', date: minutesAgo(120),
    body: 'The plate is gone.' });
  const sent = w.sent.length;
  w.run('run()');
  assert.strictEqual(w.github.issues.length, count);
  assert.strictEqual(w.sent.length, sent);
  for (const t of [google, list, old]) assert.deepStrictEqual([...t.labels], []);
});

check('an issue deleted on GitHub: its sender writing again brings the thread back under No issue, runs go on', () => {
  w.github.remove(2);
  w.replyFrom(hud, { from: 'Ann <ann@example.com>', date: new Date(), body: 'Still broken.' });
  const count = w.github.issues.length;
  w.run('run()');
  assert.deepStrictEqual(gmail(hud), ['No issue']);
  assert.ok(hud.inbox && !w.props.has(`t:${hud.id}`) && !w.props.has('i:2'));
  w.run('run()');
  assert.strictEqual(w.github.issues.length, count, 'the forgotten thread was filed again');
});

check('a mail Ikar archived is left alone; one out of the inbox given a kind by hand is filed', () => {
  const archived = w.mail({ from: 'Ned <ned@example.com>', subject: 'KaLi Quest bug', date: new Date(),
    body: 'The tracker is gone.' });
  archived.inbox = false;
  const given = w.mail({ from: 'Oz <oz@example.com>', subject: 'About the minimap', date: new Date(),
    body: 'Where is the clock?' });
  given.inbox = false;
  given.labels.add('GitHub/question');
  const count = w.github.issues.length;
  w.run('run()');
  assert.deepStrictEqual(gmail(archived), []);
  assert.strictEqual(w.github.issues.length, count + 1);
  assert.strictEqual(last().title, 'KaLi HUD: About the minimap');
  assert.deepStrictEqual(gmail(given), filed('question', 'KaLi HUD', 'in English'));
});

check('closed as a duplicate, the mail says so', () => {
  const n = last().number;
  w.github.close(n, 'duplicate');
  w.run('run()');
  const told = w.sent.filter((s) => s.body.includes(`Issue #${n} is closed`));
  assert.strictEqual(told.length, 1);
  assert.ok(told[0].body.includes('a duplicate of another issue') && !told[0].body.includes('doublon'), told[0].body);
});

const NBSP = String.fromCharCode(160);

check('a French mail: its thank-you, an answer and the closing in French alone, none taken for Ikar\'s', () => {
  const n = w.github.issues.find((i) => i.title.startsWith('KaLi Quest: Le suivi')).number;
  const toLou = () => w.sent.filter((s) => s.thread === lou.id);
  assert.ok(toLou()[0].body.startsWith(`Merci. Votre message est devenu le ticket n°${NBSP}${n} `), toLou()[0].body);
  assert.ok(!toLou()[0].body.includes('Thank you'));
  w.github.comment(n, 'Corrigé pour la prochaine version.');
  w.run('run()');
  const answer = toLou()[toLou().length - 1].body;
  assert.ok(answer.startsWith(`Ikar-Rahl sur GitHub, ticket n°${NBSP}${n}${NBSP}:`) &&
    answer.includes('Répondez à ce message') && !answer.includes('Answer this mail'), answer);
  w.github.close(n, 'completed');
  w.run('run()');
  const closing = toLou()[toLou().length - 1].body;
  assert.ok(closing.startsWith(`Le ticket n°${NBSP}${n} est fermé${NBSP}: résolu.`), closing);
  w.run('run()');
  const issue = w.github.issues.find((i) => i.number === n);
  assert.ok(!issue.comments.some((x) => x.body.includes('Answered by mail')),
    'a French mail of the script\'s taken for Ikar\'s');
});

check('every reply of the script, in each language, is known for its own', () => {
  assert.ok(w.run(`Object.keys(SAY).every((l) => isScriptMail(filedReply({ number: 7, html_url: 'u' }, l))
    && isScriptMail(answerReply({ user: { login: 'Ikar-Rahl' }, body: 'x', html_url: 'u' }, 7, l))
    && ['completed', 'not_planned', 'duplicate', 'reopened'].every((reason) =>
      isScriptMail(closedReply({ number: 7, state_reason: reason, html_url: 'u' }, l))))`));
});

check('a name misspelt after KaLi: kali receip is KaLi Recipe, kali reset is nothing', () => {
  const receip = w.mail({ from: 'Pat <pat@example.com>', subject: 'Bad add-on', date: new Date(),
    body: 'I have issue with kali receip, it doesn\'t work, you bad.' });
  w.run('run()');
  assert.strictEqual(last().title, 'KaLi Recipe: Bad add-on');
  assert.deepStrictEqual(gmail(receip), filed('bug', 'KaLi Recipe', 'in English'));
  w.mail({ from: 'Quin <quin@example.com>', subject: 'Bug', date: new Date(),
    body: 'KaLi reset my settings after the patch.' });
  w.run('run()');
  assert.ok(!last().labels.some((l) => l.startsWith('KaLi ')), last().labels.join(', '));
});

check('praise saying there is no issue stays under No issue; a problem beside a denied one is still a bug', () => {
  const count = w.github.issues.length;
  const praise = w.mail({ from: 'Rae <rae@example.com>', subject: 'This is great', date: new Date(),
    body: 'One of the best addon kali hud, no issue at all !' });
  const french = w.mail({ from: 'Sol <sol@example.com>', subject: 'Merci', date: new Date(),
    body: 'Aucun problème, super addon !' });
  w.run('run()');
  assert.strictEqual(w.github.issues.length, count, 'praise was filed');
  assert.deepStrictEqual(gmail(praise), ['No issue']);
  assert.deepStrictEqual(gmail(french), ['No issue']);
  const crash = w.mail({ from: 'Tim <tim@example.com>', subject: 'Minimap', date: new Date(),
    body: 'No problem with the HUD but the minimap crashes.' });
  w.run('run()');
  assert.deepStrictEqual(gmail(crash), filed('bug', 'KaLi HUD', 'in English'));
});

// The issues opened on GitHub, labelled by tools/mail/label.js with the mail script's own reading.
const { labelsForIssue } = require('./label.js');
const fenced = (report) => `\n\n\`\`\`text\n${report}\n\`\`\`\n`;

check('an issue from the game\'s link: a bug, its addon, its language, the player\'s or else the game\'s', () => {
  assert.deepStrictEqual(labelsForIssue({ title: 'KaLi Quest 0.9.0: groups vanish', labels: [],
    body: `What you were doing, and what happened:\nMy groups vanish after a reload.${fenced(
      REPORT_TEXT.replace('frFR', 'enUS'))}` }), ['bug', 'KaLi Quest', 'in English']);
  assert.deepStrictEqual(labelsForIssue({ title: 'KaLi Quest 0.9.0: ', labels: [],
    body: `Ce que vous faisiez, et ce qui s'est passé :\n${fenced(REPORT_TEXT)}` }),
  ['bug', 'KaLi Quest', 'in French']);
});

check('an issue opened by hand, one already labelled, one the mail script wrote', () => {
  assert.deepStrictEqual(labelsForIssue({ title: 'Idea: a sound option for KaLi Recipe', body: '', labels: [] }),
    ['enhancement', 'KaLi Recipe']);
  assert.deepStrictEqual(labelsForIssue({ title: 'KaLi HUD: the plate is gone, a bug', body: null,
    labels: [{ name: 'bug' }] }), ['KaLi HUD']);
  assert.deepStrictEqual(labelsForIssue({ title: 'KaLi Quest: a bug', labels: [],
    body: '<!-- kali-mail -->\nSent by mail on 2026-11-24.' }), []);
});

console.log(failures ? `\n${failures} FAILED` : '\nALL PASS');
process.exit(failures ? 1 : 0);
