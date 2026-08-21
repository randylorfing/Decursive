# Zhaohu's Decursive Dispel Database

Each WoW expansion has its own Lua module under `Database/Dispels/`.

The database is intentionally curated rather than generated from every spell in the client. Entries are added when a mechanic is verified as a player-facing dispellable debuff (or a separately-tagged enemy purge target). This avoids registering irrelevant spells and keeps `C_UnitAuras.AddAuraSound()` focused on actionable mechanics.

Entry fields:
- `id`: Blizzard spell ID
- `name`: human-readable spell name
- `cureType`: `MAGIC`, `POISON`, `DISEASE`, `CURSE`, `BLEED`, or `ENEMYMAGIC`
- `target`: `friendly` for player/group debuffs, `enemy` for purgeable enemy buffs
- `content`: dungeon/raid/world source
- `alert`: whether this entry is eligible for the friendly afflicted sound registry
- `source`: optional verification source

Only `target="friendly"` and `alert=true` entries that the current class/spec can cure are sent to `C_UnitAuras.AddAuraSound()`.

## Coverage

- Midnight: active/current-content database
- Dragonflight, Legion, Battle for Azeroth: verified seed coverage
- Classic, The Burning Crusade, Wrath, Cataclysm, Mists, Warlords, Shadowlands, The War Within: expansion modules active and ready for continued harvesting

Use `/zddb` or the **Dispel Database** page in the v11 UI to see live counts by expansion. Use `/zdsound` to see the subset registered for the current class/spec.
