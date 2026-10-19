'use strict';
// =====================================================================
//  Game data: stats, perks, relics, curses, consumables,
//  enemies, bosses, biomes, lanterns
// =====================================================================

const RARITY = [
  { name: 'Common', col: '#c8c0b0', w: 62 },
  { name: 'Rare', col: '#6fa8e8', w: 27 },
  { name: 'Epic', col: '#c57ae0', w: 9 },
  { name: 'Legendary', col: '#f6cf57', w: 2.5 },
];

function baseStats() {
  return {
    maxHp: 60, dmg: 10, dmgMult: 1, fireRate: 3.0, rateMult: 1, shotSpeed: 230, range: 200, shotSize: 3,
    proj: 1, pierce: 0, bounce: 0, homing: 0, crit: 0.05, critMult: 2.0,
    speed: 64.4, speedMult: 1, armor: 0, dodge: 0, dashCharges: 1, dashCd: 1.0, dashDist: 1, iframes: 0.9,
    maxOil: 100, oilDrain: 1, light: 104, lightMult: 1, pickup: 26, coinMult: 1, xpMult: 1, healMult: 1,
    leech: 0, thorns: 0, burn: 0, poison: 0, chill: 0, chain: 0, explode: 0, orbit: 0, flareCost: 40, flareMult: 1,
    fury: 0, comet: 0, split: 0, berserk: 0, secondwind: 0, ashguard: 0, guardian: 0, primal: 0, echo: 0, sun: 0,
    dashfire: 0, critBurn: 0, critHeal: 0, dashReflect: 0, noOilDrain: 0, bellStun: 0, immune: {}, chillAll: 0,
    storm: 0, extraChoice: 0, luck: 0, revive: 0, ashTrail: 0, lowHpDmg: 0, priceMult: 1,
    enemySpeed: 1, dmgTaken: 1, mapReveal: 0, hideMap: 0, goldKeys: 0, burnMult: 1
  };
}

