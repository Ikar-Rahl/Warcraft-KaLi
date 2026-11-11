// Made by recipe/tools/bench_sounds.py from the addon's Core/Sounds.lua and this build's sound
// tables: the sounds the in-game options offer, to hear them on the bench.
window.SOUNDS = {
 "build": "1.60.1.70790",
 "defaults": {
  "recipe": "quill",
  "place": "stroke"
 },
 "quiet": 3,
 "fade": 0.2,
 "options": {
  "fr": {
   "OPT_CHAT_SECTION": "Annonces",
   "OPT_SOUND_RECIPE": "Son d'une nouvelle recette",
   "OPT_SOUND_RECIPE_TIP": "Quand une visite note une recette qui n'était pas encore dans le carnet. Un son du jeu, au volume des effets sonores ; choisi, il se fait entendre.",
   "OPT_SOUND_PLACE": "Son d'un nouvel endroit",
   "OPT_SOUND_PLACE_TIP": "Quand une visite note un nouvel endroit pour une recette déjà dans le carnet. Un seul son par visite.",
   "SOUND_NONE": "Aucun"
  },
  "en": {
   "OPT_CHAT_SECTION": "Announcements",
   "OPT_SOUND_RECIPE": "Sound for a new recipe",
   "OPT_SOUND_RECIPE_TIP": "When a visit notes a recipe that wasn't in the notebook yet. A sound of the game's, at the sound effects volume; picked, it plays.",
   "OPT_SOUND_PLACE": "Sound for a new place",
   "OPT_SOUND_PLACE_TIP": "When a visit notes a new place for a recipe already in the notebook. One sound per visit.",
   "SOUND_NONE": "None"
  }
 },
 "kinds": {
  "recipe": [
   {
    "key": "quill",
    "kit": 3093,
    "name": "IG_WRITE_QUEST",
    "stop": null,
    "fr": "Plume qui écrit",
    "en": "Quill writing",
    "volume": 0.3,
    "takes": [
     {
      "file": "art/sounds/567396.ogg",
      "seconds": 2.95
     },
     {
      "file": "art/sounds/567445.ogg",
      "seconds": 2.64
     },
     {
      "file": "art/sounds/567503.ogg",
      "seconds": 2.2
     }
    ],
    "use": "the quest log's quill, when a quest is accepted: three takes of 2.2 to 3 s, one at random"
   },
   {
    "key": "note",
    "kit": 3093,
    "name": "IG_WRITE_QUEST",
    "stop": 0.9,
    "fr": "Quelques mots",
    "en": "A few words",
    "volume": 0.3,
    "takes": [
     {
      "file": "art/sounds/567396.ogg",
      "seconds": 2.95
     },
     {
      "file": "art/sounds/567445.ogg",
      "seconds": 2.64
     },
     {
      "file": "art/sounds/567503.ogg",
      "seconds": 2.2
     }
    ],
    "use": "the same quill, stopped after 0.9 s and fading out"
   },
   {
    "key": "stroke",
    "kit": 3093,
    "name": "IG_WRITE_QUEST",
    "stop": 0.4,
    "fr": "Trait de plume",
    "en": "Quill stroke",
    "volume": 0.3,
    "takes": [
     {
      "file": "art/sounds/567396.ogg",
      "seconds": 2.95
     },
     {
      "file": "art/sounds/567445.ogg",
      "seconds": 2.64
     },
     {
      "file": "art/sounds/567503.ogg",
      "seconds": 2.2
     }
    ],
    "use": "the same quill, stopped after 0.4 s and fading out"
   },
   {
    "key": "parchment",
    "kit": 1209,
    "name": "file 567556",
    "stop": null,
    "fr": "Parchemin posé",
    "en": "Parchment laid down",
    "volume": 0.5,
    "takes": [
     {
      "file": "art/sounds/567556.ogg",
      "seconds": 0.33
     }
    ],
    "use": "the bags' sound for a paper item laid down"
   },
   {
    "key": "sheet",
    "kit": 1192,
    "name": "file 567562",
    "stop": null,
    "fr": "Parchemin pris",
    "en": "Parchment picked up",
    "volume": 0.6,
    "takes": [
     {
      "file": "art/sounds/567562.ogg",
      "seconds": 0.52
     }
    ],
    "use": "the bags' sound for a paper item picked up"
   }
  ],
  "place": [
   {
    "key": "quill",
    "kit": 3093,
    "name": "IG_WRITE_QUEST",
    "stop": null,
    "fr": "Plume qui écrit",
    "en": "Quill writing",
    "volume": 0.3,
    "takes": [
     {
      "file": "art/sounds/567396.ogg",
      "seconds": 2.95
     },
     {
      "file": "art/sounds/567445.ogg",
      "seconds": 2.64
     },
     {
      "file": "art/sounds/567503.ogg",
      "seconds": 2.2
     }
    ],
    "use": "the quest log's quill, when a quest is accepted: three takes of 2.2 to 3 s, one at random"
   },
   {
    "key": "note",
    "kit": 3093,
    "name": "IG_WRITE_QUEST",
    "stop": 0.9,
    "fr": "Quelques mots",
    "en": "A few words",
    "volume": 0.3,
    "takes": [
     {
      "file": "art/sounds/567396.ogg",
      "seconds": 2.95
     },
     {
      "file": "art/sounds/567445.ogg",
      "seconds": 2.64
     },
     {
      "file": "art/sounds/567503.ogg",
      "seconds": 2.2
     }
    ],
    "use": "the same quill, stopped after 0.9 s and fading out"
   },
   {
    "key": "stroke",
    "kit": 3093,
    "name": "IG_WRITE_QUEST",
    "stop": 0.4,
    "fr": "Trait de plume",
    "en": "Quill stroke",
    "volume": 0.3,
    "takes": [
     {
      "file": "art/sounds/567396.ogg",
      "seconds": 2.95
     },
     {
      "file": "art/sounds/567445.ogg",
      "seconds": 2.64
     },
     {
      "file": "art/sounds/567503.ogg",
      "seconds": 2.2
     }
    ],
    "use": "the same quill, stopped after 0.4 s and fading out"
   },
   {
    "key": "parchment",
    "kit": 1209,
    "name": "file 567556",
    "stop": null,
    "fr": "Parchemin posé",
    "en": "Parchment laid down",
    "volume": 0.5,
    "takes": [
     {
      "file": "art/sounds/567556.ogg",
      "seconds": 0.33
     }
    ],
    "use": "the bags' sound for a paper item laid down"
   },
   {
    "key": "sheet",
    "kit": 1192,
    "name": "file 567562",
    "stop": null,
    "fr": "Parchemin pris",
    "en": "Parchment picked up",
    "volume": 0.6,
    "takes": [
     {
      "file": "art/sounds/567562.ogg",
      "seconds": 0.52
     }
    ],
    "use": "the bags' sound for a paper item picked up"
   }
  ]
 }
};
