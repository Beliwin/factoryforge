# 02 — API Blueprint (Factorio 2.0)

Référence : [BlueprintEntity](https://lua-api.factorio.com/latest/concepts/BlueprintEntity.html),
[LuaItemStack](https://lua-api.factorio.com/latest/classes/LuaItemStack.html).

## 1. Format d'une entité de blueprint

`set_blueprint_entities(array[BlueprintEntity])`. Champs utilisés :

```lua
{
  entity_number = n,                 -- uint, identifiant unique dans le BP (1-based)
  name = "assembling-machine-2",     -- prototype
  position = { x = 0.5, y = 0.5 },   -- CENTRE de l'entité (voir §2)
  direction = defines.direction.east,-- optionnel (défaut nord)
  quality = "normal",                -- optionnel
  recipe = "electronic-circuit",     -- assembleurs
  recipe_quality = "normal",         -- optionnel
  items = { ... },                   -- modules, voir §3
}
```

## 2. Positions & géométrie

- `position` est le **centre** de l'entité.
- Une entité de dimensions `(w, h)` **impaires** (3×3) a son centre sur `.5`
  (ex. centre `{x=1.5, y=1.5}` pour occuper les tuiles 0..2).
- Dimensions **paires** → centre sur entier. Calcul générique :
  `center = top_left + (w/2, h/2)`.
- On travaille dans un repère « tuiles » ; `emit` convertit en centres.
- `direction` : `defines.direction.north/east/south/west` (+ diagonales en 2.0, non utilisées).
  Un inserter « pointe » par défaut vers la tuile devant lui ; sa `direction` définit le
  sens **pickup → drop** (à valider empiriquement en M2/M3, source d'erreurs classique).

## 3. Modules — `items` (BlueprintInsertPlan)

En 2.0, les modules ne sont plus une simple map `{name=count}`. `items` est un
tableau de **BlueprintInsertPlan** :

```lua
items = {
  {
    id = { name = "productivity-module", quality = "normal" },
    items = {
      in_inventory = {
        { inventory = defines.inventory.assembling_machine_modules, stack = 0, count = 2 },
        -- 'stack' = index de slot (0-based) ; répartir 1 module par slot si besoin
      },
    },
  },
}
```

> ⚠️ **À confirmer en M2** : indexation exacte des slots (`stack`), la valeur de
> `defines.inventory.*` selon le type de machine, et si `count` par slot ou 1/slot.
> On validera en posant une machine modulée à la main, en la prenant dans un blueprint,
> puis en lisant `get_blueprint_entities()`.

## 4. Créer et remettre le blueprint au joueur

Deux voies :

**A. Blueprint dans la main du joueur (recommandé pour l'UX)**
```lua
local stack = player.cursor_stack
stack.set_stack{ name = "blueprint" }
stack.set_blueprint_entities(entities)
stack.blueprint_snap_to_grid = { x = grid_w, y = grid_h }  -- optionnel
stack.label = plan.meta.name
```

**B. Export string** (pour tests/CI hors-jeu)
```lua
local str = stack.export_stack()   -- string "0eNq..." partageable
```

## 5. Vérité terrain (méthode de test)

Pour lever tout doute sur un format (modules, direction, snap) :
1. Poser l'entité à la main en jeu avec les réglages voulus.
2. La capturer dans un blueprint.
3. `game.player.cursor_stack.get_blueprint_entities()` → inspecter la table exacte.
4. Reproduire ce format dans `emit`.

C'est la source de vérité qui prime sur cette spec en cas de conflit.

## 6. Critères d'acceptation (transverses)

- [ ] `emit(placement)` renvoie un tableau valide accepté par `set_blueprint_entities`
      sans erreur.
- [ ] Le blueprint obtenu, posé en jeu, contient exactement les machines attendues,
      aux bonnes positions, sans chevauchement de collision.
- [ ] Recette + modules + quality corrects sur chaque machine (vérif visuelle + tooltip).
- [ ] `export_stack()` produit une string réimportable qui redonne le même blueprint.
