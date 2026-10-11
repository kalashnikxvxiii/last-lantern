'use strict';
// =====================================================================
//  Dati di gioco: statistiche, doni, reliquie, maledizioni, consumabili,
//  nemici, boss, biomi, lanterne
// =====================================================================

const RARITY = [
  { name: 'Comune', col: '#c8c0b0', w: 62 },
  { name: 'Raro', col: '#6fa8e8', w: 27 },
  { name: 'Epico', col: '#c57ae0', w: 9 },
  { name: 'Leggendario', col: '#f6cf57', w: 2.5 },
];

function baseStats() {
  return {
    maxHp: 60, dmg: 10, dmgMult: 1, fireRate: 3.0, rateMult: 1, shotSpeed: 230, range: 200, shotSize: 3,
    proj: 1, pierce: 0, bounce: 0, homing: 0, crit: 0.05, critMult: 2.0,
    speed: 92, speedMult: 1, armor: 0, dodge: 0, dashCharges: 1, dashCd: 1.0, dashDist: 1, iframes: 0.9,
    maxOil: 100, oilDrain: 1, light: 104, lightMult: 1, pickup: 26, coinMult: 1, xpMult: 1, healMult: 1,
    leech: 0, thorns: 0, burn: 0, poison: 0, chill: 0, chain: 0, explode: 0, orbit: 0, flareCost: 40, flareMult: 1,
    fury: 0, comet: 0, split: 0, berserk: 0, secondwind: 0, ashguard: 0, guardian: 0, primal: 0, echo: 0, sun: 0,
    dashfire: 0, critBurn: 0, critHeal: 0, dashReflect: 0, noOilDrain: 0, bellStun: 0, immune: {}, chillAll: 0,
    storm: 0, extraChoice: 0, luck: 0, revive: 0, ashTrail: 0, lowHpDmg: 0, priceMult: 1,
    enemySpeed: 1, dmgTaken: 1, mapReveal: 0, hideMap: 0, goldKeys: 0, burnMult: 1
  };
}

