# Specs — Générateur d'usines (fork Factory Planner)

Développement **spec-driven** : on écrit/valide la spec d'un milestone *avant* de coder,
et le code doit satisfaire les **critères d'acceptation** listés. Aucune fonctionnalité
n'est « finie » tant que ses critères ne passent pas en jeu.

## Index

| Fichier | Contenu |
|---|---|
| [00-overview.md](00-overview.md) | Vision, objectifs/non-objectifs, glossaire, contraintes, architecture, roadmap |
| [01-data-model.md](01-data-model.md) | Contrat d'entrée depuis Factory Planner + représentation interne (IR) |
| [02-blueprint-api.md](02-blueprint-api.md) | Format des entités de blueprint 2.0, modules/quality, remise au joueur |
| [03-m2-naive-placement.md](03-m2-naive-placement.md) | M2 — placement en grille brute, sans belts |
| [04-m3-mainbus-layout.md](04-m3-mainbus-layout.md) | M3 — layout main-bus avec convoyeurs et inserters |
| [99-open-questions.md](99-open-questions.md) | Décisions en attente, points à vérifier |

## Process

1. Un milestone = un fichier spec avec des **critères d'acceptation** (cases à cocher).
2. On implémente uniquement le milestone courant.
3. On coche les critères en les vérifiant *en jeu* (voir la stratégie de test dans chaque spec).
4. Toute divergence entre le code réel de FP et la spec `01-data-model` est corrigée
   dans la spec en premier, puis dans le code.

## État

- [x] M0 — Scaffold du mod compagnon (`factoryforge/`, hotkey + bouton + commande)
- [x] M1 — Localiser la donnée résolue dans FP → **fait**, format réel dans `01-data-model`
- [x] M2 — Blueprint « bête » (grille, sans belts) → **validé en jeu** (circuits verts : 5 machines, 2 blocs, recettes OK, posable). Reste à vérifier : modules (Q4) sur un plan modulé, round-trip `export_stack`.
- [x] **M3a — Layout hybride « chaînes + mini-bus » : VALIDÉ EN JEU** (2026-07-14).
      L'usine circuits verts générée **tourne en boucle fermée** (plaques injectées en haut
      du bus → circuits collectés en bas). Électricité à fournir manuellement.
- [~] M3b — Recettes **3 ingrédients** (belt sud + sortie par inséreurs longs), lanes pitch 3,
      pontage souterrain des routes, ordre de routage descendant → **à tester en jeu**
      (4 ingrédients : hors scope, avertissement)
- [ ] M4 — Raffinements (électricité, multi-belt, fluides, beacons, machines non-3×3)

> ⚠️ Env local : FP tourne en **zip 2.1.3 patché** (2 lignes dans `Object.lua`, cf. `99` bug FP).
> L'original est sauvegardé en `vendor/fp-zip-backup/factoryplanner_2.1.3.ORIGINAL.zip`.
> Une mise à jour de FP écrasera le patch → il faudra le réappliquer (ou vérifier que la release corrige le bug).

## Tester le mod en jeu

Le mod vit dans [`../factoryforge/`](../factoryforge). Pour l'essayer :

1. Copier (ou lier en symlink) le dossier `factoryforge/` dans le répertoire des mods
   Factorio : `%APPDATA%\Factorio\mods\factoryforge`.
2. Activer **Factory Planner** (≥ 2.1.1) + **FactoryForge** dans le jeu.
3. Ouvrir un factory résolu dans FP, puis **Ctrl+Shift+G** (ou `/ff-generate`).
4. Un blueprint atterrit dans la main → le poser sur une surface vide.

Voir les critères d'acceptation M2 dans [03-m2-naive-placement.md](03-m2-naive-placement.md).
