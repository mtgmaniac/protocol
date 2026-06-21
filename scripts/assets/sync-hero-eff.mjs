/**
 * Rewrites heroes.data.json abilities[].eff to match buildHeroEffectSummary (ability-row).
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const jsonPath = path.join(__dirname, '..', 'src', 'app', 'data', 'json', 'heroes.data.json');

function buildHeroEffectSummary(a) {
  const parts = [];
  const dLo = a.dMin || 0;
  const dHi = a.dMax || 0;
  const hasSpread = dLo > 0 && dHi > 0 && dLo !== dHi;
  const combatDmg = (a.dmg || 0) > 0 ? a.dmg : 0;
  const flatBracket = dLo > 0 && dHi > 0 && dLo === dHi ? dLo : 0;

  if (combatDmg > 0) {
    let s = `${combatDmg} dmg`;
    if (a.blastAll || a.multiHit) s += ' (all enemies)';
    if (a.ignSh) s += ', pierce';
    parts.push(s);
  } else if (hasSpread) {
    let s = `${dLo}-${dHi} dmg`;
    if (a.blastAll || a.multiHit) s += ' (all enemies)';
    if (a.ignSh) s += ', pierce';
    parts.push(s);
  } else if (flatBracket > 0) {
    let s = `${flatBracket} dmg`;
    if (a.blastAll || a.multiHit) s += ' (all enemies)';
    if (a.ignSh) s += ', pierce';
    parts.push(s);
  }
  if (a.splitDmg && (combatDmg > 0 || hasSpread || flatBracket > 0)) parts.push('split');

  if ((a.heal || 0) > 0) {
    if (a.healAll) parts.push(`all ${a.heal} heal`);
    else if (a.healLowest) parts.push(`lowest ${a.heal} heal`);
    else if (a.healTgt) parts.push(`${a.heal} heal (ally)`);
    else if (combatDmg > 0 || hasSpread || flatBracket > 0) parts.push(`heal self ${a.heal}`);
    else parts.push(`${a.heal} heal`);
  }

  if ((a.shield || 0) > 0) {
    const t = (a.shT || 0) > 1 ? `, ${a.shT}t` : '';
    if (a.shieldAll) parts.push(`all ${a.shield} shield${t}`);
    else if (a.shTgt) parts.push(`ally ${a.shield} shield${t}`);
    else parts.push(`self ${a.shield} shield${t}`);
  }

  if ((a.dot || 0) > 0) {
    const t = (a.dT || 0) > 1 ? `, ${a.dT}t` : '';
    parts.push(`${a.dot} DoT${t}`);
  }

  if ((a.rfe || 0) > 0) {
    const t = (a.rfT || 0) > 1 ? `, ${a.rfT}t` : '';
    if (a.rfeAll) parts.push(`all -${a.rfe} roll${t}`);
    else parts.push(`-${a.rfe} roll${t}`);
  }

  if ((a.rfm || 0) > 0) {
    const t = (a.rfmT || 0) > 1 ? `, ${a.rfmT}t` : '';
    if (a.rfmTgt) parts.push(`+${a.rfm} roll ally${t}`);
    else if (a.shTgt && (a.shield || 0) > 0) parts.push(`+${a.rfm} roll any ally${t}`);
    else parts.push(`+${a.rfm} squad roll${t}`);
  }

  if (a.revive) parts.push('revive 50%');
  if (a.cloak) parts.push('Cloak');
  if (a.taunt) parts.push('taunt (enemies target you)');

  return parts.length ? parts.join(', ') : '—';
}

function walk(abilities, counts) {
  if (!abilities) return;
  for (const a of abilities) {
    const next = buildHeroEffectSummary(a);
    if (a.eff !== next) {
      a.eff = next;
      counts.n++;
    }
  }
}

const raw = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
const counts = { n: 0 };
for (const h of raw.heroes || []) {
  walk(h.abilities, counts);
  for (const ev of h.evolutions || []) walk(ev.abilities, counts);
}
fs.writeFileSync(jsonPath, JSON.stringify(raw, null, 2) + '\n', 'utf8');
console.log('Updated eff on', counts.n, 'hero abilities');
