# 00 — Vue d'ensemble

## Contexte & vision

Un mod Factorio **2.0 / Space Age** qui, à partir d'un plan de production déjà calculé
dans **Factory Planner** (ratios, machines, modules), **génère automatiquement un blueprint
posable** implémentant ce plan.

Factory Planner résout déjà le « combien » (nb de machines, débits). Ce projet ajoute le
« comment le poser » : géométrie des machines, bus d'ingrédients, convoyeurs, inserters.

Nom de travail provisoire : **FactoryForge** (à confirmer, cf. `99-open-questions.md`).

## Objectifs (in scope)

- Déclencher la génération sur le factory **résolu** courant de Factory Planner (raccourci /
  bouton — emplacement UI cf. Q7).
- Produire une entité `blueprint` remise au joueur (main ou inventaire), exportable en string.
- Layout **main-bus** lisible et fonctionnel (pas optimal, mais qui tourne réellement).
- Régler sur chaque machine : **recette**, **modules**, **quality** (si présents dans le plan).
- Router les E/S via inserters + convoyeurs jusqu'au bus.

## Non-objectifs (out of scope, au moins au début)

- **Optimalité spatiale** (problème de recherche ouvert) — on vise « correct et lisible ».
- Routage de fluides / tuyauterie complexe (v1 : items solides ; fluides = itération ultérieure).
- Trains, robots logistiques, circuits.
- Multi-surface, gestion du terrain/obstacles existants.
- Rétro-compat Factorio 1.1.

## Personas

- **Moi (mono-utilisateur)** : joueur/dev, connaît Factorio, veut gagner le temps de layout
  manuel pour des sous-usines de taille petite à moyenne.

## Contraintes

- **Plateforme** : Factorio 2.0.x + Space Age, API Lua runtime (control stage).
- **Base** : **mod compagnon** (révisé en M1). FP expose
  `remote.call("fp-interface", "export_current_factory", player.index)` (≥ 2.1.1) avec les
  résultats du solveur → pas besoin de forker. Dépendance optionnelle `? factoryplanner >= 2.1.1`.
  (FP est MIT si un fork s'avérait nécessaire plus tard.)
- **Langage** : Lua (API Factorio). Pas de dépendances externes.
- **Perf** : la génération d'un factory moyen (< ~200 machines) doit être quasi instantanée
  (< 1 s), sans figer le jeu de façon perceptible.

## Architecture (haut niveau)

```
Factory Planner (non modifié)
│  remote "fp-interface" : export_current_factory(player.index) ──► PackedFactory (résolu)
▼
Mod compagnon (ce projet)
     ├── extract.lua   : PackedFactory ──► IR (ProductionPlan)     [M1 ✓ / M2]
     ├── layout.lua    : IR ──► placement (positions, directions)  [M2 grille, M3 bus]
     ├── routing.lua   : bus + belts + inserters                   [M3]
     ├── emit.lua      : placement ──► array[BlueprintEntity]       [M2]
     └── control/gui   : déclencheur + remise du blueprint au joueur [M2]
```

Flux : **déclencheur** → `remote.call(export_current_factory)` → `extract` → `layout` →
`routing` → `emit` → `set_blueprint_entities` → blueprint dans la main du joueur.

Découplage clé : `layout`/`routing` ne connaissent que l'**IR** (`01-data-model.md`),
jamais les structures internes de FP. Seul `extract.lua` dépend de FP.

## Roadmap / milestones

| M | Titre | But | Livrable testable |
|---|---|---|---|
| M0 | Scaffold compagnon | `info.json` + `control.lua`, mod chargé à côté de FP | Mod visible, aucune erreur |
| M1 | Data probe ✓ | Comprendre le format résolu de FP | **Fait** : format documenté (`01-data-model.md`) |
| M2 | Blueprint bête | Chaîne complète, machines en grille, **sans** belts | Blueprint exportable, machines réglées |
| M3 | Main-bus | Bus + convoyeurs + inserters, usine qui **tourne** | Usine posée produit l'output attendu |
| M4 | Raffinements | Élec, multi-belt, beacons, undergrounds | Cas > 1 belt/s gérés |

Détail des critères d'acceptation : specs M2 (`03-`) et M3 (`04-`).