// ---------------------------------------------------------------------
//  Doni (scelti al passaggio di livello)
// ---------------------------------------------------------------------
const PERKS = {
  dmg:      { name: 'Braci Vive', rar: 0, max: 5, icon: 'i_blade', desc: '+^y18%^w danno dei proiettili.', apply: (s, n) => s.dmgMult += 0.18 * n },
  rate:     { name: 'Mano Lesta', rar: 0, max: 5, icon: 'i_rate', desc: '+^y14%^w cadenza di fuoco.', apply: (s, n) => s.rateMult += 0.14 * n },
  speed:    { name: 'Passo Felpato', rar: 0, max: 3, icon: 'i_boot', desc: '+^y10%^w velocità di movimento.', apply: (s, n) => s.speedMult += 0.10 * n },
  hp:       { name: 'Cuore Robusto', rar: 0, max: 5, icon: 'i_heart', desc: '+^y15^w vita massima e ne curi ^y15^w.', apply: (s, n) => s.maxHp += 15 * n, onTake: p => healPlayer(15, true) },
  armor:    { name: 'Pelle Conciata', rar: 0, max: 4, icon: 'i_shield', desc: '+^y1^w armatura: riduce del ^y7%^w i danni subiti.', apply: (s, n) => s.armor += n },
  crit:     { name: 'Occhio Fino', rar: 0, max: 4, icon: 'i_eye', desc: '+^y7%^w probabilità di colpo critico.', apply: (s, n) => s.crit += 0.07 * n },
  range:    { name: 'Braccio Lungo', rar: 0, max: 3, icon: 'i_range', desc: '+^y20%^w gittata e +^y12%^w velocità dei proiettili.', apply: (s, n) => { s.range *= 1 + 0.2 * n; s.shotSpeed *= 1 + 0.12 * n; } },
  oilmax:   { name: 'Serbatoio Ampio', rar: 0, max: 3, icon: 'i_drop', desc: '+^y25^w olio massimo e +^y8%^w raggio di luce.', apply: (s, n) => { s.maxOil += 25 * n; s.lightMult += 0.08 * n; } },
  magnet:   { name: 'Calamita', rar: 0, max: 2, icon: 'i_magnet', desc: '+^y60%^w raggio di raccolta.', apply: (s, n) => s.pickup *= 1 + 0.6 * n },
  greed:    { name: "Dita d'Oro", rar: 0, max: 3, icon: 'i_coin', desc: '+^y30%^w monete raccolte.', apply: (s, n) => s.coinMult += 0.3 * n },
  xp:       { name: 'Mente Accesa', rar: 0, max: 3, icon: 'i_book', desc: "+^y15%^w esperienza ottenuta.", apply: (s, n) => s.xpMult += 0.15 * n },
  thorns:   { name: 'Spine di Rovo', rar: 0, max: 2, icon: 'i_thorn', desc: 'Chi ti tocca subisce il ^y150%^w del tuo danno.', apply: (s, n) => s.thorns += 1.5 * n },
  medic:    { name: 'Erborista', rar: 0, max: 2, icon: 'i_flask', desc: 'Pozioni e cuori curano il ^y40%^w in più.', apply: (s, n) => s.healMult += 0.4 * n },
  multishot:{ name: 'Doppio Stoppino', rar: 1, max: 3, icon: 'i_multi', desc: '+^y1^w proiettile per raffica, ^r-8%^w danno.', apply: (s, n) => { s.proj += n; s.dmgMult -= 0.08 * n; } },
  pierce:   { name: 'Punta di Ferro', rar: 1, max: 3, icon: 'i_pierce', desc: 'I proiettili trapassano ^y1^w nemico in più.', apply: (s, n) => s.pierce += n },
  bounce:   { name: 'Rimbalzo', rar: 1, max: 3, icon: 'i_bounce', desc: 'I proiettili rimbalzano sui muri ^y1^w volta in più.', apply: (s, n) => s.bounce += n },
  homing:   { name: 'Fuoco Fatuo', rar: 1, max: 2, icon: 'i_wisp', desc: 'I proiettili curvano verso i nemici.', apply: (s, n) => s.homing += n },
  burn:     { name: 'Tizzone', rar: 1, max: 3, icon: 'i_flame', desc: '^y18%^w di probabilità di ^oincendiare^w il bersaglio.', apply: (s, n) => s.burn += 0.18 * n },
  poison:   { name: 'Linfa Nera', rar: 1, max: 3, icon: 'i_poison', desc: '^y20%^w di probabilità di ^gavvelenare^w. Il veleno si accumula.', apply: (s, n) => s.poison += 0.2 * n },
  chill:    { name: 'Brina', rar: 1, max: 3, icon: 'i_snow', desc: '^y18%^w di probabilità di ^craffreddare^w. Tre cariche congelano.', apply: (s, n) => s.chill += 0.18 * n },
  dash:     { name: 'Gambe Agili', rar: 1, max: 2, icon: 'i_wing', desc: '+^y1^w carica di scatto.', apply: (s, n) => s.dashCharges += n },
  dashfire: { name: 'Scia Ardente', rar: 1, max: 1, icon: 'i_flame', desc: 'Lo scatto lascia una ^oscia di fuoco^w che brucia i nemici.', apply: (s, n) => s.dashfire = n },
  fury:     { name: 'Frenesia', rar: 1, max: 2, icon: 'i_rate', desc: 'Ogni uccisione: +^y35%^w cadenza per ^y2.5^w secondi.', apply: (s, n) => s.fury += 0.35 * n },
  dodge:    { name: 'Riflessi', rar: 1, max: 3, icon: 'i_wing', desc: '^y10%^w di probabilità di schivare un colpo.', apply: (s, n) => s.dodge += 0.1 * n },
  flare:    { name: 'Vampata Feroce', rar: 1, max: 2, icon: 'i_sun', desc: 'La Vampata costa il ^y25%^w in meno e fa +^y50%^w danno.', apply: (s, n) => { s.flareCost *= Math.pow(0.75, n); s.flareMult += 0.5 * n; } },
  leech:    { name: 'Sete', rar: 1, max: 3, icon: 'i_blood', desc: 'Ogni uccisione cura ^y1^w vita.', apply: (s, n) => s.leech += n },
  critdmg:  { name: 'Colpo Mortale', rar: 1, max: 3, icon: 'i_skull', desc: '+^y50%^w danno dei colpi critici.', apply: (s, n) => s.critMult += 0.5 * n },
  oileff:   { name: 'Stoppino Pulito', rar: 1, max: 2, icon: 'i_lantern', desc: 'L\'olio si consuma il ^y35%^w più lentamente.', apply: (s, n) => s.oilDrain *= Math.pow(0.65, n) },
  chain:    { name: 'Arco Voltaico', rar: 2, max: 3, icon: 'i_bolt', desc: '^y15%^w di probabilità che un colpo scateni un ^bfulmine^w su 3 nemici.', apply: (s, n) => s.chain += 0.15 * n },
  explode:  { name: 'Ceneri Instabili', rar: 2, max: 2, icon: 'i_urn', desc: 'I nemici uccisi ^oesplodono^w ferendo quelli vicini.', apply: (s, n) => s.explode += n },
  orbit:    { name: 'Lucciole', rar: 2, max: 3, icon: 'i_orbit', desc: '+^y1^w lucciola orbitante: ferisce i nemici e para i proiettili.', apply: (s, n) => s.orbit += n },
  split:    { name: 'Schegge', rar: 2, max: 1, icon: 'i_star', desc: 'I proiettili si spezzano in ^y3^w schegge all\'impatto.', apply: (s, n) => s.split = n },
  comet:    { name: 'Cometa', rar: 2, max: 2, icon: 'i_moon', desc: 'Ogni pochi colpi parte una ^ycometa^w perforante da ^y300%^w danno.', apply: (s, n) => s.comet += n },
  berserk:  { name: 'Furore del Sangue', rar: 2, max: 1, icon: 'i_blood', desc: '+^y1%^w danno per ogni ^y1%^w di vita mancante.', apply: (s, n) => s.berserk = n },
  secondwind:{ name: 'Ultimo Respiro', rar: 2, max: 1, icon: 'i_heart', desc: 'Una volta per profondità sopravvivi a un colpo mortale.', apply: (s, n) => s.secondwind = n },
  ashguard: { name: 'Corazza di Cenere', rar: 2, max: 1, icon: 'i_shield', desc: 'Quando vieni colpito rilasci un\'^oonda di fuoco^w.', apply: (s, n) => s.ashguard = n },
  guardian: { name: 'Lume Custode', rar: 3, max: 1, icon: 'i_lamp', desc: 'Ogni ^y10^w secondi uno scudo di luce assorbe un colpo.', apply: (s, n) => s.guardian = n },
  primal:   { name: 'Fiamma Prima', rar: 3, max: 1, icon: 'i_flame', desc: 'Tutti i colpi ^oincendiano^w e la bruciatura fa il doppio.', apply: (s, n) => { s.primal = n; s.burnMult += 1; } },
  swarm:    { name: 'Sciame Ardente', rar: 3, max: 1, icon: 'i_multi', desc: '+^y2^w proiettili per raffica, ^r-12%^w danno.', apply: (s, n) => { s.proj += 2; s.dmgMult -= 0.12; } },
  echo:     { name: 'Eco', rar: 3, max: 1, icon: 'i_bell', desc: '^y30%^w di probabilità di sparare una seconda raffica.', apply: (s, n) => s.echo = 0.3 },
  sun:      { name: 'Piccolo Sole', rar: 3, max: 1, icon: 'i_sun', desc: 'La tua luce ^obrucia^w i nemici che ti stanno vicino.', apply: (s, n) => s.sun = n },
};