// ---------------------------------------------------------------------
//  Perks (chosen on level-up)
// ---------------------------------------------------------------------
const PERKS = {
  dmg:      { name: 'Live Embers', rar: 0, max: 5, icon: 'i_blade', desc: '+^y18%^w projectile damage.', apply: (s, n) => s.dmgMult += 0.18 * n },
  rate:     { name: 'Nimble Hand', rar: 0, max: 5, icon: 'i_rate', desc: '+^y14%^w fire rate.', apply: (s, n) => s.rateMult += 0.14 * n },
  speed:    { name: 'Soft Step', rar: 0, max: 3, icon: 'i_boot', desc: '+^y10%^w movement speed.', apply: (s, n) => s.speedMult += 0.10 * n },
  hp:       { name: 'Sturdy Heart', rar: 0, max: 5, icon: 'i_heart', desc: '+^y15^w max health and heal ^y15^w.', apply: (s, n) => s.maxHp += 15 * n, onTake: p => healPlayer(15, true) },
  armor:    { name: 'Tanned Hide', rar: 0, max: 4, icon: 'i_shield', desc: '+^y1^w armor: reduces damage taken by ^y7%^w.', apply: (s, n) => s.armor += n },
  crit:     { name: 'Keen Eye', rar: 0, max: 4, icon: 'i_eye', desc: '+^y7%^w critical hit chance.', apply: (s, n) => s.crit += 0.07 * n },
  range:    { name: 'Long Arm', rar: 0, max: 3, icon: 'i_range', desc: '+^y20%^w range and +^y12%^w projectile speed.', apply: (s, n) => { s.range *= 1 + 0.2 * n; s.shotSpeed *= 1 + 0.12 * n; } },
  oilmax:   { name: 'Wide Reservoir', rar: 0, max: 3, icon: 'i_drop', desc: '+^y25^w max oil and +^y8%^w light radius.', apply: (s, n) => { s.maxOil += 25 * n; s.lightMult += 0.08 * n; } },
  magnet:   { name: 'Magnet', rar: 0, max: 2, icon: 'i_magnet', desc: '+^y60%^w pickup radius.', apply: (s, n) => s.pickup *= 1 + 0.6 * n },
  greed:    { name: "Golden Fingers", rar: 0, max: 3, icon: 'i_coin', desc: '+^y30%^w coins collected.', apply: (s, n) => s.coinMult += 0.3 * n },
  xp:       { name: 'Lit Mind', rar: 0, max: 3, icon: 'i_book', desc: "+^y15%^w experience gained.", apply: (s, n) => s.xpMult += 0.15 * n },
  thorns:   { name: 'Bramble Thorns', rar: 0, max: 2, icon: 'i_thorn', desc: 'Whoever touches you takes ^y150%^w of your damage.', apply: (s, n) => s.thorns += 1.5 * n },
  medic:    { name: 'Herbalist', rar: 0, max: 2, icon: 'i_flask', desc: 'Potions and hearts heal ^y40%^w more.', apply: (s, n) => s.healMult += 0.4 * n },
  multishot:{ name: 'Double Wick', rar: 1, max: 3, icon: 'i_multi', desc: '+^y1^w projectile per volley, ^r-8%^w damage.', apply: (s, n) => { s.proj += n; s.dmgMult -= 0.08 * n; } },
  pierce:   { name: 'Iron Tip', rar: 1, max: 3, icon: 'i_pierce', desc: 'Projectiles pierce ^y1^w more enemy.', apply: (s, n) => s.pierce += n },
  bounce:   { name: 'Ricochet', rar: 1, max: 3, icon: 'i_bounce', desc: 'Projectiles bounce off walls ^y1^w more time.', apply: (s, n) => s.bounce += n },
  homing:   { name: 'Will-o\'-the-Wisp', rar: 1, max: 2, icon: 'i_wisp', desc: 'Projectiles curve toward enemies.', apply: (s, n) => s.homing += n },
  burn:     { name: 'Firebrand', rar: 1, max: 3, icon: 'i_flame', desc: '^y18%^w chance to ^oignite^w the target.', apply: (s, n) => s.burn += 0.18 * n },
  poison:   { name: 'Black Sap', rar: 1, max: 3, icon: 'i_poison', desc: '^y20%^w chance to ^gpoison^w. Poison stacks.', apply: (s, n) => s.poison += 0.2 * n },
  chill:    { name: 'Hoarfrost', rar: 1, max: 3, icon: 'i_snow', desc: '^y18%^w chance to ^cchill^w. Three stacks freeze.', apply: (s, n) => s.chill += 0.18 * n },
  dash:     { name: 'Nimble Legs', rar: 1, max: 2, icon: 'i_wing', desc: '+^y1^w dash charge.', apply: (s, n) => s.dashCharges += n },
  dashfire: { name: 'Burning Trail', rar: 1, max: 1, icon: 'i_flame', desc: 'Dashing leaves a ^ofire trail^w that burns enemies.', apply: (s, n) => s.dashfire = n },
  fury:     { name: 'Frenzy', rar: 1, max: 2, icon: 'i_rate', desc: 'Each kill: +^y35%^w fire rate for ^y2.5^w seconds.', apply: (s, n) => s.fury += 0.35 * n },
  dodge:    { name: 'Reflexes', rar: 1, max: 3, icon: 'i_wing', desc: '^y10%^w chance to dodge a hit.', apply: (s, n) => s.dodge += 0.1 * n },
  flare:    { name: 'Fierce Flare', rar: 1, max: 2, icon: 'i_sun', desc: 'The Flare costs ^y25%^w less and deals +^y50%^w damage.', apply: (s, n) => { s.flareCost *= Math.pow(0.75, n); s.flareMult += 0.5 * n; } },
  leech:    { name: 'Thirst', rar: 1, max: 3, icon: 'i_blood', desc: 'Each kill heals ^y1^w health.', apply: (s, n) => s.leech += n },
  critdmg:  { name: 'Killing Blow', rar: 1, max: 3, icon: 'i_skull', desc: '+^y50%^w critical hit damage.', apply: (s, n) => s.critMult += 0.5 * n },
  oileff:   { name: 'Clean Wick', rar: 1, max: 2, icon: 'i_lantern', desc: 'Oil burns ^y35%^w slower.', apply: (s, n) => s.oilDrain *= Math.pow(0.65, n) },
  chain:    { name: 'Electric Arc', rar: 2, max: 3, icon: 'i_bolt', desc: '^y15%^w chance for a hit to unleash ^blightning^w on 3 enemies.', apply: (s, n) => s.chain += 0.15 * n },
  explode:  { name: 'Unstable Ashes', rar: 2, max: 2, icon: 'i_urn', desc: 'Slain enemies ^oexplode^w, hurting those nearby.', apply: (s, n) => s.explode += n },
  orbit:    { name: 'Fireflies', rar: 2, max: 3, icon: 'i_orbit', desc: '+^y1^w orbiting firefly: hurts enemies and blocks projectiles.', apply: (s, n) => s.orbit += n },
  split:    { name: 'Shards', rar: 2, max: 1, icon: 'i_star', desc: 'Projectiles break into ^y3^w shards on impact.', apply: (s, n) => s.split = n },
  comet:    { name: 'Comet', rar: 2, max: 2, icon: 'i_moon', desc: 'Every few shots a piercing ^ycomet^w fires for ^y300%^w damage.', apply: (s, n) => s.comet += n },
  berserk:  { name: 'Blood Fury', rar: 2, max: 1, icon: 'i_blood', desc: '+^y1%^w damage for every ^y1%^w of missing health.', apply: (s, n) => s.berserk = n },
  secondwind:{ name: 'Last Breath', rar: 2, max: 1, icon: 'i_heart', desc: 'Once per depth, survive a lethal hit.', apply: (s, n) => s.secondwind = n },
  ashguard: { name: 'Ash Armor', rar: 2, max: 1, icon: 'i_shield', desc: 'When hit, you release a ^owave of fire^w.', apply: (s, n) => s.ashguard = n },
  guardian: { name: 'Warden Light', rar: 3, max: 1, icon: 'i_lamp', desc: 'Every ^y10^w seconds a shield of light absorbs a hit.', apply: (s, n) => s.guardian = n },
  primal:   { name: 'First Flame', rar: 3, max: 1, icon: 'i_flame', desc: 'All hits ^oignite^w and burning deals double damage.', apply: (s, n) => { s.primal = n; s.burnMult += 1; } },
  swarm:    { name: 'Burning Swarm', rar: 3, max: 1, icon: 'i_multi', desc: '+^y2^w projectiles per volley, ^r-12%^w damage.', apply: (s, n) => { s.proj += 2; s.dmgMult -= 0.12; } },
  echo:     { name: 'Echo', rar: 3, max: 1, icon: 'i_bell', desc: '^y30%^w chance to fire a second volley.', apply: (s, n) => s.echo = 0.3 },
  sun:      { name: 'Little Sun', rar: 3, max: 1, icon: 'i_sun', desc: 'Your light ^oburns^w enemies close to you.', apply: (s, n) => s.sun = n },
};

