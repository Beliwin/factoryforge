# 99 — Questions ouvertes & décisions

Décisions à trancher au fil de l'eau. Une fois tranchée, une entrée est déplacée en
« Décidé » avec la date.

## En attente

| # | Question | Impact | Statut |
|---|---|---|---|
| Q1 | Nom définitif du mod (travail : *FactoryForge*) | Cosmétique / publication | Ouvert |
| Q4 | Format exact `items` modules 2.0 (slots, `defines.inventory.*`) | Bloque `02`/`emit` | À lever par vérité terrain en M2 |
| Q10 | Faut-il ignorer les lignes `active == false` ? | `extract` | À confirmer en jeu (M2) |
| Q11 | Inclure les `byproducts` comme sorties à router, ou les ignorer ? | `routing` | Ouvert (défaut : ignorer v1) |
| Q5 | Choix du belt/inserter : config fixe vs déduit du débit | Layout, multi-belt | Défaut config en M3, auto en M4 |
| Q6 | Électricité en M3 : rien vs poteaux en grille | UX de l'usine posée | Ouvert (défaut : rien) |
| Q7 | Comment le bouton s'insère dans l'UI de FP (emplacement) | UX | À voir en lisant l'UI FP (M2) |
| Q8 | Gestion des fluides (raffinage, chimie) | Élargit fortement le scope | Reporté (post-M4) |
| Q9 | Orientation du bus (vertical/horizontal) et sens blocs | Layout | Défaut : bus vertical, blocs à droite (04) |

## Décidé

| Date | Décision |
|---|---|
| 2026-07-14 | Cible **Factorio 2.0 / Space Age** uniquement (pas de 1.1). |
| 2026-07-14 | Base = fork de **Factory Planner** (licence MIT). |
| 2026-07-14 | Dev **spec-driven** ; roadmap M0→M4 (cf. `00-overview.md`). |
| 2026-07-14 | v1 = items solides only ; fluides reportés (Q8). |
| 2026-07-14 | Layout v1 = **main-bus**, pas d'optimalité spatiale. |
| 2026-07-14 | **Q2 → mod compagnon** (pas de fork dur). FP expose `remote.call("fp-interface", "export_current_factory", idx)` depuis 2.1.1, avec résultats solveur. Dépendance optionnelle `? factoryplanner >= 2.1.1`. |
| 2026-07-14 | **Q3 → résolu en M1.** Format d'entrée réel documenté dans `01-data-model.md` (méthodes `:pack`). |
| 2026-07-14 | **Q9 → layout hybride « chaînes + mini-bus »** (décidé après essai du bus complet sur un plan réel : trop de lanes). Direct-feed pour les items mono-consommateur, bus réservé aux base/partagés/finaux. Spec 04 réécrite. |
| 2026-07-14 | **Directions 2.0 (vérité terrain)** : 16 directions (est=4) ; inserter `direction` = côté de **prise** ; underground `type` in/out. Documenté en 04 §8. |
| 2026-07-14 | Item `amount` = **items/seconde** ; `machine.amount` = count fractionnaire → `ceil`. Items sans quality (→ `normal` sur le bus). |
| 2026-07-14 | **BUG FP 2.1.3** : `backend/data/Object.lua` `methods:_pack()` ne prend/propage pas `full` → `object:pack()` au lieu de `object:pack(full)`. Conséquence : counts machines et items *par ligne* absents de l'export (seul le niveau floor a ses items). Corrigé dans FP master. À retester à la prochaine release FP. |
| 2026-07-14 | **Contournement retenu** : FP master installé en mod **décompressé** via jonction `mods/factoryplanner` → `vendor/FactoryPlanner/modfiles` ; le zip 2.1.3 déplacé en `vendor/fp-zip-backup/`. Locale master partielle (cosmétique). À défaire quand la release FP corrigée sort. |
