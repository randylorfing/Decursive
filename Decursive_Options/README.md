# Packaging: Zhaohu's Decursive + Decursive_Options

Install **both** folders into `World of Warcraft\_retail_\Interface\AddOns\`:

```
Interface\AddOns\Decursive\            # combat core, AceDB (DecursiveDB)
Interface\AddOns\Decursive_Options\     # LoadOnDemand settings UI
```

## Rules

- Folder name for the main addon must remain `Decursive` (SavedVariables path).
- `Decursive_Options` has **no** SavedVariables; it reads `DecursiveDB` via the parent.
- `## RequiredDeps: Decursive` + the `Decursive_` name prefix nests Options under Decursive in the AddOns list.
- If Options is missing or disabled, `/dcr` prints a clear error instead of silently failing.

## Development layout

```
Decursive-Cursor\
  Decursive\              # this repo / main addon
  Decursive_Options\      # sibling companion (same parent folder)
```

Copy or junction both into `_retail_\Interface\AddOns` for in-game testing.