// ---------------------------------------------------------------------
//  Relics (treasure rooms, bosses, shops, secrets)
// ---------------------------------------------------------------------
const RELICS = {
  r_stoneheart: { name: 'Stone Heart', icon: 'i_heart', desc: '+^y30^w max health. ^r-5%^w speed.', apply: s => { s.maxHp += 30; s.speedMult -= 0.05; }, onTake: () => healPlayer(30, true) },
  r_mirror:  { name: 'Cracked Mirror', icon: 'i_mirror', desc: 'Dashing ^yreflects^w nearby enemy projectiles.', apply: s => s.dashReflect = 1 },
  r_crown:   { name: 'Drowned Man\'s Crown', icon: 'i_crown', desc: '+^y40%^w coins. Merchants give a ^y25%^w discount.', apply: s => { s.coinMult += 0.4; s.priceMult *= 0.75; } },
  r_skull:   { name: 'Laughing Skull', icon: 'i_skull', desc: '+^y35%^w damage. ^pCurse:^w Frailty.', apply: s => s.dmgMult += 0.35, curse: 'c_frail' },
  r_lens:    { name: "Amber Lens", icon: 'i_lens', desc: '+^y12%^w crit. Crits ^oignite^w.', apply: s => { s.crit += 0.12; s.critBurn = 1; } },
  r_wick:    { name: 'Eternal Wick', icon: 'i_lantern', desc: 'Oil no longer burns over time.', apply: s => s.noOilDrain = 1 },
  r_bell:    { name: 'Silent Bell', icon: 'i_bell', desc: 'Entering a room leaves enemies ^ystunned^w for 1.5 seconds.', apply: s => s.bellStun = 1.5 },
  r_hourglass:{ name: 'Broken Hourglass', icon: 'i_hourglass', desc: '+^y25%^w fire rate, +^y12%^w speed. ^pCurse:^w Haste.', apply: s => { s.rateMult += 0.25; s.speedMult += 0.12; }, curse: 'c_haste' },
  r_tooth:   { name: 'Vampire Fang', icon: 'i_tooth', desc: 'Each critical hit heals ^y1^w health.', apply: s => s.critHeal = 1 },
  r_eye:     { name: 'Third Eye', icon: 'i_eye', desc: 'Reveals the map and secret rooms. +^y10%^w light.', apply: s => { s.mapReveal = 1; s.lightMult += 0.1; } },
  r_quiver:  { name: 'Bone Quiver', icon: 'i_quiver', desc: '+^y2^w projectiles. ^r-10%^w fire rate.', apply: s => { s.proj += 2; s.rateMult -= 0.1; } },
  r_anvil:   { name: 'Anvil', icon: 'i_anvil', desc: '+^y50%^w damage, bigger projectiles. ^r-20%^w fire rate.', apply: s => { s.dmgMult += 0.5; s.rateMult -= 0.2; s.shotSize += 1; } },
  r_feather: { name: 'Raven Feather', icon: 'i_wing', desc: '+^y1^w dash charge, longer dash that recharges faster.', apply: s => { s.dashCharges += 1; s.dashDist += 0.3; s.dashCd *= 0.8; } },
  r_moth:    { name: 'Moth Wings', icon: 'i_wing', desc: 'Immune to ^gpoison^w and ^sslow^w. +^y10%^w speed.', apply: s => { s.immune.poison = 1; s.immune.slow = 1; s.speedMult += 0.1; } },
  r_ember:   { name: 'Ember of the First Fire', icon: 'i_flame', desc: '+^y1^w orbiting firefly. The Flare costs half.', apply: s => { s.orbit += 1; s.flareCost *= 0.5; } },
  r_key:     { name: 'Skeleton Key', icon: 'i_key', desc: '+^y3^w keys. Golden chests are more generous.', apply: s => s.goldKeys = 1, onTake: p => { p.keys += 3; } },
  r_blood:   { name: 'Blood Pact', icon: 'i_cup', desc: '+^y60%^w damage below 40% health. ^pCurse:^w Bitter Blood.', apply: s => s.lowHpDmg = 0.6, curse: 'c_blood' },
  r_ice:     { name: 'Heart of Frost', icon: 'i_ice', desc: 'All hits ^cchill^w. Immune to frost.', apply: s => { s.chillAll = 1; s.immune.chill = 1; } },
  r_storm:   { name: 'Storm Bottle', icon: 'i_storm', desc: 'Every 3 seconds ^blightning^w strikes an enemy (250% damage).', apply: s => s.storm = 1 },
  r_shell:   { name: 'Tortoise Shell', icon: 'i_shell', desc: '+^y4^w armor. ^r-12%^w speed.', apply: s => { s.armor += 4; s.speedMult -= 0.12; } },
  r_clover:  { name: 'Dried Clover', icon: 'i_clover', desc: 'Rarer perks and a ^yfourth choice^w each level.', apply: s => { s.extraChoice = 1; s.luck += 1; } },
  r_lamp:    { name: 'Miner\'s Lamp', icon: 'i_lamp', desc: '+^y35%^w light radius, +^y10%^w crit.', apply: s => { s.lightMult += 0.35; s.crit += 0.1; } },
  r_coffin:  { name: 'Coffin Nail', icon: 'i_coffin', desc: 'On death, ^yrevive^w once with half health.', apply: s => s.revive = 1 },
  r_ash:     { name: 'Ash Urn', icon: 'i_urn', desc: 'Slain enemies leave ^oflames^w on the ground.', apply: s => s.ashTrail = 1 },
  r_mask:    { name: 'Jester\'s Mask', icon: 'i_mask', desc: '+^y20%^w dodge. ^pCurse:^w Fog.', apply: s => s.dodge += 0.2, curse: 'c_fog' },
  r_gauntlet:{ name: 'Smith\'s Gauntlet', icon: 'i_hand', desc: '+^y20%^w damage, +^y2^w armor, projectiles pierce +^y1^w.', apply: s => { s.dmgMult += 0.2; s.armor += 2; s.pierce += 1; } },
};