// ---------------------------------------------------------------------
//  Reliquie (stanze del tesoro, boss, negozi, segreti)
// ---------------------------------------------------------------------
const RELICS = {
  r_stoneheart: { name: 'Cuore di Pietra', icon: 'i_heart', desc: '+^y30^w vita massima. ^r-5%^w velocità.', apply: s => { s.maxHp += 30; s.speedMult -= 0.05; }, onTake: () => healPlayer(30, true) },
  r_mirror:  { name: 'Specchio Incrinato', icon: 'i_mirror', desc: 'Scattando ^yrifletti^w i proiettili nemici vicini.', apply: s => s.dashReflect = 1 },
  r_crown:   { name: 'Corona dell\'Annegato', icon: 'i_crown', desc: '+^y40%^w monete. I mercanti fanno lo sconto del ^y25%^w.', apply: s => { s.coinMult += 0.4; s.priceMult *= 0.75; } },
  r_skull:   { name: 'Teschio Ridente', icon: 'i_skull', desc: '+^y35%^w danno. ^pMaledizione:^w Fragilità.', apply: s => s.dmgMult += 0.35, curse: 'c_frail' },
  r_lens:    { name: "Lente d'Ambra", icon: 'i_lens', desc: '+^y12%^w critico. I critici ^oincendiano^w.', apply: s => { s.crit += 0.12; s.critBurn = 1; } },
  r_wick:    { name: 'Stoppino Eterno', icon: 'i_lantern', desc: 'L\'olio non si consuma più col tempo.', apply: s => s.noOilDrain = 1 },
  r_bell:    { name: 'Campana Muta', icon: 'i_bell', desc: 'Entrando in una stanza i nemici restano ^ystorditi^w per 1.5 secondi.', apply: s => s.bellStun = 1.5 },
  r_hourglass:{ name: 'Clessidra Rotta', icon: 'i_hourglass', desc: '+^y25%^w cadenza, +^y12%^w velocità. ^pMaledizione:^w Fretta.', apply: s => { s.rateMult += 0.25; s.speedMult += 0.12; }, curse: 'c_haste' },
  r_tooth:   { name: 'Dente di Vampiro', icon: 'i_tooth', desc: 'Ogni colpo critico cura ^y1^w vita.', apply: s => s.critHeal = 1 },
  r_eye:     { name: 'Terzo Occhio', icon: 'i_eye', desc: 'Rivela la mappa e le stanze segrete. +^y10%^w luce.', apply: s => { s.mapReveal = 1; s.lightMult += 0.1; } },
  r_quiver:  { name: 'Faretra di Ossa', icon: 'i_quiver', desc: '+^y2^w proiettili. ^r-10%^w cadenza.', apply: s => { s.proj += 2; s.rateMult -= 0.1; } },
  r_anvil:   { name: 'Incudine', icon: 'i_anvil', desc: '+^y50%^w danno, proiettili più grossi. ^r-20%^w cadenza.', apply: s => { s.dmgMult += 0.5; s.rateMult -= 0.2; s.shotSize += 1; } },
  r_feather: { name: 'Piuma di Corvo', icon: 'i_wing', desc: '+^y1^w carica di scatto, scatto più lungo e rapido a ricaricarsi.', apply: s => { s.dashCharges += 1; s.dashDist += 0.3; s.dashCd *= 0.8; } },
  r_moth:    { name: 'Ali di Falena', icon: 'i_wing', desc: 'Immune a ^gveleno^w e ^slentezza^w. +^y10%^w velocità.', apply: s => { s.immune.poison = 1; s.immune.slow = 1; s.speedMult += 0.1; } },
  r_ember:   { name: 'Brace del Primo Fuoco', icon: 'i_flame', desc: '+^y1^w lucciola orbitante. La Vampata costa la metà.', apply: s => { s.orbit += 1; s.flareCost *= 0.5; } },
  r_key:     { name: 'Chiave dello Scheletro', icon: 'i_key', desc: '+^y3^w chiavi. I forzieri dorati sono più generosi.', apply: s => s.goldKeys = 1, onTake: p => { p.keys += 3; } },
  r_blood:   { name: 'Patto di Sangue', icon: 'i_cup', desc: '+^y60%^w danno sotto il 40% di vita. ^pMaledizione:^w Sangue Amaro.', apply: s => s.lowHpDmg = 0.6, curse: 'c_blood' },
  r_ice:     { name: 'Cuore di Brina', icon: 'i_ice', desc: 'Tutti i colpi ^craffreddano^w. Immune al gelo.', apply: s => { s.chillAll = 1; s.immune.chill = 1; } },
  r_storm:   { name: 'Bottiglia di Tempesta', icon: 'i_storm', desc: 'Ogni 3 secondi un ^bfulmine^w colpisce un nemico (250% danno).', apply: s => s.storm = 1 },
  r_shell:   { name: 'Guscio di Tartaruga', icon: 'i_shell', desc: '+^y4^w armatura. ^r-12%^w velocità.', apply: s => { s.armor += 4; s.speedMult -= 0.12; } },
  r_clover:  { name: 'Quadrifoglio Secco', icon: 'i_clover', desc: 'Doni più rari e una ^yquarta scelta^w a ogni livello.', apply: s => { s.extraChoice = 1; s.luck += 1; } },
  r_lamp:    { name: 'Lampada del Minatore', icon: 'i_lamp', desc: '+^y35%^w raggio di luce, +^y10%^w critico.', apply: s => { s.lightMult += 0.35; s.crit += 0.1; } },
  r_coffin:  { name: 'Chiodo di Bara', icon: 'i_coffin', desc: 'Alla morte ^yrinasci^w una volta con metà vita.', apply: s => s.revive = 1 },
  r_ash:     { name: 'Urna di Cenere', icon: 'i_urn', desc: 'I nemici uccisi lasciano ^ofiamme^w a terra.', apply: s => s.ashTrail = 1 },
  r_mask:    { name: 'Maschera del Giullare', icon: 'i_mask', desc: '+^y20%^w schivata. ^pMaledizione:^w Nebbia.', apply: s => s.dodge += 0.2, curse: 'c_fog' },
  r_gauntlet:{ name: 'Guanto del Fabbro', icon: 'i_hand', desc: '+^y20%^w danno, +^y2^w armatura, proiettili trapassano +^y1^w.', apply: s => { s.dmgMult += 0.2; s.armor += 2; s.pierce += 1; } },
};

