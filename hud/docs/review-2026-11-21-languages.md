# The languages, reviewed (2026-11-21)

Ikar, 2026-11-21: "Review the transition in detail, make sure everything make sense, clear, in each language. Take
your time." Read as the translations, of the three addons (the question before it was each one's languages and words).

## How it was read

Every string of the three `Core/Locale.lua`, side by side in French, English, German and Spanish (and Mexican
Spanish's own), in the file's order: KaLi Quest 231 keys, KaLi Recipe 223, KaLi HUD 727, some 30,000 words. Each
unclear string read again where the code shows it. Each word the game has its own for checked against this build's
game strings (`reference/BlizzardInterfaceResources/Resources/GlobalStrings/<locale>.lua`) and tables
(`reference/db2/1.60.1.70790`). Then the checks a reading misses, over all three: the forms of address, the quote
marks, the spelling, French spacing, Spanish's opening marks, double spaces, three dots for an ellipsis.

What was sound already: every language has every key, with English's blanks; no Spanish question or exclamation
lacks its opening mark; no double space, no "..." for "…"; KaLi Quest's and KaLi Recipe's German speak to the
player as the game does (Ihr, Euch, Euer), their Spanish too (tú); Mexican Spanish's own words are the game's
(Calabozos, Llamamiento, Marcador de mapa, modo de edición, disposición, Audio); yards are « mètres », « Meter »,
« metros » as in the game; tag 21 is « Life » / « Vie » as the game's own table names it (kept, organiser-design.md
says why); « Seguim. » on the Spanish Track bar is the game's `TRACK_QUEST_ABBREV`.

## Applied: KaLi Quest and KaLi Recipe

Offline-checked only, nothing seen in game: each addon's full run passes (its tests with the language test, the
smoke, the labels measured with the game's font: 220 texts for KaLi Quest, 285 for KaLi Recipe, all fitting). KaLi
Quest's smoke looked for « Métier : 2 · hauts faits : 1 » and now for « Recettes : 2 ».

KaLi Quest (37 edits):
- **French.** The diagnostics' « Métier : %d » counted the recipes tracked: « Recettes : %d ». « a du contenu, KaLi
  Quest gardé » said nothing clear: « a du contenu, suivi de KaLi Quest conservé » (the player kept KaLi Quest's
  tracker over a section that filled). « Fond de quête survolée » beside « au repos » and « en combat »: « au
  survol ». « le Mode Édition » inside a sentence: « le mode Édition », as the game writes it there. « reprend la
  main jusqu'à la fin » (the end of what?): « jusqu'à sa fin »; « le temps que ça dure »: « le temps qu'elle dure ».
  The tips' menu names quoted (« Déplacer vers » sur une quête, …), so they read as names; « Fige l'ouverture »:
  « Fige ce qui est ouvert ». « addon » nine times: « add-on », the game's word and KaLi HUD's.
- **English.** « has contents, KaLi Quest kept »: « …, KaLi Quest's tracker kept ». The tips' menu names quoted,
  « Delete » as the menu says it, « Delete the group ». « Grey »: « Gray », the game's spelling.
- **German.** KaLi Quest's tracker was « Zielverfolgung », a word the game never uses (alone it reads as target
  tracking): « Questverfolgung », the game's word for the quest tracker, 18 times; Blizzard's is the game's
  « Questzielverfolgung » (5 places, « Blizzards Zielverfolgung » before). « Wenn aus, kommt … zurück » (clipped):
  « Ist sie aus, kehrt … zurück ». The chat lines after « KaLi Quest: » that are whole sentences start with a
  capital, as German has it after a colon (an error, the tracker failing or back, the game not answering, the saved
  data refused). « Verschieben in eine Gruppe »: « In eine Gruppe verschieben ». « auf das Ende »: « auf das
  Kampfende ». The tips: « fügt es ihren Link ein » (es?): « fügt er » (the click); « Eine davon ziehen, oder ihr
  Rechtsklickmenü, wirkt auf alle » (no grammar): « Das Ziehen einer davon und ihr Rechtsklickmenü wirken auf alle »;
  the menu names quoted.
- **Spanish.** « Misiones en reposo / en combate / bajo el ratón » under Opacidad read as the quests' own opacity:
  « Recuadro en reposo », … (the English « Quest box »; « Fondo de misión en reposo » took three lines of the two the
  label has). « tiene contenido, KaLi Quest mantenido »: « tiene
  contenido, se mantiene el rastreador de KaLi Quest ». The tips' menu names quoted.