// ---------------------------------------------------------------------
//  Curses (permanent maluses for the run)
// ---------------------------------------------------------------------
const CURSES = {
  c_dark:  { name: 'Pitch Dark', desc: '^r-25%^w light radius.', apply: s => s.lightMult -= 0.25 },
  c_frail: { name: 'Frailty', desc: '^r+20%^w damage taken.', apply: s => s.dmgTaken *= 1.2 },
  c_greed: { name: 'Greed', desc: 'Merchant prices ^r+40%^w.', apply: s => s.priceMult *= 1.4 },
  c_haste: { name: 'Haste', desc: 'Enemies are ^r12%^w faster.', apply: s => s.enemySpeed *= 1.12 },
  c_blood: { name: 'Bitter Blood', desc: 'Healing is ^r40%^w less effective.', apply: s => s.healMult -= 0.4 },
  c_fog:   { name: 'Fog', desc: 'The minimap is hidden.', apply: s => s.hideMap = 1 },
  c_weak:  { name: 'Weakness', desc: '^r-12%^w damage.', apply: s => s.dmgMult -= 0.12 },
  c_rust:  { name: 'Rust', desc: '^r-1^w armor and ^r-10%^w fire rate.', apply: s => { s.armor -= 1; s.rateMult -= 0.1; } },
};

// ---------------------------------------------------------------------
//  Status effects
// ---------------------------------------------------------------------
const STATUS = {
  burn:    { name: 'Burning', icon: 's_burn', col: '#f29c38', bad: true },
  poison:  { name: 'Poison', icon: 's_poison', col: '#8fd35a', bad: true },
  chill:   { name: 'Frost', icon: 's_chill', col: '#7fd8e6', bad: true },
  slow:    { name: 'Slow', icon: 's_slow', col: '#b8b2c2', bad: true },
  weak:    { name: 'Weakness', icon: 's_weak', col: '#e0574a', bad: true },
  fragile: { name: 'Frailty', icon: 's_fragile', col: '#e0574a', bad: true },
  blind:   { name: 'Blindness', icon: 's_blind', col: '#8a8294', bad: true },
  rage:    { name: 'Rage', icon: 's_rage', col: '#f29c38', bad: false },
  immune:  { name: 'Purity', icon: 's_shield', col: '#7fd8e6', bad: false },
  invis:   { name: 'Invisible', icon: 's_invis', col: '#b8b2c2', bad: false },
  fury:    { name: 'Frenzy', icon: 's_rage', col: '#f6cf57', bad: false },
};

// ---------------------------------------------------------------------
//  Consumables (4 slots, stack up to 3)
// ---------------------------------------------------------------------
const CONS = {
  potion:  { name: 'Red Potion', spr: 'potion', w: 10, price: 14, desc: 'Heals ^y30^w health.', use: p => { if (p.hp >= p.stats.maxHp) return false; healPlayer(30); return true; } },
  bigpotion:{ name: 'Vital Elixir', spr: 'bigpotion', w: 2, price: 30, desc: 'Heals ^yall^w health.', use: p => { if (p.hp >= p.stats.maxHp) return false; healPlayer(999); return true; } },
  oil:     { name: "Oil Flask", spr: 'oilflask', w: 8, price: 10, desc: 'Restores ^y60^w oil.', use: p => { if (p.oil >= p.stats.maxOil) return false; addOil(60); Sound.play('oil'); return true; } },
  bomb:    { name: 'Bomb', spr: 'bomb', w: 9, price: 9, desc: 'Explodes shortly after: ^y80^w area damage. Breaks cracked rocks and secret passages.', use: p => { placeBomb(p.x, p.y + 3, 'player'); return true; } },
  antidote:{ name: 'Antidote', spr: 'antidote', w: 6, price: 10, desc: 'Removes all debuffs and protects against them for ^y6^w seconds.', use: p => { cleanse(p); addStatus(p, 'immune', 6); Sound.play('heal'); return true; } },
  rage:    { name: 'Miner\'s Brew', spr: 'rage', w: 6, price: 12, desc: '+^y50%^w damage and fire rate for ^y10^w seconds.', use: p => { addStatus(p, 'rage', 10); Sound.play('flare', 0.5); return true; } },
  frost:   { name: 'Frost Vial', spr: 'frost', w: 5, price: 14, desc: '^cFreezes^w all enemies in the room for ^y3^w seconds.', use: p => { freezeAll(3); return true; } },
  map:     { name: 'Scroll', spr: 'scroll', w: 4, price: 8, desc: 'Reveals the depth\'s map, secrets included.', use: p => { revealMap(); return true; } },
  firefly: { name: 'Jar of Fireflies', spr: 'jar', w: 5, price: 12, desc: '^y3^w fireflies protect you for ^y25^w seconds.', use: p => { p.tempOrbitT = 25; p.tempOrbit = 3; Sound.play('pickup'); return true; } },
  dice:    { name: 'Loaded Die', spr: 'dice', w: 3, price: 18, desc: 'Gain a random perk. ^r30%^w chance of also receiving a curse.', use: p => { rollDice(); return true; } },
  smoke:   { name: "Shadow Dust", spr: 'pouch', w: 4, price: 10, desc: 'You become ^sinvisible^w for ^y4^w seconds.', use: p => { addStatus(p, 'invis', 4); Particles.burst(p.x, p.y, 30, ['#4a4068', '#8a80b0', '#2a2440'], 60, 0.8); Sound.play('dash'); return true; } },
  holy:    { name: 'Holy Water', spr: 'holy', w: 2, price: 28, desc: 'Removes a ^pcurse^w. With no curses, heals 30 health.', use: p => { if (p.curses.length) { const c = p.curses.pop(); toast('Curse broken: ' + CURSES[c].name, '#c57ae0'); recalcStats(); Sound.play('heal'); } else { if (p.hp >= p.stats.maxHp) return false; healPlayer(30); } return true; } },
  feather: { name: 'Phoenix Feather', spr: 'feather', w: 1.5, price: 35, desc: 'Passive: if you die, ^yrevive^w with half health (consumed).', passive: true, use: p => false },
};