// ---------------------------------------------------------------------
//  Maledizioni (malus permanenti per la run)
// ---------------------------------------------------------------------
const CURSES = {
  c_dark:  { name: 'Buio Pesto', desc: '^r-25%^w raggio di luce.', apply: s => s.lightMult -= 0.25 },
  c_frail: { name: 'Fragilità', desc: '^r+20%^w danni subiti.', apply: s => s.dmgTaken *= 1.2 },
  c_greed: { name: 'Avarizia', desc: 'Prezzi dei mercanti ^r+40%^w.', apply: s => s.priceMult *= 1.4 },
  c_haste: { name: 'Fretta', desc: 'I nemici sono più veloci del ^r12%^w.', apply: s => s.enemySpeed *= 1.12 },
  c_blood: { name: 'Sangue Amaro', desc: 'Le cure sono ^r40%^w meno efficaci.', apply: s => s.healMult -= 0.4 },
  c_fog:   { name: 'Nebbia', desc: 'La minimappa è nascosta.', apply: s => s.hideMap = 1 },
  c_weak:  { name: 'Debolezza', desc: '^r-12%^w danno.', apply: s => s.dmgMult -= 0.12 },
  c_rust:  { name: 'Ruggine', desc: '^r-1^w armatura e ^r-10%^w cadenza.', apply: s => { s.armor -= 1; s.rateMult -= 0.1; } },
};

