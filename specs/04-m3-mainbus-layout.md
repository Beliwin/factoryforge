# 04 — M3 : Layout main-bus (belts + inserters)

**But** : produire une usine qui **tourne réellement** — ingrédients de base injectés en haut
d'un bus vertical, blocs de recettes qui tapent dessus, produit final récupéré en bas. Pattern
main-bus classique, généré par heuristiques. Pas d'optimalité : **correct, lisible, buildable**.

On découpe en **M3a** (périmètre restreint mais bouclé en jeu) puis **M3b** (généralisation).

---

## 1. Conventions de repère

- Repère **tuiles**, `x` vers la droite, `y` vers le bas.
- Le **bus** est un ensemble de **lanes verticales** (belts orientées **sud**, l'item descend),
  côté gauche (`x = 0, 1, 2, …`). Une lane = 1 item = 1 tuile de large.
- Les **blocs** de recettes sont empilés **verticalement** à droite du bus
  (`x ≥ BUS_WIDTH + MARGIN`), un bloc par bande horizontale.
- Sens de production = **haut → bas** : un item est *produit* plus haut qu'il n'est *consommé*.

## 2. Prérequis sur l'IR (petits ajouts à `extract`)

Le layout a besoin, en plus de l'IR actuelle (`01-data-model.md`) :

- `plan.meta.products` : noms des **produits finaux** du factory (depuis `packed.products`).
  → lanes qui *sortent* en bas du bus.
- Rôle de chaque item, calculé dans `layout` (pas dans extract) à partir des blocs :
  - `produced_by[item]` = bloc dont `outputs` contient l'item (au plus 1 en M3a).
  - `consumed_by[item]` = liste des blocs dont `inputs` contient l'item.
  - **base** = consommé mais jamais produit → entre en haut du bus (source externe = le joueur).
  - **intermédiaire** = produit par un bloc ET consommé par un autre.
  - **final** = dans `meta.products` → sort en bas.

## 3. Ordre des blocs (tri topologique)

Placer un bloc produisant `X` **au-dessus** de tout bloc consommant `X`, pour que la lane de `X`
existe (mergée sur le bus) avant d'être tapée plus bas.

- Graphe orienté : arête `A → B` si un `output` de `A` est un `input` de `B`.
- **Tri topologique** → ordre vertical des blocs. (FP liste souvent le produit final en premier ;
  ne pas se fier à son ordre, recalculer.)
- Cycles (rare : boucles de recyclage) → casser arbitrairement + `log` un avertissement.

## 4. Ordre des lanes du bus (déterministe)

- Lanes de gauche à droite : d'abord les **base** (dans l'ordre d'apparition), puis les
  **intermédiaires** (dans l'ordre des blocs producteurs), puis les **finaux**.
- Ordre **stable et reproductible** (2 générations du même plan ⇒ blueprint identique).
- Minimisation des croisements = **hors scope M3a** (optimisation M3b).

## 5. Gabarit d'un bloc (M3a)

**Hypothèse M3a : machines 3×3** (assembleur 1/2/3, usine électromag., usine chimique). Machines
non-3×3 (fonderie 5×5, etc.) ⇒ posées mais **non routées + avertissement** (M3b).

Recette à `N` machines en **une rangée horizontale**. Offsets `y` relatifs au haut du bloc :

```
y=0 : lane belt entrée ingrédient #2  (I2), horizontale
y=1 : lane belt entrée ingrédient #1  (I1), horizontale
y=2 : rangée d'inséreurs NORD  (pickup depuis I1/I2, drop SUD dans la machine)
y=3..5 : les N machines 3×3, adjacentes horizontalement  (largeur = N*3)
y=6 : rangée d'inséreurs SUD  (pickup produit machine, drop SUD sur la sortie)
y=7 : lane belt SORTIE produit, horizontale
```

**Alimentation multi-ingrédients sur le côté nord (cœur du gabarit M3a) :**
- I1 sur `y=1` : **inséreur normal** en `y=2` (pickup 1 tuile = `y=1`).
- I2 sur `y=0` : **inséreur longue-portée** (`long-handed-inserter`) en `y=2` (pickup 2 tuiles = `y=0`,
  par-dessus la belt `y=1`).
- Répartition sur les 3 colonnes d'une machine : ex. colonnes 0 et 2 → I1 (normal),
  colonne 1 → I2 (long). Alimentation approximative mais suffisante (les machines lissent).
- **1 seul ingrédient** ⇒ pas de lane I2, que des inséreurs normaux.

**Sortie :** inséreur (`y=6`) prend le produit de chaque machine → dépose sur la belt `y=7`.

→ Un bloc fait **`N*3` de large × 8 de haut**.

**Périmètre routé M3a :** recettes à **1–2 ingrédients solides** et **1 produit solide**.
Au-delà (≥3 inputs, multi-produits, fluides) ⇒ machines posées, I/O **non routées** + `log`.

## 6. Connexion bus ↔ bloc

Pour chaque lane d'entrée du bloc (I1, I2) :
- **Prise** sur la lane de bus correspondante via un **splitter** (dérive une partie du flux).
- Une **belt horizontale** amène l'item du bus jusqu'à la lane d'entrée du bloc, en **passant en
  souterrain** (`underground-belt`) sous chaque lane de bus / obstacle traversé
  (respecter `meta.underground_max`).

Pour la sortie du bloc (`y=7`) :
- Belt horizontale ramène le produit vers le bus (undergrounds pour les croisements),
- **merge** sur la lane de l'item via un splitter (ou side-load) — création de la lane si l'item
  est un intermédiaire produit ici pour la première fois.

*Détail d'implémentation du routage (placement exact des undergrounds/splitters) laissé au code ;
la spec fixe les règles, l'acceptation se fait en jeu (usine qui tourne).*

## 7. Débits & multi-belt

- **M3a** : 1 belt par item, on suppose débit ≤ capacité de `meta.belt`. Dépassement ⇒ `log`
  d'avertissement, 1 lane quand même.
- **M3b** : multi-lane, choix du tier de belt selon débit, balancers.

## 8. Entités à émettre (nouvelles pour `emit`)

En plus des machines (M2), `emit` doit gérer :

| Entité | Champs BlueprintEntity clés |
|---|---|
| `transport-belt` | `name`, `position`, **`direction`** (sens du flux) |
| `underground-belt` | + **`type` = "input" \| "output"**, `direction` |
| `splitter` | `direction`, (filtres/priorités : hors M3a) |
| `inserter` / `long-handed-inserter` | **`direction`** = sens **pickup→drop** |

> ✅ **Vérité terrain (validée en jeu, 2.0)** :
> - `direction` : encodage **16 directions** — nord=0, **est=4**, sud=8, ouest=12.
> - **Belt** : `direction` = sens du flux (est=4 → vers la droite).
> - **Inserter** : `direction` = **côté de PRISE** (dépose du côté opposé !). `direction=north`
>   ⇒ prend au nord, dépose au sud. (Contre-intuitif — confirmé par test, inséreurs inversés
>   quand on met le sens de dépose.)
> - **Underground** : champ `type = "input"` (entrée, côté amont) / `"output"` (sortie, côté aval),
>   `direction` = sens du flux.

## 9. Structure de code

- Nouveau module `layout.lua` : IR → **placement** (bus + gabarits de blocs + rôles/ordre).
- Nouveau module `routing.lua` : ajoute belts/inséreurs/undergrounds reliant bus ↔ blocs.
- `emit.lua` : **placement → array[BlueprintEntity]** (étendu pour les nouveaux types).
- Format **placement** (intermédiaire, indépendant de l'API BP) :
  ```lua
  { kind="machine"|"belt"|"underground"|"splitter"|"inserter",
    name=..., x=..., y=...,           -- coin haut-gauche en tuiles
    direction=defines.direction.*,     -- si applicable
    ug_type="input"|"output",          -- undergrounds
    recipe=..., quality=..., modules={...} }  -- machines
  ```
  `emit` calcule centre + `entity_number` + `items` (modules) comme en M2.

## 10. Critères d'acceptation (M3a)

- [ ] Chaîne 2 recettes (câble cuivre → circuit vert) : en injectant `copper-plate` + `iron-plate`
      sur les lanes de base en haut, l'usine **produit `electronic-circuit`** en sortie, en
      régime établi, **sans blocage** (test en éditeur/créatif, sources infinies sur les lanes).
- [ ] Chaque machine routée reçoit tous ses ingrédients (aucune machine « no ingredients »).
- [ ] Les intermédiaires produits atteignent leurs consommateurs via le bus.
- [ ] Aucun chevauchement de collision ; blueprint posable d'un coup.
- [ ] Sortie **déterministe** (2 générations identiques).
- [ ] Recettes hors périmètre (≥3 inputs, fluides, machine non 3×3, débit > 1 belt) ⇒
      **avertissement** clair, pas de plantage.
- [ ] Génération d'un plan ~50 machines en < 1 s.

## 11. Stratégie de test

- **Boucle fermée en éditeur** : `/editor`, poser des `infinity-chest`/`infinity-loader` ou des
  sources infinies alimentant les lanes de base en haut du bus ; observer la sortie en bas.
- **Cas de référence versionnés** : circuits verts (2 recettes), science rouge (3-4 recettes) —
  tests de non-régression manuels documentés.
- **Vérité terrain directions** (§8) : mini-blueprint manuel belt+inséreur+underground → dump.

## 12. Hors scope M3a → M3b

Machines non-3×3, recettes ≥3 inputs / multi-produits, fluides & tuyaux, multi-belt, beacons,
électricité, minimisation des croisements de lanes, compaction du layout, priorités de splitters.
