# 04 — M3 : Layout hybride « chaînes + mini-bus »

**But** : produire une usine qui **tourne réellement**. Layout **hybride** (révisé après essai
du bus complet, trop coûteux : ~10 lanes pour des blocs d'1-6 machines sur un plan réel) :

- **Alimentation directe (chaîne)** : un item produit par un bloc et consommé par **un seul**
  autre bloc ne passe pas par le bus — le producteur est posé **juste au-dessus** du
  consommateur et sa belt de sortie **est** la belt d'entrée du suivant.
- **Mini-bus** : seuls les **ingrédients de base** (fournis de l'extérieur), les intermédiaires
  **partagés** (≥ 2 consommateurs) et les **produits finaux** ont une lane.

C'est ce qu'un joueur dessine à la main : des colonnes de production compactes qui tapent sur
un petit bus. Découpage : **M3a** (périmètre restreint, bouclé en jeu) puis **M3b**.

---

## 1. Conventions de repère

- Repère **tuiles**, `x` vers la droite, `y` vers le bas.
- **Bus** : lanes verticales (belts **sud**), côté gauche (`x = 0..nb_lanes-1`). 1 lane = 1 item.
- **Chaînes de blocs** : empilées verticalement à droite du bus (`x ≥ nb_lanes + MARGIN`).
  Une chaîne = suite de blocs reliés en alimentation directe, du producteur (haut) au
  consommateur (bas). Les chaînes se succèdent verticalement (une colonne en M3a).

## 2. Rôles des items

Calculés dans `layout` à partir des blocs de l'IR :

| Rôle | Définition | Traitement |
|---|---|---|
| **base** | consommé, jamais produit | lane de bus (injection en haut) |
| **direct** | 1 producteur, **1 consommateur**, blocs routables des deux côtés | alimentation directe (pas de lane) |
| **partagé** | produit ici, ≥ 2 consommateurs (ou 2 producteurs, ou direct impossible) | lane de bus |
| **final** | produit, jamais consommé | lane de bus (sortie en bas) |

## 3. Formation des chaînes (règles)

- Arête directe `A → B` possible si : l'item est mono-producteur ET mono-consommateur,
  `A` et `B` sont **routables** (§5), `B` n'a pas déjà une entrée directe, `A` pas déjà une
  sortie directe (≤ 1 arête entrante et sortante par bloc → les chaînes sont des **chemins**).
- Si un bloc a plusieurs entrées candidates : choisir celle au **plus gros débit**
  (départage par nom → déterminisme) ; les autres retombent sur le bus.
- Comme le périmètre M3a limite à **2 ingrédients**, un bloc chaîné a au plus **1 entrée bus**.
- Cycles éventuels (recyclage) : cassés arbitrairement + avertissement.
- **Ordre vertical** : tri topologique des **chaînes** (graphe condensé via les items de bus :
  la chaîne qui produit un item partagé est posée au-dessus des chaînes qui le consomment).
  Déterministe (files triées par id).

## 4. Ordre des lanes du bus

Groupes de gauche à droite : **base**, puis **partagés**, puis **finaux** — chaque groupe trié
par nom. Stable et reproductible (2 générations ⇒ blueprint identique).

## 5. Gabarit d'un bloc (M3a)

**Routable** = machine **3×3**, **≤ 2 ingrédients** solides, **1 produit** solide.
Non-routable ⇒ machines posées, I/O non câblées + avertissement.

Bloc de `N` machines = **une rangée**, largeur `N*3`, hauteur **8**. Deux saveurs :

**Tête de chaîne** (toutes entrées depuis le bus) — offsets `y` relatifs au haut :
```
y+0 : belt entrée FAR  (ingrédient #2, si présent)      → est
y+1 : belt entrée NEAR (ingrédient #1 = plus gros débit) → est
y+2 : inséreurs : cols 0,2 normaux (prise y+1) ; col 1 long (prise y+0) si #2
y+3..5 : machines
y+6 : inséreurs de sortie (prise nord = machine, dépose sud = belt)
y+7 : belt de SORTIE → ouest
```

**Bloc chaîné** (entrée directe depuis le bloc du dessus) — **partage sa rangée `y+0` avec
la belt de sortie du bloc précédent** (le bloc commence au `y+7` du précédent → −3 rangées
et −1 belt par jonction) :
```
y+0 : belt PARTAGÉE (= sortie du bloc précédent ; item direct)
y+1 : belt entrée bus (l'éventuel 2e ingrédient) → est
y+2 : inséreurs : cols 0,2 LONGS (prise y+0, item direct) ; col 1 normal (prise y+1) si entrée bus, sinon long
y+3..7 : comme la tête (machines, inséreurs sortie, belt sortie)
```
Si les largeurs diffèrent, la belt partagée est **prolongée** à la largeur du plus large.

Inséreurs : `direction` = **côté de prise** (vérité terrain §8). Nord pour toutes les entrées
(prise belt au nord, dépose machine au sud) et pour les sorties (prise machine au nord,
dépose belt au sud).

## 6. Connexion bus ↔ bloc (incrément 2 — routing.lua)

- Lanes **espacées de 2** (colonne libre à droite de chaque lane, pour les splitters).
  Lanes **élaguées** : pas de lane pour un item sans extrémité routable.
- **Prise (entrée de bloc, rangée R)** : **splitter inline** sur la lane en rangée `R-1`
  (sortie gauche = la lane continue, sortie droite = belt **est** en rangée `R` jusqu'à la
  belt d'entrée du bloc). Les splitters se débordent naturellement : si le bloc est plein,
  tout continue sur la lane.
- **Rejet (sortie de fin de chaîne, rangée R)** : belts **ouest** depuis le bloc jusqu'à la
  colonne `lane.x+1`, puis **side-load** sur la belt sud de la lane (pas de splitter).
- **Croisements** : c'est **la lane qui passe en souterrain** (hop vertical `ug_in`/`ug_out`
  autour des rangées croisées, croisements consécutifs groupés, portée `meta.underground_max`),
  la belt horizontale reste continue en surface.
- Conflits de cellules (occupancy grid) → connexion abandonnée + **avertissement** (pas de crash).

## 7. Débits & multi-belt

- **M3a** : 1 belt par item ; dépassement de capacité ⇒ avertissement, 1 lane quand même.
- **M3b** : multi-lane, tiers de belt selon débit ; **2 items par belt** (2 lanes physiques
  d'une même belt, side-loading) pour les recettes à 3-4 ingrédients.

## 8. Vérité terrain (validée en jeu, 2.0)

- `direction` : encodage **16 directions** — nord=0, **est=4**, sud=8, ouest=12.
- **Belt** : `direction` = sens du flux.
- **Inserter** : `direction` = **côté de PRISE** (dépose du côté opposé). `direction=north`
  ⇒ prend au nord, dépose au sud. (Contre-intuitif — confirmé par test.)
- **Underground** : `type = "input"` (amont) / `"output"` (aval), `direction` = sens du flux.

## 9. Structure de code

- `layout.lua` : IR → **parts** (rôles, chaînes, tri topo, lanes, gabarits).
- `routing.lua` (incrément 2) : parts += splitters/undergrounds/belts bus↔blocs.
- `emit.lua` : parts → `array[BlueprintEntity]`.
- Format **parts** : `{ kind="machine"|"belt"|"underground"|"splitter"|"inserter",
  name, x, y, direction?, ug_type?, recipe?, quality?, modules? }` (coin haut-gauche en tuiles).

## 10. Critères d'acceptation (M3a)

- [ ] Chaîne 2 recettes (câble → circuit vert) : blocs **empilés en chaîne** partageant leur
      belt (pas de lane câble sur le bus) ; bus = `copper-plate`, `iron-plate`,
      `electronic-circuit` seulement.
- [ ] En injectant les plaques en haut des lanes, l'usine **produit des circuits** en sortie,
      sans blocage (test éditeur, sources infinies).
- [ ] Chaque machine routée reçoit tous ses ingrédients.
- [ ] Aucun chevauchement ; blueprint posable d'un coup ; sortie déterministe.
- [ ] Hors périmètre (≥3 ingrédients, fluides, non-3×3, >1 belt) ⇒ avertissement, pas de crash.
- [ ] Plan ~50 machines < 1 s.

## 11. Stratégie de test

- **Boucle fermée en éditeur** : sources infinies sur les lanes de base, observer la sortie.
- **Cas de référence** : circuits verts (1 chaîne de 2 + bus 3 lanes) ; plan « bras » (chaînes
  + recettes 3 ingrédients → avertissements attendus).

## 12. Hors scope M3a → M3b/M4

Recettes ≥3 ingrédients (→ 2 items/belt), machines non-3×3, fluides, multi-belt, beacons,
électricité, multi-colonnes de chaînes, insertion directe machine-à-machine (sans belt),
minimisation des croisements, priorités de splitters.