// ---------------------------------------------------------------------
//  Stati alterati
// ---------------------------------------------------------------------
const STATUS = {
  burn:    { name: 'Bruciatura', icon: 's_burn', col: '#f29c38', bad: true },
  poison:  { name: 'Veleno', icon: 's_poison', col: '#8fd35a', bad: true },
  chill:   { name: 'Gelo', icon: 's_chill', col: '#7fd8e6', bad: true },
  slow:    { name: 'Lentezza', icon: 's_slow', col: '#b8b2c2', bad: true },
  weak:    { name: 'Debolezza', icon: 's_weak', col: '#e0574a', bad: true },
  fragile: { name: 'Fragilità', icon: 's_fragile', col: '#e0574a', bad: true },
  blind:   { name: 'Accecamento', icon: 's_blind', col: '#8a8294', bad: true },
  rage:    { name: 'Ira', icon: 's_rage', col: '#f29c38', bad: false },
  immune:  { name: 'Purezza', icon: 's_shield', col: '#7fd8e6', bad: false },
  invis:   { name: 'Invisibile', icon: 's_invis', col: '#b8b2c2', bad: false },
  fury:    { name: 'Frenesia', icon: 's_rage', col: '#f6cf57', bad: false },
};

// ---------------------------------------------------------------------
//  Consumabili (4 slot, si impilano fino a 3)
// ---------------------------------------------------------------------
const CONS = {
  potion:  { name: 'Pozione Rossa', spr: 'potion', w: 10, price: 14, desc: 'Cura ^y30^w vita.', use: p => { if (p.hp >= p.stats.maxHp) return false; healPlayer(30); return true; } },
  bigpotion:{ name: 'Elisir Vitale', spr: 'bigpotion', w: 2, price: 30, desc: 'Cura ^ytutta^w la vita.', use: p => { if (p.hp >= p.stats.maxHp) return false; healPlayer(999); return true; } },
  oil:     { name: "Fiaschetta d'Olio", spr: 'oilflask', w: 8, price: 10, desc: 'Ricarica ^y60^w olio.', use: p => { if (p.oil >= p.stats.maxOil) return false; addOil(60); Sound.play('oil'); return true; } },
  bomb:    { name: 'Bomba', spr: 'bomb', w: 9, price: 9, desc: 'Esplode dopo poco: ^y80^w danni ad area. Sfonda rocce incrinate e passaggi segreti.', use: p => { placeBomb(p.x, p.y + 3, 'player'); return true; } },
  antidote:{ name: 'Antidoto', spr: 'antidote', w: 6, price: 10, desc: 'Rimuove tutti i malus e ne protegge per ^y6^w secondi.', use: p => { cleanse(p); addStatus(p, 'immune', 6); Sound.play('heal'); return true; } },
  rage:    { name: 'Grappa del Minatore', spr: 'rage', w: 6, price: 12, desc: '+^y50%^w danno e cadenza per ^y10^w secondi.', use: p => { addStatus(p, 'rage', 10); Sound.play('flare', 0.5); return true; } },
  frost:   { name: 'Fiala di Gelo', spr: 'frost', w: 5, price: 14, desc: '^cCongela^w tutti i nemici della stanza per ^y3^w secondi.', use: p => { freezeAll(3); return true; } },
  map:     { name: 'Pergamena', spr: 'scroll', w: 4, price: 8, desc: 'Rivela la mappa della profondità, segreti inclusi.', use: p => { revealMap(); return true; } },
  firefly: { name: 'Barattolo di Lucciole', spr: 'jar', w: 5, price: 12, desc: '^y3^w lucciole ti proteggono per ^y25^w secondi.', use: p => { p.tempOrbitT = 25; p.tempOrbit = 3; Sound.play('pickup'); return true; } },
  dice:    { name: 'Dado Truccato', spr: 'dice', w: 3, price: 18, desc: 'Ottieni un dono casuale. ^r30%^w di ricevere anche una maledizione.', use: p => { rollDice(); return true; } },
  smoke:   { name: "Polvere d'Ombra", spr: 'pouch', w: 4, price: 10, desc: 'Diventi ^sinvisibile^w per ^y4^w secondi.', use: p => { addStatus(p, 'invis', 4); Particles.burst(p.x, p.y, 30, ['#4a4068', '#8a80b0', '#2a2440'], 60, 0.8); Sound.play('dash'); return true; } },
  holy:    { name: 'Acqua Santa', spr: 'holy', w: 2, price: 28, desc: 'Rimuove una ^pmaledizione^w. Senza maledizioni cura 30 vita.', use: p => { if (p.curses.length) { const c = p.curses.pop(); toast('Maledizione spezzata: ' + CURSES[c].name, '#c57ae0'); recalcStats(); Sound.play('heal'); } else { if (p.hp >= p.stats.maxHp) return false; healPlayer(30); } return true; } },
  feather: { name: 'Piuma di Fenice', spr: 'feather', w: 1.5, price: 35, desc: 'Passiva: se muori, ^yrinasci^w con metà vita (si consuma).', passive: true, use: p => false },
};

