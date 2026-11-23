// The KaLi border's looks, for the borders bench and hud/tools/make_media.py (which ships one of them): plain JSON
// after the assignment below. Lengths in UI units at 100 %: width, the metal; lines, a dark line each side of it;
// shadow, soft, outside and inside. polish 0..100: brushed (soft, even) to mirror (a bright sky over a dark horizon).
// color: the border's colour, its brightest reflections. bgTex: gradient, flat, dialog, marble, rock. corners: round,
// square or bevel, the plate's and our frames' (an Edit Mode setting; the look's is its default).
window.KALI_LOOKS = [
  {"id": "bronze", "name": "Bronze patiné", "note": "Un bronze à facettes, poli comme un miroir : une large face qui accroche la lumière, une arête nette, l'autre face sombre.",
   "width": 3.5, "profile": "facet", "polish": 100, "lines": 0.5, "shadow": 3.5, "corners": "round", "color": "#d6b386", "alpha": 100,
   "bgTex": "gradient", "bg": "#0d0b09", "bgAlpha": 100},
  {"id": "laiton", "name": "Laiton fin", "note": "Un fil de laiton poli, presque un trait de plume : discret, élégant.",
   "width": 1.5, "profile": "round", "polish": 70, "lines": 0.4, "shadow": 1, "corners": "round", "color": "#dccb9c", "alpha": 100,
   "bgTex": "flat", "bg": "#000000", "bgAlpha": 70},
  {"id": "brosse", "name": "Acier brossé", "note": "Une bande d'acier plate et mate, l'arête claire dessus, sombre dessous.",
   "width": 3, "profile": "flat", "polish": 10, "lines": 0.5, "shadow": 1.5, "corners": "square", "color": "#c9cdd1", "alpha": 100,
   "bgTex": "flat", "bg": "#1a1c1f", "bgAlpha": 92},
  {"id": "noir", "name": "Acier noir", "note": "Un métal presque noir, poli : seule l'arête accroche la lumière. Moderne.",
   "width": 2.5, "profile": "flat", "polish": 85, "lines": 0.6, "shadow": 2, "corners": "bevel", "color": "#9a9ea4", "alpha": 100,
   "bgTex": "flat", "bg": "#000000", "bgAlpha": 90},
  {"id": "fer", "name": "Fer forgé", "note": "Une lourde barre de fer chanfreinée, terne, posée sur la roche.",
   "width": 6, "profile": "bevel", "polish": 35, "lines": 0.8, "shadow": 3, "corners": "bevel", "color": "#8e8c88", "alpha": 100,
   "bgTex": "rock", "bg": "#6a665f", "bgAlpha": 100},
  {"id": "etain", "name": "Étain", "note": "Une gorge creusée dans un étain mat : deux arêtes douces, sans éclat.",
   "width": 5, "profile": "groove", "polish": 30, "lines": 0.4, "shadow": 1.5, "corners": "round", "color": "#b9bab3", "alpha": 100,
   "bgTex": "gradient", "bg": "#14161a", "bgAlpha": 100},
  {"id": "chrome", "name": "Chrome", "note": "Un jonc miroir : le ciel clair au-dessus, l'horizon noir au milieu, sur marbre.",
   "width": 2.5, "profile": "round", "polish": 100, "lines": 0.5, "shadow": 1.5, "corners": "round", "color": "#c4c8ce", "alpha": 100,
   "bgTex": "marble", "bg": "#4a4c50", "bgAlpha": 100},
  {"id": "bleui", "name": "Acier bleui", "note": "Un acier d'arme bleui au feu, chanfreiné et poli, froid, sur la nuit.",
   "width": 3, "profile": "bevel", "polish": 75, "lines": 0.6, "shadow": 2, "corners": "bevel", "color": "#a4afbf", "alpha": 100,
   "bgTex": "gradient", "bg": "#0c1016", "bgAlpha": 100},
  {"id": "double", "name": "Double jonc", "note": "Deux joncs d'or vieilli côte à côte, comme un cadre ancien.",
   "width": 4.5, "profile": "double", "polish": 60, "lines": 0.5, "shadow": 2, "corners": "square", "color": "#c8ad7f", "alpha": 100,
   "bgTex": "dialog", "bg": "#8a7a66", "bgAlpha": 100},
  {"id": "cuivre", "name": "Cuivre vieilli", "note": "Un chanfrein de cuivre sourd, rosé, à demi poli, sur un brun chaud.",
   "width": 4, "profile": "bevel", "polish": 50, "lines": 0.6, "shadow": 2, "corners": "bevel", "color": "#c4977c", "alpha": 100,
   "bgTex": "gradient", "bg": "#1a1210", "bgAlpha": 100}
];
// The status bars' border, whatever the look: one thin line between two dark halos, as FlareUI's XP bar has.
window.KALI_THIN = {"width": 1.25, "profile": "round", "polish": 20, "lines": 0, "shadow": 2.25};
