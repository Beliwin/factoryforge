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

## 5. Gabarit d'un bloc (M3a + M3b)

**Routable** = machine **3×3**, **≤ 3 ingrédients** solides (M3b), **1 produit** solide.
Non-routable ⇒ machines posées, I/O non câblées + avertissement.

Bloc de `N` machines = **une rangée**, largeur `N*3`, hauteur **8** (≤2 ingrédients bus)
ou **9** (3ᵉ ingrédient → belt SUD). Offsets `y` relatifs au haut :

**Tête de chaîne** (toutes entrées depuis le bus) :
```
y+0 : belt FAR   (3e priorité : ins[2] si 2 ingr., ins[3] si 3) → est, col 1 long
y+1 : belt NEAR  (ins[1] = plus gros débit) → est, cols 0,2 normaux
y+2 : inséreurs d'entrée nord
y+3..5 : machines
--- si ≤ 2 ingrédients (validé M3a, inchangé) ---
y+6 : inséreurs de sortie (3/machine, prise nord)
y+7 : belt de SORTIE → ouest
--- si 3 ingrédients ---
y+6 : cols 0,2 : inséreurs SUD (prise y+7 = 2e ingrédient) ; col 1 : inséreur LONG
      prise nord (machine) → dépose y+8 par-dessus la belt sud = SORTIE
y+7 : belt entrée SUD (ins[2], 2 inséreurs/machine) → est
y+8 : belt de SORTIE → ouest
```
Assignation tête 3 ingr. : `near=ins[1]` (2 ins/machine), `sud=ins[2]` (2), `far=ins[3]` (1).

**Bloc chaîné** : rangée `y+0` = belt PARTAGÉE (sortie du précédent, item direct, cols 0,2
longs), `y+1` = belt bus n°1 (col 1 normal), et si 2e entrée bus → belt SUD `y+7` comme
ci-dessus. Le bloc commence au rang de sortie du précédent ; belt partagée prolongée si
le bloc est plus large.

Inséreurs : `direction` = **côté de prise** (vérité terrain §8). Entrées nord : nord ;
entrées sud : sud ; sorties : nord (prise machine) — le long de sortie dépose à 2 tuiles.

Recettes à **4 ingrédients** : hors scope (avertissement) — nécessiterait la composition
2 items/voie de belt, repoussée (M4).

## 6. Connexion bus ↔ bloc (incrément 2 — routing.lua)

- Lanes **espacées de 3** (M3b — 1 colonne pour le splitter + 1 colonne franche, pour que
  les routes horizontales puissent **ponter en souterrain** par-dessus les splitters des
  autres lanes). Lanes **élaguées** : pas de lane pour un item sans extrémité routable.
- **Ordre de routage : entrées triées par rangée décroissante**, puis sorties. Garantit
  qu'une route posée à la rangée R ne bloque jamais un splitter futur (toujours plus haut),
  et que les conflits restants se résolvent par pontage souterrain horizontal.
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

- **M3a/b** : 1 belt par item ; dépassement de capacité ⇒ avertissement, 1 lane quand même.
- **M4** : multi-lane, tiers de belt selon débit ; composition « 2 items par belt » si un
  jour nécessaire (4 ingrédients) — écartée en M3b car elle exige un accès des deux côtés
  de la belt cible, incompatible avec le gabarit compact.

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

## 10. Critères d'acceptation (M3a) — **validé en jeu le 2026-07-14**

- [x] Chaîne 2 recettes (câble → circuit vert) : blocs **empilés en chaîne** partageant leur
      belt (pas de lane câble sur le bus) ; bus = `copper-plate`, `iron-plate`,
      `electronic-circuit` seulement.
- [x] En injectant les plaques en haut des lanes, l'usine **produit des circuits** en sortie,
      sans blocage (⚠️ électricité à fournir manuellement — prévue en M4).
- [x] Chaque machine routée reçoit tous ses ingrédients.
- [x] Aucun chevauchement ; blueprint posable d'un coup.
- [x] Hors périmètre (≥3 ingrédients, non-3×3) ⇒ avertissement, pas de crash (plan « bras »).
- [ ] Sortie déterministe (2 générations identiques) — non vérifié formellement.
- [ ] Plan ~50 machines < 1 s — non mesuré (instantané à l'usage sur ~15 machines).

## 11. Stratégie de test

- **Boucle fermée en éditeur** : sources infinies sur les lanes de base, observer la sortie.
- **Cas de référence** : circuits verts (1 chaîne de 2 + bus 3 lanes) ; plan « bras » (chaînes
  + recettes 3 ingrédients → avertissements attendus).

## 12. Hors scope M3a → M3b/M4

Recettes ≥3 ingrédients (→ 2 items/belt), machines non-3×3, fluides, multi-belt, beacons,
électricité, multi-colonnes de chaînes, insertion directe machine-à-machine (sans belt),
minimisation des croisements, priorités de splitters.
