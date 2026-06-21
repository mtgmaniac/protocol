# Cursor handoff — read this first (one-shot, Jun 2026)

**Purpose:** Resume work without re-explaining context. Delete or archive after the next session picks up.

---

## Repos

| Repo | Path | Remote | Role |
|------|------|--------|------|
| **protocol (Godot)** | `C:\Users\Kev\Documents\protocol` | [github.com/mtgmaniac/protocol](https://github.com/mtgmaniac/protocol) | **Primary game** — combat authority in `scripts/battle/combat_manager.gd` |
| **overload-protocol (Angular)** | `C:\Users\Kev\overload-protocol` | legacy / mobile UI experiments | Not on Godot `main`; parallel codebase |

---

## Git snapshot (verified Jun 21 2026)

### Godot `protocol`

- **`main` = `origin/main` = `a21eaf4`** — pushed to GitHub ✓  
  Latest: *feat: item roster refactor — squad-wide consumables, gear renames, balance sims*
- Includes **`9b9c1db`** — sliding reward rarity ladder (`GameState.gd`: `DRAFT_RARITY_BY_ROUND`, round 5 relic-only)
- **Active branch:** `feat/ui-redesign` @ `2fa7aaf` (Direction-05 UI — protocol bar, field, status badges) — **not on main**
- **Dirty (uncommitted):** `scripts/battle/battle_scene.gd`, untracked `scenes/shared/UnitCard.tscn`
- **`fix/cleanup`** @ same as `main` (`a21eaf4`) — backend branch merged into main for last push

### Angular `overload-protocol`

- **`feat/mobile-ui`** @ `f7c398c` — **2 commits ahead of `origin/feat/mobile-ui`**, not pushed when handoff written:
  1. Sliding rarity ladder (`constants.ts`, `item.service.ts`, `combat.service.ts`, `docs/reward-draft-rarity.md`)
  2. `.claude/launch.json` npm start entry
- **`main`** @ `8c52f70` — does **not** include reward ladder

---

## Reward draft methodology (implemented both codebases)

Doc: `overload-protocol/docs/reward-draft-rarity.md` (Angular); logic on Godot `GameState.gd`.

| Round | Common | Uncommon | Rare | Legendary |
|------:|-------:|---------:|-----:|----------:|
| 1 | 85% | 10% | 4% | 1% |
| 2 | 70% | 20% | 8% | 2% |
| 3 | 55% | 28% | 14% | 3% |
| 4 | 40% | 35% | 20% | 5% |
| **5** | — | — | — | **Relic only** (2 choices, no items) |
| 6–10 | ramps to 10/35/35/20% | | | |
| **After final win** | No draft (run ends) | | | |

Rules: relics never before round 5; three independent rarity rolls per supply cache slot; gear merges into uncommon/rare pools when slots open.

---

## Balance sim (Tier 1–2 done, not fully on main audit path)

- **Gear:** `scripts/sim/gear-sim.lib.ts` + hooks in `battle-progress-sim.lib.ts` (`squadGearId`)
- **Consumables:** `scripts/sim/consumable-sim.lib.ts` — 1× per battle, heuristic use (`trackConsumableId`)
- **Audit CLI:** `npx tsx scripts/debug/balance_sim_item_audit.ts 3000`
- **Omitted in sim:** cloak evasion, healShieldBonus, cloak/reroll consumables, relics, full Protocol economy
- **Task 5 (facility balance):** still in progress — tune via `balance_sim_facility.ts`; target full-clear band TBD

---

## Recent backend/data (on `main`)

- Large **items/gear** pass: squad-wide heals/shields, protocol consumables, `enemyDieFreezeAll`, gear renames, new icons (some still missing — see commit message KNOWN GAP)
- Consumable effects wired: `healAll`, `shieldAll`, `gainProtocol`, `enemyDieFreezeAll`, `battleStartCloakRoll`
- **`npm run validate-data`** after any `data/raw/` edit

---

## Open work (pick from `TASK_QUEUE.md`)

**UI (`feat/ui-redesign` or `codex/*`):**
- Task 13 — show `picker_blurb` on UnitSelect
- Task 8/9 — animation + audio tiers
- Task 14 — enemy half-cards
- Incoming target indicators during hero targeting
- Finish Direction-05 UI on current branch; commit `battle_scene.gd` WIP

**Backend (`fix/cleanup` / data):**
- Task 5 facility balance sim loop
- Optional: Tier 3 sim (full run loop with rewards) — discussed, not started

**Do not batch unrelated UI + backend in one commit.**

---

## Commands

```bash
# Godot repo root
npm run validate-data
npx tsx scripts/debug/balance_sim_facility.ts 3000
npx tsx scripts/debug/balance_sim_item_audit.ts 3000

# Angular (separate repo)
npm start   # :4200
```

---

## Rules for assistants

- **Do not commit** unless user asks
- Backend on `fix/cleanup`; UI on `feat/ui-redesign` or `codex/*`
- Godot combat is source of truth; TypeScript sim is tuning lab only
- Read `AGENTS.md`, `TASK_QUEUE.md`, `docs/AI_AGENT_GAME_REFERENCE.md` for detail

---

## Suggested next prompt (new chat)

> Read `docs/CURSOR_HANDOFF.md` and `TASK_QUEUE.md`. Continue [UI on feat/ui-redesign | Task 5 facility sim | …]. Do not commit unless I ask.