// ---------------------------------------------------------------------
//  Enemies
// ---------------------------------------------------------------------
const ENEMIES = {
  rat:      { name: 'Crypt Rat', spr: 'rat', hp: 14, spd: 74, dmg: 8, r: 5, ai: 'chaser', xp: 1, side: true, burst: true },
  bat:      { name: 'Bat', spr: 'bat', hp: 10, spd: 62, dmg: 7, r: 5, ai: 'erratic', xp: 1, fly: true, anim: 10 },
  skeleton: { name: 'Skeleton', spr: 'skeleton', hp: 28, spd: 30, dmg: 10, r: 6, ai: 'shooter', xp: 2, shot: { kind: 'bone', spd: 110, cd: 2.4, n: 1 } },
  skull:    { name: 'Wisp Skull', spr: 'skull', hp: 24, spd: 26, dmg: 8, r: 6, ai: 'caster', xp: 3, fly: true, keep: 90, shot: { kind: 'orb', col: 'violet', spd: 68, cd: 3.2, ring: 6 } },
  ghoul:    { name: 'Ghoul', spr: 'ghoul', hp: 46, spd: 36, dmg: 12, r: 7, ai: 'charger', xp: 3, chargeSpd: 225 },
  grub:     { name: 'Grub', spr: 'grub', hp: 26, spd: 38, dmg: 9, r: 6, ai: 'chaser', xp: 2, side: true, split: 'grubling', splitN: 2 },
  grubling: { name: 'Grublet', spr: 'grubling', hp: 9, spd: 66, dmg: 6, r: 4, ai: 'chaser', xp: 0.5, side: true },
  spore:    { name: 'Sporangium', spr: 'spore', hp: 42, spd: 0, dmg: 8, r: 7, ai: 'turret', xp: 3, shot: { kind: 'spore', spd: 52, cd: 2.8, ring: 8, status: 'poison' }, deathCloud: true },
  hopper:   { name: 'Hopping Fungus', spr: 'hopper', hp: 34, spd: 0, dmg: 10, r: 6, ai: 'hopper', xp: 3, hopCd: 1.7, landRing: 6 },
  moth:     { name: 'Pale Moth', spr: 'moth', hp: 18, spd: 48, dmg: 7, r: 6, ai: 'erratic', fly: true, xp: 2, anim: 12, shot: { kind: 'dust', spd: 90, cd: 2.4, n: 3, spread: 0.35, status: 'slow' } },
  automaton:{ name: 'Automaton', spr: 'automaton', hp: 52, spd: 42, dmg: 13, r: 6, ai: 'charger', xp: 3, chargeSpd: 270 },
  turret:   { name: 'Turret', spr: 'turret', hp: 48, spd: 0, dmg: 10, r: 7, ai: 'turret', xp: 3, shot: { kind: 'orb', col: 'red', spd: 125, cd: 2.2, n: 1, burst: 3, aimed: true } },
  slag:     { name: 'Molten Slag', spr: 'slag', hp: 38, spd: 30, dmg: 11, r: 6, ai: 'chaser', xp: 3, trail: true },
  smith:    { name: 'Corrupted Smith', spr: 'smith', hp: 95, spd: 26, dmg: 15, r: 7, ai: 'shielder', xp: 5, shield: true },
  spark:    { name: 'Spark', spr: 'spark', hp: 12, spd: 92, dmg: 14, r: 4, ai: 'kamikaze', fly: true, xp: 1, anim: 14 },
  drowned:  { name: 'Drowned', spr: 'drowned', hp: 52, spd: 42, dmg: 12, r: 6, ai: 'phaser', fly: true, xp: 4, touch: 'chill' },
  eel:      { name: 'Eel', spr: 'eel', hp: 42, spd: 0, dmg: 13, r: 6, ai: 'dasher', xp: 3, side: true },
  jelly:    { name: 'Jellyfish', spr: 'jelly', hp: 46, spd: 22, dmg: 10, r: 6, ai: 'caster', fly: true, keep: 100, xp: 4, shot: { kind: 'orb', col: 'cyan', spd: 52, cd: 3.0, ring: 10, status: 'chill' } },
  shade:    { name: 'Shade', spr: 'shade', hp: 36, spd: 0, dmg: 11, r: 6, ai: 'teleporter', xp: 4, shot: { kind: 'orb', col: 'violet', spd: 115, n: 5, spread: 0.5, status: 'weak' } },
  cultist:  { name: 'Cultist', spr: 'cultist', hp: 62, spd: 30, dmg: 11, r: 6, ai: 'summoner', xp: 5, keep: 110, summon: 'wisp', shot: { kind: 'orb', col: 'red', spd: 100, cd: 2.8, n: 3, spread: 0.3 } },
  wisp:     { name: 'Black Flame', spr: 'wisp', hp: 10, spd: 88, dmg: 12, r: 4, ai: 'kamikaze', fly: true, xp: 0.5 },
  knight:   { name: 'Hollow Knight', spr: 'knight', hp: 150, spd: 34, dmg: 18, r: 7, ai: 'shielder', shield: true, xp: 7, slam: true },
  eye:      { name: 'Eye of the Well', spr: 'eye', hp: 78, spd: 16, dmg: 10, r: 7, ai: 'spinner', fly: true, xp: 6, shot: { kind: 'orb', col: 'red', spd: 82, cd: 0.17, arms: 3, status: 'fragile' } },
};

