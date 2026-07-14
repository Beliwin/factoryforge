# 01 — Modèle de données

> ✅ **Validé en M1** (lecture du code FP 2.1.3). Le format d'entrée ci-dessous est le
> format **réel** renvoyé par l'interface remote de FP, pas une hypothèse.
> Source : `vendor/FactoryPlanner/modfiles/backend/data/*.lua` (méthodes `:pack(full)`)
> et `backend/handlers/interface.lua`.

## 0. Accès aux données (résultat clé de M1)

FP expose une **interface remote publique**, donc **pas besoin de forker** — un mod
compagnon suffit (cf. décision Q2 dans `99`) :

```lua
-- Disponible depuis FP 2.1.1. Renvoie le factory courant du joueur, résolu.
local packed = remote.call("fp-interface", "export_current_factory", player.index)
-- packed == nil  si joueur inconnu / non initialisé / aucun factory
```

Le `true` interne (`current_factory:pack(true)`) => **inclut les résultats du solveur**
(counts machines, products/ingredients/byproducts par ligne). C'est exactement notre besoin.

Notre mod doit déclarer une dépendance optionnelle `? factoryplanner >= 2.1.1` et
vérifier `remote.interfaces["fp-interface"]` avant d'appeler.

## 1. Format réel `PackedFactory` (entrée brute)

Arbre imbriqué. `?` = présent seulement si `full=true` (c'est notre cas).

```
PackedFactory = {
  class = "Factory",
  name  = string,                       -- nom du factory (→ meta.name / label BP)
  matrix_solver_active = boolean,
  matrix_free_items = ...?,             -- (matrix solver, ignorable v1)
  productivity_boni = table,
  products = [PackedProduct],           -- outputs demandés au niveau factory
  top_floor = PackedFloor,              -- ← racine de l'arbre de lignes
}

PackedFloor = {
  class = "Floor",
  level = integer,                      -- 1 = top
  lines = [ PackedLine | PackedFloor ], -- ⚠️ une "ligne" PEUT être un sous-floor imbriqué
  products?    = [PackedItem],
  byproducts?  = [PackedItem],
  ingredients? = [PackedItem],
}

PackedLine = {
  class = "Line",
  recipe = PackedRecipe,
  done = boolean, active = boolean, percentage = number,
  machine = PackedMachine,
  beacon? = PackedBeacon,               -- M4
  comment = string,
  products?    = [PackedItem],
  byproducts?  = [PackedItem],
  ingredients? = [PackedItem],
}

PackedRecipe = {
  class = "Recipe",
  proto = SimplifiedProto,              -- proto.name = nom de la recette
  production_type = string,             -- "produce" | "consume" (recyclage etc.)
  priority_product? = SimplifiedProto,
  temperatures = table,
}

PackedMachine = {
  class = "Machine",
  proto = SimplifiedProto,              -- proto.name = ex. "assembling-machine-2", "foundry"
  quality_proto = SimplifiedProto,      -- quality_proto.name = ex. "normal", "rare"
  limit = number?, force_limit = boolean,
  fuel? = PackedFuel,                   -- machines à combustible (M4 : inséreur charbon)
  module_set = PackedModuleSet,
  amount = number,                      -- ⚠️ nb de machines FRACTIONNAIRE (résultat solveur)
}

PackedModuleSet = { class = "ModuleSet", modules = [PackedModule] }
PackedModule = {
  class = "Module",
  proto = SimplifiedProto,              -- proto.name = ex. "productivity-module"
  quality_proto = SimplifiedProto,
  amount = integer,                     -- nb de ce module DANS la machine
}

PackedItem = {                          -- products / ingredients / byproducts
  proto = SimplifiedProto,              -- proto.name = item ; proto.category = "item" | "fluid"
  amount = number,                      -- ⚠️ items par SECONDE (confirmé, voir §3)
}

SimplifiedProto = { name = string, category = any, data_type = string, simplified = true }
```

## 2. Extraction : PackedFactory → IR (`extract.lua`)

L'IR cible (`ProductionPlan`) reste celui décrit en §4 ci-dessous. Algo :

1. `meta.name = packed.name`.
2. **Aplatir l'arbre** : parcourir `packed.top_floor.lines` récursivement ; une entrée
   `class == "Floor"` → recurse dans ses `.lines` ; une entrée `class == "Line"` → un **bloc**.
   (Les sous-floors sont purement organisationnels ; on ne garde que les lignes-feuilles.)
3. Par ligne, ignorer si `active == false` (ligne désactivée par l'utilisateur) — à confirmer
   en jeu ; sinon la garder.
4. Mapper chaque `PackedLine` → bloc IR :
   - `recipe = line.recipe.proto.name`, `recipe_quality = "normal"` (les recettes ne
     portent pas de quality dans ce format).
   - `machine.name = line.machine.proto.name`,
     `machine.quality = line.machine.quality_proto.name`,
     `machine.tile_w/h` = lues de `prototypes.entity[name].tile_width/height`
     (dispo côté control d'un mod ; **ne pas hardcoder**).
   - `count = ceil(line.machine.amount)` (cf. §3 arrondi), `count_exact = line.machine.amount`.
   - `modules` = `line.machine.module_set.modules` → `{name=proto.name,
     quality=quality_proto.name, count=amount}`.
   - `inputs`  = `line.ingredients` filtrés `proto.category == "item"` →
     `{item=proto.name, quality="normal", rate=amount}`.
   - `outputs` = `line.products` (idem filtrage item).
   - **fluides** (`proto.category == "fluid"`) : mis de côté en v1 (cf. Q8), mais **comptés**
     dans un champ debug pour avertir l'utilisateur qu'ils ne sont pas routés.

## 3. Sémantique confirmée (M1)

- `machine.amount` = **nombre de machines fractionnaire** (résultat du solveur, ex. 5.7).
  → IR `count = ceil(amount)` (on préfère sur-produire). `count_exact` conserve la valeur brute.
- `PackedItem.amount` = **items par seconde**. Preuve : `util/cursor.lua:153`
  `count = ceil(amount * timescale)` avec `timescale ∈ {1, 60}` → l'amount stocké est per-second.
  → IR `rate` = `amount` directement (items/s), parfait pour dimensionner les belts (M4).
- **Quality** : machines et modules portent `quality_proto.name`. Les **items n'ont pas de
  quality** dans ce format → sur le bus on suppose `"normal"` (limite acceptée v1).

## 4. Représentation interne (IR) — inchangée

```lua
ProductionPlan = {
  meta = { name, belt, inserter, underground_max },   -- belt/inserter/underground = config
  blocks = {
    { id, recipe, recipe_quality,
      machine = { name, quality, tile_w, tile_h },
      count, count_exact,
      modules = { {name, quality, count}, ... },       -- count = par machine
      inputs  = { {item, quality, rate}, ... },         -- rate = items/s, total bloc
      outputs = { {item, quality, rate}, ... },
    }, ...
  },
}
```

L'IR est **indépendant de FP** : `layout`/`routing`/`emit` ne voient que ça. Seul
`extract.lua` connaît le format §1. IR sérialisable JSON (test snapshot).

## 5. Invariants (assertions dans `extract`)

- `count >= 1` pour tout bloc conservé (sinon on saute la ligne).
- `machine.tile_w > 0 and machine.tile_h > 0`.
- `rate >= 0`.
- Tout item en `outputs` d'un bloc et en `inputs` d'un autre = intermédiaire (→ lane de bus, `04`).
- Fluides exclus des inputs/outputs v1 mais signalés.
