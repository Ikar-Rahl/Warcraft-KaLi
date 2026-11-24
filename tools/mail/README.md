# KaLi's mailbox

Bug reports by mail, for players without a GitHub account (Ikar 2026-11-24: "Can we have a mail maybe instead? Can it
be processed? A gmail for kali?"). [Code.gs](Code.gs) runs in KaLi's own Gmail account, as a Google Apps Script, every
five minutes:

- a new mail holding a keyword of a kind, or a report pasted from the game, becomes an issue labelled **by mail**
  and its kind's label, and its sender gets the issue's link (Ikar: "for issue, let's make a filter of keywords like
  bugreport, proposal, issue etc."). The kinds and their keywords, in English, French, German
  and Spanish, are `KINDS` in [Code.gs](Code.gs): a bug (bug, issue, problem, error, crash, "doesn't work", bogue,
  plantage, Fehler, fallo…: GitHub's **bug**), a proposal (proposal, suggestion, idea, request, idée, Vorschlag,
  propuesta…: **enhancement**), a question (question, help, comment faire, Frage, pregunta…: **question**). The
  subject's words count first, then the text's; a pasted report is a bug; a problem the mail denies doesn't count
  ("no issue at all", "aucun problème", "kein Problem", "sin errores": praise stays under No issue). The issue's title
  is the subject, after the
  addon's name when the mail names one (KaLi Quest, `/kq`, KaLi Recipe, `/kr`, KaLi HUD, `/kh`), KaLi's otherwise;
- Gmail sorts them ("The mail would also sort them, so I can see the mail that got no GitHub issues", then "the mails
  that were forwarded should be put in a separate folder. Also, the labels in the Mail should match"): a mail sent on
  to GitHub leaves the inbox for the **GitHub** folder, under the issue's own labels (**GitHub/bug**,
  **GitHub/enhancement**, **GitHub/question**, **GitHub/KaLi Quest**, **GitHub/in French**, **GitHub/attachments in
  mail**…), and **GitHub/closed** while its issue is closed; a reply brings it back to the inbox until the next run
  has added it to the issue. Any other mail stays in the inbox under **No issue**. To file one the keywords missed,
  give it a kind's label (**GitHub/bug**, **GitHub/enhancement** or **GitHub/question**), and an addon's if need be:
  the next run files it so and takes off No issue;
- the addon is found by itself (Ikar: "it should try to auto detect the addon and make good use of labels, as much as
  possible"): from a pasted report, from its name or command (a word after "KaLi" a letter or two off counts: "kali
  receip" is KaLi Recipe; Ikar: "it did not detect kali receipt"), else from the words of its features in the four
  languages (`ADDONS`: quest, tracker, journal… for KaLi Quest; recipe, notebook, profession, vendor… for KaLi Recipe;
  plate, minimap, info bar, folder, macro… for KaLi HUD) when they point to one alone. Each addon named is labelled,
  the issue's title starting with the likeliest. The issue also gets the mail's language (**in French**, **in
  German**, **in Spanish**, **in English**: answer in it) and **attachments in mail** when it has some, the same in
  Gmail's folder. An addon's label given by hand in Gmail before the mail is filed wins;
- the sender's replies in the thread are added to the issue; the issue's comments, and its closing, are mailed to the
  sender in the same thread (Ikar: "And yes both ways");
- every mail the script writes is in the sender's language alone, the one its label says, English when it can't be
  told (Ikar: "Yes, never multiples languages"); the script knows its own mails by how they open, in each language.

**The title** (Ikar: "And what is the title? Or should we guess by the content see if there is our logs"): what the
subject says, unless it says nothing more than a kind, a greeting or a name ("bug", "help", "Re: KaLi Quest"); else
the sender's first sentence, its greeting left out; else what the pasted report shows went wrong: its first error
("error in UI/Notebook.lua:42: attempt to index a nil value"), what the API check found missing, or "bug report".
Before it, the addon with its version when the report gives it, as the game's own link titles an issue ("KaLi Recipe
0.9.0: …"), the addon alone otherwise, "KaLi" when none is found. The language label comes from the sender's words,
else from the game's language in the report.

Left alone: a machine's mail (a no-reply sender, a notification, a mailing list, a newsletter), and whatever the
account held before the mailbox was started: Google's own mail to the new account was filed as a proposal on the first
day (issue #1).

What is published is the mail's own text: the quote of the earlier mails, the signature and every mail address in it
are left out, and the sender's address never reaches GitHub. Attachments stay in Gmail; the issue says how many. An
absence reply or a bounce is never added. The issues are written by the token's owner, Ikar's GitHub account.

**The issues opened on GitHub** (the game's link, or by hand) are labelled the same way, when they are opened: their
kind, their addons and their language, read by this script's own functions from the title and the body
([label.js](label.js), run by `.github/workflows/label-issues.yml`; Ikar: "Yes" to labelling them as the mailed ones).
It adds labels, never takes one off, and leaves the mailed issues to the script.

## Setting it up, once

1. **The account:** KaLi's Gmail, with 2-Step Verification on, as the script reads and sends its mail.
2. **The GitHub token:** on github.com, Settings, Developer settings, Personal access tokens, **Fine-grained tokens**,
   Generate new token. Name it "KaLi mail". Expiration: the longest GitHub offers, and note the date: on that day
   GitHub refuses the token and the mailbox stops working until the token is renewed (below). Repository access:
   **Only select repositories**, Warcraft-KaLi. Permissions, Repository permissions: **Issues**, Read and write.
   Generate, and copy it.
3. **The script:** signed in to KaLi's Gmail, open [script.google.com](https://script.google.com), **New project**,
   name it "KaLi mail". Replace what `Code.gs` holds with [Code.gs](Code.gs) (its raw text:
   `https://github.com/Ikar-Rahl/Warcraft-KaLi/raw/main/tools/mail/Code.gs`), then save.
4. **The token, in the script:** Project Settings (the gear), Script Properties, **Add script property**: name
   `GITHUB_TOKEN`, value the token. Save. It stays there, never in the repository.
5. **Start it:** back in the editor, pick `setup` in the list of functions, **Run**. Google asks to allow the script
   to read and send the account's mail, reach GitHub and run on a timer; as the script is your own, "Google hasn't
   verified this app" is answered with **Advanced**, then **Go to KaLi mail**. The log then says the token works, the
   labels are made on both sides, and `run()` is on every five minutes, and every hour in case Google stops firing
   the first (it did once, on 2026-11-24, with no error). Running `setup` again is safe: it replaces both.
6. **Try it:** from another address, mail "KaLi Quest: a test bug" to KaLi's address. Within five minutes an issue
   labelled **by mail** and **bug** appears, and the test mail gets its link. Comment on the issue: the comment comes
   back by mail. Close it as not planned: that comes back too.

To change the script: paste the new `Code.gs` over the old one and save; the token and the timer stay. A run that
fails (an expired token: "GitHub answered 401") is mailed to the account by Google; its Triggers page sets how often.

**Renewing the token,** when it expires (GitHub warns by mail before): on github.com, the token's page, **Regenerate
token** (its settings stay), copy it; in the script, Project Settings, Script Properties, `GITHUB_TOKEN`: the new
value, saved. Nothing is lost meanwhile if it's done within 30 days: the mails wait in the inbox, and the next run files
them and catches up with the comments; the script looks no further back than 30 days.

## Its limits

- Google lets a free account's scripts send 100 mails a day: replies, answers and closings together.
- The issue can't hold the mail's pictures: GitHub's API takes none. They are read in Gmail.
- Only the last 30 days' mails are looked at. A mail under **No issue** that should have been filed: give it a
  kind's label (and, for the keywords, a word to add to `KINDS`).
- An answer written from KaLi's Gmail, rather than on GitHub, reaches the player and is added to the issue as
  "Answered by mail" (Ikar: "Yes"), its quote of the earlier mails left out; it isn't mailed to them twice.
- A mail archived before a run is left alone (Ikar has seen it); given a kind's label, it is filed even so.
- An issue deleted on GitHub: if its sender writes again, the thread is forgotten and comes back to the inbox under No
  issue (a reply to a deleted issue used to make every run fail).
- An issue closed as a duplicate says so in the closing mail; GitHub's other reasons read "closed".
- An addon can't send a mail itself: the report window shows the address, to copy (`Report.MAIL`, set in each addon's
  `UI/Report.lua`).

## Its tests

`node tools/mail/test.js` plays the script on a fake Gmail and a fake GitHub: a report, a proposal and a question
filed under their kinds and addons, the addon found by its words or left out when they are torn, a hello under No
issue then filed by hand, a reply added without its quote, an answer and a closing mailed once, nothing twice, no
address on GitHub.
`node tools/mail/breaks.js` undoes 42 of its safeguards one at a time; the test must fail each time.