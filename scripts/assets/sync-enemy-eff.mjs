/**
 * Rewrites enemies.data.json enemyAbilities[*][*].eff to match buildEnemyEffectSummary
 * in ability-row.component.ts (canonical stats from JSON; battle scaling still applied at runtime).
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');
const jsonPath = path.join(root, 'src', 'app', 'data', 'json', 'enemies.data.json');

function buildEnemyEffectSummary(ab) {
  const parts = [];
  if ((ab.dmg || 0) > 0) {
    if (ab.dmgP2 != null && ab.dmgP2 > 0 && ab.dmgP2 !== ab.dmg) {
      parts.push(`${ab.dmg} dmg (P2 ${ab.dmgP2})`);
    } else {
      parts.push(`${ab.dmg} dmg`);
    }
  }
  if ((ab.burn || 0) > 0) {
    const t = (ab.burnT || 0) > 1 ? `, ${ab.burnT}t` : '';
    parts.push(`${ab.burn} burn${t}`);
  }
  if ((ab.rfm || 0) > 0) {
    const t = (ab.rfmT || 0) > 1 ? `, ${ab.rfmT}t` : '';
    parts.push(`-${ab.rfm} roll${t}`);
  }
  if (ab.wipeShields) parts.push('wipe shields');
  if ((ab.heal || 0) > 0) parts.push(`${ab.heal} heal`);
  if ((ab.shield || 0) > 0) {
    parts.push(`${ab.shield} shield`);
  }
  if ((ab.shieldAlly || 0) > 0) {
    parts.push(`ally ${ab.shieldAlly} shield`);
  }
  if ((ab.rfe || 0) > 0) {
    const t = (ab.rfT || 0) > 1 ? `, ${ab.rfT}t` : '';
    parts.push(`-${ab.rfe} roll${t}`);
  }
  if ((ab.lifestealPct || 0) > 0) parts.push(`lifesteal ${ab.lifestealPct}%`);
  if ((ab.erb || 0) > 0) {
    const t = (ab.erbT || 0) > 1 ? `, ${ab.erbT}t` : '';
    parts.push(`${ab.erbAll ? 'all ' : ''}+${ab.erb} enemy roll${t}`);
  }
  if ((ab.summonChance ?? 0) > 0) parts.push(`summon ~${ab.summonChance}% nat20`);
  if ((ab.freezeAllEnemyDice ?? 0) > 0) parts.push(`freeze all (${ab.freezeAllEnemyDice} reveal skip${ab.freezeAllEnemyDice > 1 ? 's' : ''})`);
  else if ((ab.freezeEnemyDice ?? 0) > 0) parts.push(`freeze (${ab.freezeEnemyDice} reveal skip${ab.freezeEnemyDice > 1 ? 's' : ''})`);
  if ((ab.counterspellPct ?? 0) > 0) {
    const p = Math.max(0, Math.min(100, ab.counterspellPct));
    parts.push(`counter C ${p}%`);
  }
  if ((ab.grantRampage || 0) > 0) parts.push(`rampage +${ab.grantRampage}`);
  if ((ab.grantRampageAll || 0) > 0) parts.push(`rampage all +${ab.grantRampageAll}`);
  return parts.length ? parts.join(', ') : '—';
}

const raw = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
let n = 0;
for (const suite of Object.values(raw.enemyAbilities || {})) {
  for (const ab of Object.values(suite)) {
    const next = buildEnemyEffectSummary(ab);
    if (ab.eff !== next) {
      ab.eff = next;
      n++;
    }
  }
}
fs.writeFileSync(jsonPath, JSON.stringify(raw, null, 2) + '\n', 'utf8');
console.log('Updated eff on', n, 'enemy abilities');