const ELITE_MODS = {
  armored:  { name: 'Armored', col: '#a59fb0' },
  swift:    { name: 'Swift', col: '#f6cf57' },
  vampiric: { name: 'Vampiric', col: '#e0574a' },
  volatile: { name: 'Volatile', col: '#f29c38' },
  regen:    { name: 'Regenerating', col: '#8fd35a' },
  splitter: { name: 'Splitting', col: '#c57ae0' },
  venom:    { name: 'Venomous', col: '#6fc04a' },
};

// ---------------------------------------------------------------------
//  Boss
// ---------------------------------------------------------------------
const BOSSES = {
  bones: {
    name: 'The Bone Warden', title: 'King of the Forgotten Crypts', spr: 'boss_bones', hp: 800, r: 11, spd: 34,
    phases: [
      { at: 1, gap: 1.0, pats: [
        { p: 'aimed', n: 5, spread: 0.5, count: 3, gap: 0.5, spd: 115, kind: 'bone' },
        { p: 'ring', n: 12, count: 2, gap: 0.7, spd: 75, kind: 'bone' },
        { p: 'summon', type: 'skeleton', count: 2, cap: 4 },
        { p: 'charge', count: 2, spd: 210 },
      ] },
      { at: 0.5, gap: 0.6, pats: [
        { p: 'spiral', arms: 3, rate: 9, rot: 2.2, dur: 3.2, spd: 85, kind: 'bone' },
        { p: 'aimed', n: 7, spread: 0.8, count: 3, gap: 0.45, spd: 125, kind: 'bone' },
        { p: 'summon', type: 'rat', count: 3, cap: 6 },
        { p: 'charge', count: 3, spd: 245, ring: 8, kind: 'bone' },
        { p: 'ring', n: 16, count: 3, gap: 0.55, spd: 80, kind: 'bone' },
      ] },
    ]
  },
  mycel: {
    name: 'Mother Mycelium', title: 'Rotten Heart of the Fungal Caves', spr: 'boss_mycel', hp: 1350, r: 13, spd: 16,
    phases: [
      { at: 1, gap: 1.0, pats: [
        { p: 'ring', n: 14, count: 3, gap: 0.7, spd: 58, kind: 'spore', status: 'poison' },
        { p: 'rain', n: 8, dur: 2.4, hit: 'cloud' },
        { p: 'summon', type: 'grub', count: 2, cap: 5 },
        { p: 'aimed', n: 3, spread: 0.3, count: 4, gap: 0.35, spd: 135, kind: 'spore', status: 'poison' },
      ] },
      { at: 0.5, gap: 0.6, pats: [
        { p: 'spiral', arms: 4, rate: 11, rot: 1.6, dur: 3.5, spd: 66, kind: 'spore', status: 'poison' },
        { p: 'rain', n: 14, dur: 2.8, hit: 'cloud' },
        { p: 'summon', type: 'hopper', count: 2, cap: 4 },
        { p: 'ring', n: 20, count: 4, gap: 0.6, spd: 62, kind: 'spore', status: 'poison' },
      ] },
    ]
  },
  forge: {
    name: 'The Forger', title: 'Hammer of the Sunken Foundry', spr: 'boss_forge', hp: 2000, r: 13, spd: 42,
    phases: [
      { at: 1, gap: 0.9, pats: [
        { p: 'slam', count: 2, ring: 12, kind: 'fire', status: 'burn' },
        { p: 'charge', count: 2, spd: 260, ring: 10, kind: 'fire', status: 'burn' },
        { p: 'wall', count: 3, kind: 'fire', status: 'burn' },
        { p: 'aimed', n: 5, spread: 0.6, count: 3, gap: 0.4, spd: 130, kind: 'fire', status: 'burn' },
      ] },
      { at: 0.5, gap: 0.55, pats: [
        { p: 'slam', count: 3, ring: 16, kind: 'fire', status: 'burn' },
        { p: 'rain', n: 12, dur: 2.4, hit: 'blast' },
        { p: 'spiral', arms: 2, rate: 14, rot: 3, dur: 3, spd: 95, kind: 'fire', status: 'burn' },
        { p: 'charge', count: 3, spd: 285, ring: 12, kind: 'fire' },
        { p: 'summon', type: 'spark', count: 4, cap: 6 },
      ] },
    ]
  },
  abyss: {
    name: "The Voice of the Abyss", title: 'Priestess of the Black Waters', spr: 'boss_abyss', hp: 2800, r: 12, spd: 0,
    phases: [
      { at: 1, gap: 0.9, pats: [
        { p: 'teleport', n: 7, spread: 0.9, spd: 115, kind: 'ice', status: 'chill' },
        { p: 'ring', n: 16, count: 3, gap: 0.7, spd: 52, kind: 'ice', status: 'chill' },
        { p: 'beam', count: 2, warm: 1.0, dur: 2.6, rot: 0.85 },
        { p: 'summon', type: 'jelly', count: 2, cap: 3 },
      ] },
      { at: 0.5, gap: 0.55, pats: [
        { p: 'darkpulse' },
        { p: 'spiral', arms: 5, rate: 9, rot: -1.4, dur: 3.5, spd: 60, kind: 'ice', status: 'chill' },
        { p: 'beam', count: 3, warm: 0.9, dur: 3, rot: 1.1 },
        { p: 'teleport', n: 9, spread: 1.1, spd: 125, kind: 'ice', status: 'chill' },
        { p: 'wall', count: 3, kind: 'ice', status: 'chill' },
      ] },
    ]
  },
  devourer: {
    name: 'The Light Devourer', title: 'He Who Put Out the Sun', spr: 'boss_devourer', hp: 4600, r: 15, spd: 22,
    phases: [
      { at: 1, gap: 0.8, pats: [
        { p: 'spiral', arms: 4, rate: 10, rot: 1.8, dur: 3.2, spd: 80, kind: 'void' },
        { p: 'aimed', n: 9, spread: 1.0, count: 3, gap: 0.5, spd: 120, kind: 'void' },
        { p: 'summon', type: 'wisp', count: 4, cap: 8 },
        { p: 'ring', n: 24, count: 3, gap: 0.6, spd: 70, kind: 'void' },
      ] },
      { at: 0.66, gap: 0.6, pats: [
        { p: 'beam', count: 4, warm: 0.9, dur: 3, rot: 0.8 },
        { p: 'drain', dur: 4 },
        { p: 'rain', n: 16, dur: 2.6, hit: 'blast' },
        { p: 'charge', count: 3, spd: 270, ring: 14, kind: 'void' },
        { p: 'spiral', arms: 6, rate: 12, rot: -1.5, dur: 3.2, spd: 75, kind: 'void' },
      ] },
      { at: 0.33, gap: 0.4, pats: [
        { p: 'beam', count: 2, warm: 0.7, dur: 3.5, rot: 1.7 },
        { p: 'darkpulse' },
        { p: 'slam', count: 3, ring: 20, kind: 'void' },
        { p: 'spiral', arms: 8, rate: 12, rot: 2.2, dur: 3.5, spd: 85, kind: 'void' },
        { p: 'summon', type: 'cultist', count: 2, cap: 4 },
        { p: 'drain', dur: 3.5 },
      ] },
    ]
  },
};