// ---------------------------------------------------------------------
//  Nemici
// ---------------------------------------------------------------------
const ENEMIES = {
  rat:      { name: 'Ratto di Cripta', spr: 'rat', hp: 14, spd: 74, dmg: 8, r: 5, ai: 'chaser', xp: 1, side: true, burst: true },
  bat:      { name: 'Pipistrello', spr: 'bat', hp: 10, spd: 62, dmg: 7, r: 5, ai: 'erratic', xp: 1, fly: true, anim: 10 },
  skeleton: { name: 'Scheletro', spr: 'skeleton', hp: 28, spd: 30, dmg: 10, r: 6, ai: 'shooter', xp: 2, shot: { kind: 'bone', spd: 110, cd: 2.4, n: 1 } },
  skull:    { name: 'Teschio Fatuo', spr: 'skull', hp: 24, spd: 26, dmg: 8, r: 6, ai: 'caster', xp: 3, fly: true, keep: 90, shot: { kind: 'orb', col: 'violet', spd: 68, cd: 3.2, ring: 6 } },
  ghoul:    { name: 'Ghoul', spr: 'ghoul', hp: 46, spd: 36, dmg: 12, r: 7, ai: 'charger', xp: 3, chargeSpd: 225 },
  grub:     { name: 'Larva', spr: 'grub', hp: 26, spd: 38, dmg: 9, r: 6, ai: 'chaser', xp: 2, side: true, split: 'grubling', splitN: 2 },
  grubling: { name: 'Larvetta', spr: 'grubling', hp: 9, spd: 66, dmg: 6, r: 4, ai: 'chaser', xp: 0.5, side: true },
  spore:    { name: 'Sporangio', spr: 'spore', hp: 42, spd: 0, dmg: 8, r: 7, ai: 'turret', xp: 3, shot: { kind: 'spore', spd: 52, cd: 2.8, ring: 8, status: 'poison' }, deathCloud: true },
  hopper:   { name: 'Fungo Saltatore', spr: 'hopper', hp: 34, spd: 0, dmg: 10, r: 6, ai: 'hopper', xp: 3, hopCd: 1.7, landRing: 6 },
  moth:     { name: 'Falena Pallida', spr: 'moth', hp: 18, spd: 48, dmg: 7, r: 6, ai: 'erratic', fly: true, xp: 2, anim: 12, shot: { kind: 'dust', spd: 90, cd: 2.4, n: 3, spread: 0.35, status: 'slow' } },
  automaton:{ name: 'Automa', spr: 'automaton', hp: 52, spd: 42, dmg: 13, r: 6, ai: 'charger', xp: 3, chargeSpd: 270 },
  turret:   { name: 'Torretta', spr: 'turret', hp: 48, spd: 0, dmg: 10, r: 7, ai: 'turret', xp: 3, shot: { kind: 'orb', col: 'red', spd: 125, cd: 2.2, n: 1, burst: 3, aimed: true } },
  slag:     { name: 'Scoria Fusa', spr: 'slag', hp: 38, spd: 30, dmg: 11, r: 6, ai: 'chaser', xp: 3, trail: true },
  smith:    { name: 'Fabbro Corrotto', spr: 'smith', hp: 95, spd: 26, dmg: 15, r: 7, ai: 'shielder', xp: 5, shield: true },
  spark:    { name: 'Scintilla', spr: 'spark', hp: 12, spd: 92, dmg: 14, r: 4, ai: 'kamikaze', fly: true, xp: 1, anim: 14 },
  drowned:  { name: 'Annegato', spr: 'drowned', hp: 52, spd: 42, dmg: 12, r: 6, ai: 'phaser', fly: true, xp: 4, touch: 'chill' },
  eel:      { name: 'Anguilla', spr: 'eel', hp: 42, spd: 0, dmg: 13, r: 6, ai: 'dasher', xp: 3, side: true },
  jelly:    { name: 'Medusa', spr: 'jelly', hp: 46, spd: 22, dmg: 10, r: 6, ai: 'caster', fly: true, keep: 100, xp: 4, shot: { kind: 'orb', col: 'cyan', spd: 52, cd: 3.0, ring: 10, status: 'chill' } },
  shade:    { name: 'Ombra', spr: 'shade', hp: 36, spd: 0, dmg: 11, r: 6, ai: 'teleporter', xp: 4, shot: { kind: 'orb', col: 'violet', spd: 115, n: 5, spread: 0.5, status: 'weak' } },
  cultist:  { name: 'Cultista', spr: 'cultist', hp: 62, spd: 30, dmg: 11, r: 6, ai: 'summoner', xp: 5, keep: 110, summon: 'wisp', shot: { kind: 'orb', col: 'red', spd: 100, cd: 2.8, n: 3, spread: 0.3 } },
  wisp:     { name: 'Fiammella Nera', spr: 'wisp', hp: 10, spd: 88, dmg: 12, r: 4, ai: 'kamikaze', fly: true, xp: 0.5 },
  knight:   { name: 'Cavaliere Cavo', spr: 'knight', hp: 150, spd: 34, dmg: 18, r: 7, ai: 'shielder', shield: true, xp: 7, slam: true },
  eye:      { name: 'Occhio del Pozzo', spr: 'eye', hp: 78, spd: 16, dmg: 10, r: 7, ai: 'spinner', fly: true, xp: 6, shot: { kind: 'orb', col: 'red', spd: 82, cd: 0.17, arms: 3, status: 'fragile' } },
};