KaLi Recipe (23 edits):
- **French.** « Entraîneurs » in the sources' filter, « maître » in its three tips: « Maîtres de métier », the game's
  (it never says entraîneur). « plus haut » for a rank: « plus élevé ». « à 100% »: « à 100 % ». The options' button
  tip (« dans une fenêtre à elles, … qui le laisse ouvert … et l'ouvre »): « ont leur propre fenêtre, à côté du carnet,
  qui reste ouvert pendant qu'on les règle. Ce bouton ferme les options du jeu et ouvre cette fenêtre. » « addon »
  seven times: « add-on ».
- **English.** « Sounds volume »: « Sound volume ». « And vendors another visited count as visited »: « … another of
  your characters visited … ». « … closes the game's options and opens it » (the window or the notebook?): « …
  opens that window ». « colour », « grey »: « color », « gray »; the quote marks straight then, “ ” since (below).
- **German.** The chat lines after « KaLi Recipe: » with a capital, as KaLi Quest's. « Zeilen höchstens »: « Maximale
  Zeilenzahl ». « Das Fenster des Spiels, bei %s »: « …, auf %s geöffnet ». The options' button tip had the same
  « es » for the window or the notebook: « … und öffnet dieses Fenster ». « Bei 100% »: « Bei 100 % ».
- **Spanish.** « al 100% »: « al 100 % » (Castilian and Mexican).

## KaLi HUD: prepared, then applied

Another session was working on the HUD the same day, on the attributes' card itself (Locale.lua, Stats.lua and
design.md saved at 18:45): two sessions on one file is against `AGENTS.md`. The edits were written and tried on a copy
(`review-2026-11-21-languages/`: every one finds its place, every language keeps English's blanks), then applied once
that session said it was done (111 of them, the quote marks' four left to each language's rules, below):
- **German speaks to the player two ways.** Sixteen strings in the polite Sie (« die Sie geändert haben », « trifft
  Sie nie mehr kritisch », « keiner Ihrer Angriffe », « Ihr Ziel »), the rest in the game's Ihr, Euch, Euer, both
  within one card (« Euer Ziel » two lines above « Ihr Ziel »): all Euch, as the game and the other two addons.
- **Spanish too.** The attributes' card in usted (« un enemigo de su nivel », « sus golpes blancos », « vea el golpe »,
  « su objetivo ») beside « Tu objetivo », « apunta a la más alta », « no esperes »: all tú.
- **Spanish's card and sheet.** « ficha » was both the HUD's card (« la ficha muestra en azul ») and the character
  sheet (« el cálculo de la ficha del juego »), with « hoja » and « tarjeta » besides: the card is « tarjeta », the
  sheet « ficha ».
- **The card's « Comment » and « Pourquoi » rewritten in all four,** the same figures: they were hard to follow in
  every language, English first (« its 5% of critical strikes, which each point past your most takes 0.04% from »,
  « the line wears the highest reached, each under it reached too »). Now each says what the figure is, where it
  comes from, then what the numerals are (« In the list, the attribute's line shows the highest one reached, as long
  as every one below it is reached too »). « Most it takes away », « Most on average »: « Maximum reduction »,
  « Highest average ».
- **The game's words.** Glancing blows: « Éraflures » (the game's « Éraflure », « Coups déviés » before), German
  « Streifschläge » (« Gestreift »; « Abgewehrte Schläge » before); crushing, German « schmetternde » (« Schmetternd »;
  « zerschmetternde » before). German « Beim Überfahren » (the game never) : « Bei Mouseover » (27 times in the game);
  « Minimap-Ring »: « Minikarten-Ring »; « ein anderes Konto »: « einen anderen Account » (225 to 2 in the game);
  « [Clic] Währungen » beside « [Clic] Abzeichen » for the same window: « Abzeichen », the game's.
- **Broken or unclear.** German « Keine: Setzt in der Währungsübersicht bei einer Währung „%s“ » (no object): « Keine:
  Kreuzt im Abzeichenfenster bei einem Abzeichen "%s" an ». English « unifies minimap buttons with the bottom slot
  bar »: « gathers the minimap's buttons with the info bar's elements » (the four languages); « Inner socket padding
  around bars »: « The room left around the bars inside their recess in the plate »; « Gap bridge »: « Gap closing »,
  as its command says. French « que vous avez changé vous-même » (des réglages): « changés ». German « setzt es zurück,
  wo es war »: « bringt es dorthin zurück, wo es war »; « Kopiert: fügt es ein »: « Fügt »; the chat lines' capitals.
- **One word for one thing.** Spanish « Borrar el separador » among « Eliminar »: « Eliminar ». German « Angeln
  hier » beside its tip « Hier angeln: »: « Hier angeln »; Spanish « Pesca aquí » beside « Pescar aquí: »: « Pesca
  aquí: ». French « l'addon » twice among « add-on ».
- **Labels cut to fit, given back what they say** (an options row of one line, all three measured to fit): « Discussion
  pendant la saisie » → « Discussion repliée à la saisie »; « Déplier les dégâts en combat » → « Déplier le compteur en
  combat »; « Desplegar daño en combate » → « Desplegar medidor en combate ».
- **Spelling and marks.** English « colour », « behaviour », « grey », « bevelled » beside the game's « armor »,
  « defense », « honor »: American throughout, as the game. Quote marks: English “…” and "…", German „…“ and "…",
  Spanish «…» and "…": first made straight, as the game's text in those three languages; then each language's own,
  on Ikar's answer (below).

## Put to Ikar, and his answers

Asked in the reply of 2026-11-21, by number:
1. The HUD's edits, once the session on the attributes' card was done. Done (that session said so).
2. The chat lines' colon: « KaLi Quest : an error occurred. Type /kq errors for details. » with French's space in
   every language. The game's `HEADER_COLON` is « :» after a no-break space in French, « : » alone elsewhere.
3. French spacing: 241 plain spaces before « : ; ? ! » », none no-break; a long tooltip can wrap with « : » or « ? »
   starting a line.
4. The folder icons' names: 112 of 246 French and English only; a German or Spanish player read « Flight path ».
5. KaLi Quest and KaLi Recipe wrote the mouse buttons in words, where the HUD shows the house editor's icons.

His answer: "About icons, yes. As much as possible. And make the translation correct in each language, with each
language it own rules. Also, each language in it own file." Read as: yes to 4 and 5; each language's own typography
and grammar, its own quote marks (not the game's straight ones), its colon (2 and 3); one file a language. What was
built: hud/docs/design.md's « The languages, 2026-11-21 ».