// ---------------------------------------------------------------------
//  Biomes (depths)
// ---------------------------------------------------------------------
const BIOMES = [
  {
    id: 'crypt', name: 'The Crypts', music: 'crypt', boss: 'bones', dark: 0.68,
    lore: 'Beneath the darkened city rest the first wardens. Their bones have not forgotten how to fight.',
    floor: ['#2a2430', '#241f2a', '#2e2834'], floorD: '#1a1520', wall: '#3c3448', wallD: '#231c2a', wallL: '#544a62', accent: '#6b5a80',
    pool: [['rat', 1, 3], ['bat', 1, 3], ['skeleton', 2, 3], ['skull', 3, 2], ['ghoul', 3, 1.5]], deco: 'bones', urns: true
  },
  {
    id: 'fungus', name: 'The Fungal Caves', music: 'fungus', boss: 'mycel', dark: 0.72,
    lore: 'The dark breathes here. Spores seek warm flesh and never stop growing.',
    floor: ['#1f2a22', '#1b251e', '#243026'], floorD: '#141c16', wall: '#2f3e30', wallD: '#1c261d', wallL: '#46604a', accent: '#a33a7a',
    pool: [['grub', 2, 3], ['spore', 2.5, 2], ['hopper', 3, 2], ['moth', 2, 2.5], ['rat', 1, 1], ['bat', 1, 1], ['skeleton', 2, 1]], deco: 'shrooms'
  },
  {
    id: 'forge', name: 'The Sunken Foundry', music: 'forge', boss: 'forge', dark: 0.75,
    lore: "Lanterns were forged here. Now the furnaces burn for a different master.",
    floor: ['#2c2220', '#26201e', '#32261f'], floorD: '#1a1412', wall: '#463026', wallD: '#2a1c16', wallL: '#6a4a36', accent: '#f29c38',
    pool: [['automaton', 3, 2.5], ['turret', 3, 2], ['slag', 2.5, 2.5], ['smith', 4, 1.2], ['spark', 1.5, 2.5], ['ghoul', 3, 1], ['moth', 2, 1]], deco: 'cracks', barrels: true
  },
  {
    id: 'abyss', name: "The Flooded Abyss", music: 'abyss', boss: 'abyss', dark: 0.8,
    lore: "The black water swallowed the prayers. Something down there still sings.",
    floor: ['#18242c', '#152028', '#1c2a32'], floorD: '#0e161c', wall: '#22343e', wallD: '#121e24', wallL: '#355260', accent: '#5aa0aa',
    pool: [['drowned', 3, 2.5], ['eel', 3, 2.5], ['jelly', 3.5, 2], ['shade', 3.5, 2], ['spark', 1.5, 1], ['smith', 4, 0.8], ['skull', 3, 1]], deco: 'puddles'
  },
  {
    id: 'heart', name: 'The Heart of the Well', music: 'heart', boss: 'devourer', dark: 0.85,
    lore: "Here the First Flame was devoured. Only the last lantern can rekindle it.",
    floor: ['#221824', '#1d141f', '#281c2a'], floorD: '#130c15', wall: '#382238', wallD: '#20121f', wallL: '#56345a', accent: '#c57ae0',
    pool: [['cultist', 4, 2], ['knight', 5, 1.2], ['eye', 4.5, 1.5], ['drowned', 3, 1.5], ['shade', 3.5, 1.5], ['automaton', 3, 1.5], ['hopper', 3, 1], ['jelly', 3.5, 1], ['ghoul', 3, 1]], deco: 'veins'
  },
];

