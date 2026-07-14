# 04 — M3 : Layout main-bus (belts + inserters)

**But** : produire une usine qui **tourne réellement** — les ingrédients circulent sur un
bus, les blocs tapent dessus, les produits repartent. Pattern « main bus » classique,
généré par heuristiques. Pas d'optimalité, mais fonctionnel et lisible.

## Concept

```
   BUS (lanes verticales de convoyeurs, un item par lane)
   │ iron │ copper │ gears │ circuits │ ...
   ▼      ▼        ▲        ▲
 ┌──────────────┐        ┌──────────────┐
 │  Bloc A      │        │  Bloc B      │   ← blocs à droite du bus
 │  (machines)  │        │  (machines)  │
 └──────────────┘        └──────────────┘
```

- Le **bus** = ensemble de lanes verticales, une par item traversant ≥ 1 frontière de bloc
  (cf. `01-data-model.md` §3). Ordre déterministe (tri stable).
- Chaque **bloc** est posé à droite du bus. Ses **entrées** sont tirées des lanes concernées
  (via splitters/undergrounds), ses **sorties** réinjectées dans les lanes correspondantes.
- Un bloc = rangée(s) de machines avec, entre deux rangées, une allée pour belts + inserters.

## Géométrie d'un bloc (v1)

- Machines disposées en **une ou plusieurs rangées horizontales**.
- Par rangée : une belt d'**entrée** (côté haut) et une belt de **sortie** (côté bas),
  reliées aux machines par **inserters** (1 par machine par item).
- Rangées empilées verticalement, hauteur = `tile_h + 2` (machine + 2 belts) par rangée.
- Nombre de rangées : `ceil(count / machines_par_rangée)`, où `machines_par_rangée`
  est borné pour garder des blocs pas trop larges (config, défaut ~ largeur bus-friendly).

## Routage bus ↔ bloc

- **Prise (input)** : sur la lane de l'item, un **splitter** dérive une partie vers une
  belt horizontale qui entre dans le bloc ; segments longs franchis en **underground**
  (respecter `meta.underground_max`).
- **Rejet (output)** : belt de sortie du bloc → underground/splitter → réinjection sur la
  lane de l'item produit.
- Croisements bus/belts d'accès : gérés par **undergrounds** (le bus passe dessous ou dessus).

## Débits & multi-belt

- **v1 (M3)** : suppose que chaque item tient sur **1 belt** (débit ≤ capacité belt choisie).
  Si dépassement → **avertir** (log/tooltip) et poser quand même 1 lane (à corriger en M4).
- **M4** : multi-lane par item, balancing, choix belt selon débit.

## Électricité

- **v1 (M3)** : ne pose pas l'électricité (le joueur ajoute poteaux/nucléaire).
  *Ou* option simple : semer des **poteaux moyens** en grille couvrante. → décision `99`.
- **M4** : placement propre des poteaux selon aire d'alimentation.

## Critères d'acceptation

- [ ] Sur un factory jouet à ≥ 2 recettes chaînées (ex. câbles → circuits verts) :
      le blueprint posé sur une source d'ingrédients de base **produit l'output final**
      sans blocage après stabilisation.
- [ ] Chaque machine reçoit ses ingrédients (aucune machine « no ingredients »).
- [ ] Les intermédiaires produits par un bloc atteignent le(s) bloc(s) consommateur(s) via le bus.
- [ ] Aucun chevauchement de collision ; blueprint posable d'un bloc.
- [ ] Ordre des lanes du bus déterministe (2 générations du même plan = même blueprint).
- [ ] Item dépassant 1 belt → avertissement émis (pas de silence).
- [ ] Génération d'un factory ~50 machines en < 1 s.

## Stratégie de test

- **En jeu, boucle fermée** : map créative / editor, poser une source infinie des
  ingrédients de base sur les lanes d'entrée du bus, laisser tourner, vérifier la sortie.
- **Cas de référence** : 2-3 plans jouets versionnés (circuits verts, science rouge)
  servant de tests de non-régression manuels documentés.

## Hors scope M3 (→ M4)

Multi-belt, fluides/tuyaux, beacons, électricité propre, undergrounds optimisés,
compaction du layout.
