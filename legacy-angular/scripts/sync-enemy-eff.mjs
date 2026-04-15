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
  if ((ab.dot || 0) > 0) {
    const t = (ab.dT || 0) > 1 ? `, ${ab.dT}t` : '';
    parts.push(`${ab.dot} DoT${t}`);
  }
  if ((ab.rfm || 0) > 0) {
    const t = (ab.rfmT || 0) > 1 ? `, ${ab.rfmT}t` : '';
    parts.push(`-${ab.rfm} roll${t}`);
  }
  if (ab.wipeShields) parts.push('wipe shields');
  if ((ab.heal || 0) > 0) parts.push(`${ab.heal} heal`);
  if ((ab.shield || 0) > 0) {
    const t = (ab.shT || 0) > 1 ? `, ${ab.shT}t` : '';
    parts.push(`${ab.shield} shield${t}`);
  }
  if ((ab.shieldAlly || 0) > 0) {
    const t = (ab.shT || 0) > 1 ? `, ${ab.shT}t` : '';
    parts.push(`ally ${ab.shieldAlly} shield${t}`);
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
  if ((ab.counterspellPct ?? 0) > 0) {
    const p = Math.max(0, Math.min(100, ab.counterspellPct));
    parts.push(`counter C ${p}%`);
  }
  if ((ab.grantRampage || 0) > 0) parts.push(`rampage +${ab.grantRampage}`);
  if ((ab.grantRampageAll || 0) > 0) parts.push(`rampage all +${ab.grantRampageAll}`);
  if ((ab.cowerT || 0) > 0) {
    parts.push(ab.cowerAll ? `cower all ${ab.cowerT}r` : `cower ${ab.cowerT}r`);
  }
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