// ---------------------------------------------------------------------
//  Lanterns (starting characters)
// ---------------------------------------------------------------------
const LANTERNS = [
  {
    id: 'warden', name: 'Warden\'s Lantern', glass: '#f6cf57',
    desc: 'Balanced and reliable. Start with a ^yRed Potion^w and a ^yBomb^w.',
    unlock: () => true, unlockText: '',
    apply: s => { }, start: p => { giveCons('potion'); giveCons('bomb'); }
  },
  {
    id: 'pilgrim', name: 'Pilgrim\'s Lantern', glass: '#8fd35a',
    desc: '+^y25^w health, +^y2^w armor, ^r-8%^w speed and fire rate. Start with two ^yBombs^w and a ^yPotion^w.',
    unlock: st => st.bossKills >= 1, unlockText: 'Defeat a depth warden.',
    apply: s => { s.maxHp += 25; s.armor += 2; s.speedMult -= 0.08; s.rateMult -= 0.08; },
    start: p => { giveCons('bomb'); giveCons('bomb'); giveCons('potion'); }
  },
  {
    id: 'broken', name: 'Broken Lantern', glass: '#e0574a',
    desc: '+^y35%^w damage, +^y10%^w crit, ^r-35%^w max health. Start with the ^oFirebrand^w perk.',
    unlock: st => st.bestDepth >= 3, unlockText: 'Reach the third depth.',
    apply: s => { s.dmgMult += 0.35; s.crit += 0.1; s.maxHp = Math.round(s.maxHp * 0.65); },
    start: p => { p.perks.burn = 1; }
  },
  {
    id: 'hollow', name: 'Hollow Lantern', glass: '#7fd8e6',
    desc: '+^y50^w oil, Flare ^y-40%^w cost, +^y25%^w light, +^y1^w dash. ^r-10%^w damage.',
    unlock: st => st.bestDepth >= 4, unlockText: 'Reach the fourth depth.',
    apply: s => { s.maxOil += 50; s.flareCost *= 0.6; s.lightMult += 0.25; s.dashCharges += 1; s.dmgMult -= 0.1; },
    start: p => { giveCons('oil'); }
  },
  {
    id: 'black', name: 'Black Lantern', glass: '#c57ae0',
    desc: 'Start with ^ytwo random relics^w and ^ptwo curses^w. For those who do not fear the dark.',
    unlock: st => st.wins >= 1, unlockText: 'Rekindle the First Flame at least once.',
    apply: s => { },
    start: p => {
      const pool = Object.keys(RELICS).filter(k => !RELICS[k].curse);
      shuffle(pool);
      p.relics.push(pool[0], pool[1]);
      const cs = shuffle(Object.keys(CURSES).filter(c => c !== 'c_fog'));
      p.curses.push(cs[0], cs[1]);
      for (const r of [pool[0], pool[1]]) if (RELICS[r].onTake) RELICS[r].onTake(p);
    }
  },
];

const ARDOR = [
  'The journey as it was handed down.',
  'Enemies: +^r25%^w health.',
  'Also: enemies +^r20%^w damage.',
  'Also: twice as many elite champions.',
  'Also: healing ^r-30%^w, fewer hearts on the ground.',
  'Also: faster bosses and oil burns ^r50%^w faster.',
];

// merchant lines
const MERCHANT_LINES = [
  'Light in exchange for coins, wanderer.',
  'Don\'t ask where they come from. Just pay.',
  'Every lantern that goes down... I rarely see it come back up.',
  'These prices? The dark costs everyone dearly.',
  'You look like someone in need of a potion.',
];
