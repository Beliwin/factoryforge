# FactoryForge

Mod **Factorio 2.1** compagnon de [Factory Planner](https://mods.factorio.com/mod/factoryplanner)
qui génère un **blueprint posable** à partir du plan de production résolu de FP.

Développement **spec-driven** — voir [`specs/`](specs/README.md).

## Structure

| Dossier | Contenu |
|---|---|
| [`specs/`](specs/README.md) | Specs & design (source de vérité du projet) |
| [`factoryforge/`](factoryforge/) | Le mod Factorio (mod compagnon) |
| `vendor/` | Clone de FP (référence) — *non versionné* |

## État

- ✅ M0 scaffold · M1 modèle de données · **M2 blueprint grille (validé en jeu)**
- ⏭️ M3 : layout main-bus (belts + inserters)

Détails et roadmap : [`specs/README.md`](specs/README.md).

## Architecture (résumé)

Mod compagnon (pas de fork). Lit FP via l'interface remote
`remote.call("fp-interface", "export_current_factory", player.index)`, puis pipeline
`extract → layout → emit → blueprint`, découplé par une IR interne (`ProductionPlan`).

Déclenchement en jeu : bouton dans la barre de raccourcis, hotkey **Ctrl+Shift+G**, ou
commande `/ff-generate`.

> ⚠️ Nécessite un correctif FP (bug d'export 2.1.3) — voir `specs/99-open-questions.md`.