const ELITE_MODS = {
  armored:  { name: 'Corazzato', col: '#a59fb0' },
  swift:    { name: 'Rapido', col: '#f6cf57' },
  vampiric: { name: 'Vampirico', col: '#e0574a' },
  volatile: { name: 'Instabile', col: '#f29c38' },
  regen:    { name: 'Rigenerante', col: '#8fd35a' },
  splitter: { name: 'Scisso', col: '#c57ae0' },
  venom:    { name: 'Velenoso', col: '#6fc04a' },
};

// ---------------------------------------------------------------------
//  Boss
// ---------------------------------------------------------------------
const BOSSES = {
  bones: {
    name: 'Il Custode delle Ossa', title: 'Re delle Cripte Dimenticate', spr: 'boss_bones', hp: 800, r: 11, spd: 34,
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
    name: 'Madre Micelio', title: 'Cuore Marcio delle Fungaie', spr: 'boss_mycel', hp: 1350, r: 13, spd: 16,
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
    name: 'Il Forgiatore', title: 'Martello della Fonderia Sommersa', spr: 'boss_forge', hp: 2000, r: 13, spd: 42,
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
    name: "La Voce dell'Abisso", title: 'Sacerdotessa delle Acque Nere', spr: 'boss_abyss', hp: 2800, r: 12, spd: 0,
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
    name: 'Il Divoratore di Luce', title: 'Colui che ha spento il sole', spr: 'boss_devourer', hp: 4600, r: 15, spd: 22,
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
//  Biomi (profondita')
// ---------------------------------------------------------------------
const BIOMES = [
  {
    id: 'crypt', name: 'Le Cripte', music: 'crypt', boss: 'bones', dark: 0.68,
    lore: 'Sotto la città spenta riposano i primi custodi. Le loro ossa non hanno dimenticato come si combatte.',
    floor: ['#2a2430', '#241f2a', '#2e2834'], floorD: '#1a1520', wall: '#3c3448', wallD: '#231c2a', wallL: '#544a62', accent: '#6b5a80',
    pool: [['rat', 1, 3], ['bat', 1, 3], ['skeleton', 2, 3], ['skull', 3, 2], ['ghoul', 3, 1.5]], deco: 'bones', urns: true
  },
  {
    id: 'fungus', name: 'Le Fungaie', music: 'fungus', boss: 'mycel', dark: 0.72,
    lore: 'Il buio qui respira. Le spore cercano carne calda e non smettono mai di crescere.',
    floor: ['#1f2a22', '#1b251e', '#243026'], floorD: '#141c16', wall: '#2f3e30', wallD: '#1c261d', wallL: '#46604a', accent: '#a33a7a',
    pool: [['grub', 2, 3], ['spore', 2.5, 2], ['hopper', 3, 2], ['moth', 2, 2.5], ['rat', 1, 1], ['bat', 1, 1], ['skeleton', 2, 1]], deco: 'shrooms'
  },
  {
    id: 'forge', name: 'La Fonderia Sommersa', music: 'forge', boss: 'forge', dark: 0.75,
    lore: "Qui si forgiavano le lanterne. Ora le fornaci ardono per un padrone diverso.",
    floor: ['#2c2220', '#26201e', '#32261f'], floorD: '#1a1412', wall: '#463026', wallD: '#2a1c16', wallL: '#6a4a36', accent: '#f29c38',
    pool: [['automaton', 3, 2.5], ['turret', 3, 2], ['slag', 2.5, 2.5], ['smith', 4, 1.2], ['spark', 1.5, 2.5], ['ghoul', 3, 1], ['moth', 2, 1]], deco: 'cracks', barrels: true
  },
  {
    id: 'abyss', name: "L'Abisso Allagato", music: 'abyss', boss: 'abyss', dark: 0.8,
    lore: "L'acqua nera ha inghiottito le preghiere. Qualcosa, laggiù, canta ancora.",
    floor: ['#18242c', '#152028', '#1c2a32'], floorD: '#0e161c', wall: '#22343e', wallD: '#121e24', wallL: '#355260', accent: '#5aa0aa',
    pool: [['drowned', 3, 2.5], ['eel', 3, 2.5], ['jelly', 3.5, 2], ['shade', 3.5, 2], ['spark', 1.5, 1], ['smith', 4, 0.8], ['skull', 3, 1]], deco: 'puddles'
  },
  {
    id: 'heart', name: 'Il Cuore del Pozzo', music: 'heart', boss: 'devourer', dark: 0.85,
    lore: "Qui la Fiamma Prima fu divorata. Solo l'ultima lanterna può riaccenderla.",
    floor: ['#221824', '#1d141f', '#281c2a'], floorD: '#130c15', wall: '#382238', wallD: '#20121f', wallL: '#56345a', accent: '#c57ae0',
    pool: [['cultist', 4, 2], ['knight', 5, 1.2], ['eye', 4.5, 1.5], ['drowned', 3, 1.5], ['shade', 3.5, 1.5], ['automaton', 3, 1.5], ['hopper', 3, 1], ['jelly', 3.5, 1], ['ghoul', 3, 1]], deco: 'veins'
  },
];

// ---------------------------------------------------------------------
//  Lanterne (personaggi iniziali)
// ---------------------------------------------------------------------
const LANTERNS = [
  {
    id: 'custode', name: 'Lanterna del Custode', glass: '#f6cf57',
    desc: 'Equilibrata e affidabile. Parti con una ^yPozione Rossa^w e una ^yBomba^w.',
    unlock: () => true, unlockText: '',
    apply: s => { }, start: p => { giveCons('potion'); giveCons('bomb'); }
  },
  {
    id: 'pellegrino', name: 'Lanterna del Pellegrino', glass: '#8fd35a',
    desc: '+^y25^w vita, +^y2^w armatura, ^r-8%^w velocità e cadenza. Parti con due ^yBombe^w e una ^yPozione^w.',
    unlock: st => st.bossKills >= 1, unlockText: 'Sconfiggi un guardiano di profondità.',
    apply: s => { s.maxHp += 25; s.armor += 2; s.speedMult -= 0.08; s.rateMult -= 0.08; },
    start: p => { giveCons('bomb'); giveCons('bomb'); giveCons('potion'); }
  },
  {
    id: 'spezzata', name: 'Lanterna Spezzata', glass: '#e0574a',
    desc: '+^y35%^w danno, +^y10%^w critico, ^r-35%^w vita massima. Parti con il dono ^oTizzone^w.',
    unlock: st => st.bestDepth >= 3, unlockText: 'Raggiungi la terza profondità.',
    apply: s => { s.dmgMult += 0.35; s.crit += 0.1; s.maxHp = Math.round(s.maxHp * 0.65); },
    start: p => { p.perks.burn = 1; }
  },
  {
    id: 'cava', name: 'Lanterna Cava', glass: '#7fd8e6',
    desc: '+^y50^w olio, Vampata ^y-40%^w costo, +^y25%^w luce, +^y1^w scatto. ^r-10%^w danno.',
    unlock: st => st.bestDepth >= 4, unlockText: 'Raggiungi la quarta profondità.',
    apply: s => { s.maxOil += 50; s.flareCost *= 0.6; s.lightMult += 0.25; s.dashCharges += 1; s.dmgMult -= 0.1; },
    start: p => { giveCons('oil'); }
  },
  {
    id: 'nera', name: 'Lanterna Nera', glass: '#c57ae0',
    desc: 'Parti con ^ydue reliquie^w casuali e ^pdue maledizioni^w. Per chi non teme il buio.',
    unlock: st => st.wins >= 1, unlockText: 'Riaccendi la Fiamma Prima almeno una volta.',
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

const ARDORE = [
  'Il viaggio come fu tramandato.',
  'Nemici: +^r25%^w vita.',
  'In più: nemici +^r20%^w danno.',
  'In più: i campioni d\'élite sono il doppio.',
  'In più: cure ^r-30%^w, meno cuori a terra.',
  'In più: boss più rapidi e l\'olio brucia ^r50%^w più in fretta.',
];

// battute del mercante
const MERCHANT_LINES = [
  'Luce in cambio di monete, viandante.',
  'Non chiedere da dove vengono. Paga e basta.',
  'Ogni lanterna che scende... io la vedo risalire di rado.',
  'Questi prezzi? Il buio costa caro a tutti.',
  'Hai l\'aria di chi ha bisogno di una pozione.',
];
