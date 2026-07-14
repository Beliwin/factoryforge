# 03 — M2 : Blueprint « bête » (grille, sans belts)

**But** : boucler la chaîne complète UI → extract → layout → emit → blueprint dans la main,
avec un layout minimal. Aucune logique de convoyeur. Valide toute la plomberie technique
(API blueprint, modules, quality, remise au joueur) avant d'attaquer le vrai layout (M3).

## Portée

- IN : machines de chaque bloc, posées en grille, recette + modules + quality réglés.
- OUT : belts, inserters, bus, électricité, fluides.

## Comportement attendu

1. Le joueur ouvre un factory **résolu** dans Factory Planner.
2. Un bouton **« Générer blueprint »** est visible dans l'UI FP (barre du factory).
3. Au clic : `extract` produit le `ProductionPlan` (IR, cf. `01-data-model.md`).
4. `layout` place les machines en **grille par bloc** :
   - Un bloc = un rectangle de `count` machines, disposées en colonnes.
   - Largeur de bloc : `ceil(sqrt(count))` machines ; hauteur : le reste. (Simple, compact.)
   - Espacement inter-machines : **1 tuile** (réservé aux inserters/belts de M3).
   - Espacement inter-blocs : **2 tuiles** de marge.
   - Blocs alignés de gauche à droite, ordre = ordre des `blocks` de l'IR.
5. `emit` convertit en `array[BlueprintEntity]` (positions = centres, cf. `02` §2).
6. Le blueprint est mis dans `player.cursor_stack`, labellisé `plan.meta.name`.

## Géométrie (rappel)

- Dimensions machine lues du prototype (`tile_w`, `tile_h`), **pas** hardcodées.
- Pas de collision : deux entités ne partagent aucune tuile
  (marge ≥ 1 tuile entre machines dans un bloc).

## Critères d'acceptation

- [ ] Le bouton apparaît dans l'UI FP sur un factory résolu, et seulement là.
- [ ] Clic sans factory / factory vide → message d'erreur propre, pas de crash.
- [ ] Après clic, le joueur a un blueprint dans la main (curseur).
- [ ] Le blueprint contient **exactement** `Σ count` machines, du bon prototype.
- [ ] Chaque machine a la **bonne recette**, les **bons modules** (nb + quality), la bonne quality.
- [ ] Posé sur une surface vide : aucune erreur de collision, aucun chevauchement.
- [ ] `export_stack()` → string réimportable identique.
- [ ] Génération d'un factory ~50 machines en < 500 ms.

## Stratégie de test

- **Manuel en jeu** : un factory jouet (ex. circuits verts, 2-3 recettes), cliquer,
  poser, inspecter recettes/modules via tooltips.
- **Snapshot IR** : logger le `ProductionPlan` en JSON (`helpers.table_to_json`) pour
  vérifier `extract` indépendamment du rendu.
- **Round-trip** : `set_blueprint_entities` puis `get_blueprint_entities`, comparer.

## Risques identifiés

- Format `items` (modules) 2.0 mal deviné → cf. `02` §3/§5, valider par vérité terrain.
- Accès à la donnée résolue de FP différent de l'hypothèse `01` → ajuster `extract` + spec.
- Slot d'inventaire modules selon type de machine (`defines.inventory.*`).
