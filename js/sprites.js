'use strict';
// =====================================================================
//  Sprite pixel-art (disegnati come stringhe; "sym" = meta' sinistra
//  specchiata). L'outline scuro viene aggiunto in automatico.
// =====================================================================

function buildSprites() {
  // ------------------------------------------------------------ giocatore
  defSprite('player', {
    sym: true, frames: [[
      '....aa', '...aAA', '..aAhA', '..aAAA', '..aKKK', '..aKyK', '..aKKK',
      '.aAAAa', 'aAhAAA', 'aAhAAA', 'aAAhAA', '.aAAAA', '..aAAA', '..mm..'
    ], [
      '....aa', '...aAA', '..aAhA', '..aAAA', '..aKKK', '..aKyK', '..aKKK',
      '.aAAAa', 'aAhAAA', 'aAhAAA', 'aAAhAA', '.aAAAA', '..aAA.', '.mm...'
    ]]
  });

  // ------------------------------------------------------------ cripte
  const ratPal = { G: '#6e5a4e', g: '#4a3a32', s: '#d48f8f', p: '#e0a0a0', r: '#a06868' };
  defSprite('rat', {
    pal: ratPal, frames: [[
      '.......ss...', '....GGGGGG..', '..GGGGGGGkG.', 'rrGGGgGGGGGp', '...GG...GG..'
    ], [
      '.......ss...', '....GGGGGG..', '..GGGGGGGkG.', 'rrGGGgGGGGGp', '..GG.....GG.'
    ]]
  });
  defSprite('bat', {
    sym: true, pal: { v: '#3a2246', V: '#6a3a80', y: '#ff6a5a' }, frames: [[
      'v......', 'vv....v', 'vVv..vV', '.vVvvVV', '..vVVVy', '...vvVV', '.....vV', '......v'
    ], [
      '.......', '......v', '.....vV', '..vvvVV', '.vVVVVy', 'vVv.vVV', 'vv...vV', 'v.....v'
    ]]
  });
  defSprite('skeleton', {
    sym: true, frames: [[
      '...ww', '..www', '..wkw', '..www', '...kw', '....w', '.wwww', 'w..kw', 'w.www', '...kw', '...ww', '..w.w', '..w..', '.ww..'
    ], [
      '...ww', '..www', '..wkw', '..www', '...kw', '....w', '.wwww', 'w..kw', 'w.www', '...kw', '...ww', '...ww', '...w.', '..ww.'
    ]]
  });
  defSprite('skull', {
    sym: true, pal: { p: '#c57ae0', V: '#8a4fb0' }, frames: [[
      '...p.', '..pVp', '..www', '.wwww', '.wkkw', '.wkpw', '.wwww', '..wkw', '..www', '..w.w'
    ], [
      '..p..', '...Vp', '..www', '.wwww', '.wkkw', '.wkpw', '.wwww', '..wkw', '..www', '..w.w'
    ]]
  });
  const ghoulPal = { E: '#5d7a5a', e: '#34482f', R: '#e04a3a' };
  defSprite('ghoul', {
    sym: true, pal: ghoulPal, frames: [[
      '....ee', '...eEE', '..eEEE', '..eRkE', '..eEEE', '..ekwk', '.eeEEE', 'eEEeEE', 'eE.eEE', 'eE.eEE', '...eEE', '...ee.', '..ee..', '.ee...'
    ], [
      '....ee', '...eEE', '..eEEE', '..eRkE', '..eEEE', '..ekwk', '.eeEEE', 'eEEeEE', 'eE.eEE', '.E.eEE', '...eEE', '...eE.', '...ee.', '..ee..'
    ]]
  });

  // ------------------------------------------------------------ fungaie
  const grubPal = { t: '#c9b28a', Y: '#e9dcb0' };
  defSprite('grub', {
    pal: grubPal, frames: [[
      '..tttttt....', '.tYtYtYtt...', 'tYtYtYtYttt.', 'tttttttttkkt', '.t.t.t.tttt.'
    ], [
      '...tttttt...', '..tYtYtYtt..', '.tYtYtYtYtt.', 'tttttttttkkt', 't.t.t.t.ttt.'
    ]]
  });
  defSprite('grubling', {
    pal: grubPal, frames: [[
      '.tttt...', 'tYtYtt..', 'tttttkkt', '.t.t.tt.'
    ], [
      '..tttt..', '.tYtYtt.', 'tttttkkt', 't.t.ttt.'
    ]]
  });
  defSprite('spore', {
    sym: true, pal: { q: '#5c1f4a', Q: '#a33a7a', p: '#e88fc0', e: '#2e4a2a', E: '#4f8a3a' }, frames: [[
      '....qq', '..qqQQ', '.qQpQQ', '.qQQQp', 'qQpQQQ', 'qQQQQp', 'qQQQQQ', '.qQQQQ', '..qqqq', '....ee', '...eEE', '..eeEE'
    ], [
      '......', '...qqQ', '.qqQpQ', '.qQQQp', 'qQpQQQ', 'qQQQQp', 'qQQQQQ', '.qQQQQ', '..qqqq', '....ee', '...eEE', '..eeEE'
    ]]
  });
  defSprite('hopper', {
    sym: true, pal: { r: '#7e2530', R: '#c8443a' }, frames: [[
      '...rrr', '.rrRRR', 'rRRwRR', 'rRwwRR', 'rRRRRR', '.rrrrr', '...www', '...kww', '...www', '...www', '..ww.w', '..t...'
    ], [
      '......', '...rrr', '.rrRRR', 'rRRwRR', 'rRwwRR', 'rRRRRR', '.rrrrr', '...www', '...kww', '...www', '..wwww', '.tt...'
    ]]
  });
  defSprite('moth', {
    sym: true, pal: { s: '#b8b0a0', w: '#e6e0cc', Y: '#f6cf57', n: '#5a3a24', N: '#8a5a34' }, frames: [[
      '.....k.', '......k', 'ss...nN', 'sws..nN', 'swYs.nN', 'swws.nN', '.sws.nN', '..ss.nN', '.....nn'
    ], [
      '.....k.', '......k', '.....nN', '.ss..nN', 'swYs.nN', 'swws.nN', '.sws.nN', '.....nN', '.....nn'
    ]]
  });

  // ------------------------------------------------------------ fonderia
  defSprite('automaton', {
    sym: true, frames: [[
      '...uuu', '..uUUU', '..uOOO', '..uUUU', '...gg.', '.uuUUU', 'uUUuUU', 'uU.uUU', 'gg.uUU', '...uUU', '...gg.', '..gG..', '..gG..', '.uu...'
    ], [
      '...uuu', '..uUUU', '..uOOO', '..uUUU', '...gg.', '.uuUUU', 'uUUuUU', 'uU.uUU', 'gg.uUU', '...uUU', '...gg.', '...gG.', '...gG.', '..uu..'
    ]]
  });
  defSprite('turret', {
    sym: true, frames: [[
      '...ggg', '..gGGG', '.gGGkk', '.gGkRR', '.gGkRY', '.gGGkk', '..gGGG', 'gggggg', 'gGGGGG', 'gGsGsG', 'gGGGGG', 'gggggg'
    ], [
      '...ggg', '..gGGG', '.gGGkk', '.gGkRR', '.gGkRR', '.gGGkk', '..gGGG', 'gggggg', 'gGGGGG', 'gGsGsG', 'gGGGGG', 'gggggg'
    ]]
  });
  defSprite('slag', {
    sym: true, frames: [[
      '....oo', '..oOOO', '.oOYOO', '.oOOYO', 'oOkOOO', 'oOOOOO', 'oOOOYO', '.ooOOO', '..oooo'
    ], [
      '......', '...ooo', '.ooOOO', '.oOYOO', 'oOkOYO', 'oOOOOO', 'oOOOYO', 'oooOOO', '.ooooo'
    ]]
  });
  defSprite('smith', {
    sym: true, frames: [[
      '.....gg', '....gGG', '...gGGG', '...gkRk', '...gGGG', '..nnNNN', '.nNNNNN', 'nNNnNNN', 'nN.nNNN', 'nN.nNNN', '...nNNN', '...nNNN', '...nn.n', '..mm..m'
    ], [
      '.....gg', '....gGG', '...gGGG', '...gkRk', '...gGGG', '..nnNNN', '.nNNNNN', 'nNNnNNN', 'nN.nNNN', '.N.nNNN', '...nNNN', '...nNNN', '....n.n', '...mm.m'
    ]]
  });
  defSprite('spark', {
    pal: {}, frames: [[
      '...yy...', '..yOOy..', '.yOYYOy.', 'yOYWWYOy', 'yOYWWYOy', '.yOYYOy.', '..yOOy..', '...yy...'
    ], [
      '........', '...yy...', '..yOOy..', '.yOWWOy.', '.yOWWOy.', '..yOOy..', '...yy...', '........'
    ]]
  });

  // ------------------------------------------------------------ abisso
  defSprite('drowned', {
    sym: true, pal: { c: '#5aa0aa', C: '#9ad8dc', b: '#1e3a44' }, frames: [[
      '....cc', '...cCC', '..cCCC', '..cbkb', '..cCCC', '..cCbC', '.cCCCC', 'cCcCCC', 'cC.cCC', 'c..cCC', '...cCC', '..cCcC', '..c.c.', '.c..c.'
    ], [
      '....cc', '...cCC', '..cCCC', '..cbkb', '..cCCC', '..cCbC', '.cCCCC', 'cCcCCC', 'cC.cCC', '...cCC', '...cCC', '...cCc', '...c.c', '..c..c'
    ]]
  });
  defSprite('eel', {
    pal: { i: '#1e4a52', I: '#3f8a8e', c: '#9ad8dc', R: '#ff6a5a' }, frames: [[
      '...iiiIIIIii....', '.iIIIcIIIIIIIi..', 'iIIIIIIIIIIIIIRk', '.iiIIIIIIIIIIi..', '...iiii..iii....'
    ], [
      '....iiIIIIiii...', 'iiIIIIcIIIIIIi..', '.iIIIIIIIIIIIIRk', 'iiIIIIIIIIIIIi..', '....iii..iiii...'
    ]]
  });
  defSprite('jelly', {
    sym: true, pal: { b: '#2b4a87', B: '#5f8ad8', c: '#9fd8f0', C: '#e0f6ff' }, frames: [[
      '...bbb', '..bBBB', '.bBcBB', '.bBBcC', 'bBBBBB', 'bBkBBB', 'bbbbbb', '.c.c.c', 'c.c.c.', '.c.c.c', 'c...c.'
    ], [
      '...bbb', '..bBBB', '.bBcBB', '.bBBcC', 'bBBBBB', 'bBkBBB', 'bbbbbb', 'c.c.c.', '.c.c.c', 'c.c.c.', '.c...c'
    ]]
  });
  defSprite('shade', {
    sym: true, pal: { K: '#231830', k: '#120a18', p: '#d08aff' }, frames: [[
      '....kk', '...kKK', '..kKKK', '..kKpK', '..kKKK', '.kKKKK', 'kKKkKK', 'kK.kKK', '...kKK', '...kKK', '..kKkK', '..k.kK', '.k..k.', 'k...k.'
    ], [
      '....kk', '...kKK', '..kKKK', '..kKpK', '..kKKK', '.kKKKK', 'kKKkKK', '.K.kKK', '...kKK', '...kKK', '...kKk', '...k.k', '..k..k', '.k...k'
    ]]
  });

  // ------------------------------------------------------------ cuore del pozzo
  defSprite('cultist', {
    sym: true, pal: { r: '#5c1f2a', R: '#9a2f3a' }, frames: [[
      '....rr', '...rRR', '..rRRR', '..rkkk', '..rkyk', '..rkkk', '.rrRRR', 'rRRrRR', 'rRwrRR', 'rR.rRR', '...rRR', '..rRRR', '..rRRR', '.rRRRR', '.rrrrr'
    ], [
      '....rr', '...rRR', '..rRRR', '..rkkk', '..rkyk', '..rkkk', '.rrRRR', 'rRRrRR', 'wRRrRR', '.R.rRR', '...rRR', '..rRRR', '..rRRR', '.rRRRR', '..rrrr'
    ]]
  });
  defSprite('wisp', {
    sym: true, pal: { v: '#3a1848', V: '#7a3a9a', p: '#e0a0ff' }, frames: [[
      '...v', '..vV', '.vVV', '.VpV', 'vVpp', 'vVVp', '.vVV', '..vv'
    ], [
      '....', '...v', '.vvV', '.VVV', 'vVpp', 'vVpp', '.vVV', '..vv'
    ]]
  });
  defSprite('knight', {
    sym: true, frames: [[
      '.....ss', '....sxx', '...sxxx', '...skkk', '...skRk', '...sxxx', '.zzsxxx', 'zxxzxxx', 'zx.zxxx', 'zx.zxxx', '...zxxx', '...zxxx', '...zx.z', '..zz..z'
    ], [
      '.....ss', '....sxx', '...sxxx', '...skkk', '...skRk', '...sxxx', '.zzsxxx', 'zxxzxxx', 'zx.zxxx', '.x.zxxx', '...zxxx', '...zxxx', '....x.z', '...zz.z'
    ]]
  });
  defSprite('eye', {
    sym: true, pal: { v: '#4a1a5a', V: '#8a3aa0', c: '#e0574a', b: '#7e2530' }, frames: [[
      '.....vv', '...vvVV', '..vVVww', '.vVwwww', '.vVwwcc', 'vVwwcbb', 'vVwwcbk', 'vVwwcbk', 'vVwwcbb', '.vVwwcc', '.vVwwww', '..vVVww', '...vvVV', '.....vv'
    ], [
      '.....vv', '...vvVV', '..vVVVV', '.vVVwww', '.vVwwcc', 'vVwwcbb', 'vVwwcbk', 'vVwwcbk', 'vVwwcbb', '.vVwwcc', '.vVVwww', '..vVVVV', '...vvVV', '.....vv'
    ]]
  });

  // ------------------------------------------------------------ boss
  defSprite('boss_bones', {
    sym: true, pal: { v: '#2a1838', V: '#4b2a5c' }, frames: [[
      '..........y.', '......y..yy.', '........yyyy', '.......wwwww', '......wwwwww', '......wkkkww', '......wkRkww', '......wkkkww',
      '......wwwwkw', '.......wwwww', '.......wkwkw', '........wwww', '....vvvvvwww', '..vvVVVVvwww', '.vVVVVVVvwkw', 'vVVwwVVVvwww',
      'vVVwwVVVvwkw', 'vVV..VVVvwww', 'vVV..VVVVvvv', '.vV..VVVVVVV', '....vVVVVVVV', '....vVVVVVVV', '...vVVVVVVVV', '...vvvvvvvvv'
    ], [
      '..........y.', '......y..yy.', '........yyyy', '.......wwwww', '......wwwwww', '......wkkkww', '......wkRkww', '......wkkkww',
      '......wwwwkw', '.......wwwww', '.......wkwkw', '........wwww', '....vvvvvwww', '..vvVVVVvwww', '.vVVVVVVvwkw', 'vVVwwVVVvwww',
      'vVVwwVVVvwkw', 'vVV..VVVvwww', 'vVV..VVVVvvv', '.vV..VVVVVVV', '....vVVVVVVV', '...vVVVVVVVV', '...vVVVVVVVV', '..vvvvvvvvvv'
    ]]
  });
  defSprite('boss_mycel', {
    sym: true, pal: { q: '#5c1f4a', Q: '#a33a7a', p: '#e88fc0', t: '#b8a27a', w: '#e6dcc0', e: '#2e4a2a', E: '#4f8a3a', k: '#2a0d1e' }, frames: [[
      '.........qqqq', '......qqqQQQQ', '....qqQQQQpQQ', '...qQQpQQQQQQ', '..qQQQQQQQpQQ', '.qQQpQQQQQQQQ', '.qQQQQQQQpQQQ',
      'qQQQQQQQQQQQQ', 'qqqqqqqqqqqqq', '.....twwwwwww', '.....twkkwwww', '.....twkpwwww', '.....twwwwwww', '.....twwwkkkk',
      '.....twwkwkwk', '......twwwwww', '.....ttwwwwww', '...eetttwwwww', '.eeEEttwwwwww', 'eEE.eEEttwwww', 'e..eEE.eEEttt', '..eE..eE..eEe'
    ], [
      '.........qqqq', '......qqqQQQQ', '....qqQQQQpQQ', '...qQQpQQQQQQ', '..qQQQQQQQpQQ', '.qQQpQQQQQQQQ', '.qQQQQQQQpQQQ',
      'qQQQQQQQQQQQQ', 'qqqqqqqqqqqqq', '.....twwwwwww', '.....twkkwwww', '.....twkpwwww', '.....twwwwwww', '.....twwwkkkk',
      '.....twwkkkkk', '......twwwkwk', '.....ttwwwwww', '...eetttwwwww', '.eeEEttwwwwww', 'eE..eEEttwwww', '.e.eEE.eEEttt', 'e..E..eE..eEe'
    ]]
  });
  defSprite('boss_forge', {
    sym: true, frames: [[
      '..........gg.', '.........gGGg', '........gGGGG', '........gkkkk', '........gkOOO', '........gGGGG', '.....uuuuGGGG',
      '...uuUUUUuuuu', '..uUUUUUUUUUU', '.uUUUuUUkkkkk', '.uUUUuUUkoOOO', '.uUUuuUUkOyyy', 'uUUu.uUUkOyYY', 'uUUu.uUUkoOOO',
      'uUUu.uUUkkkkk', 'ggg..uUUUUUUU', 'GGg..uUUUUUUU', '.....uuUUUUUU', '......gGGg...', '......gGGg...', '.....gGGGg...', '.....ggggg...'
    ], [
      '..........gg.', '.........gGGg', '........gGGGG', '........gkkkk', '........gkOOO', '........gGGGG', '.....uuuuGGGG',
      '...uuUUUUuuuu', '..uUUUUUUUUUU', '.uUUUuUUkkkkk', '.uUUUuUUkoOOO', '.uUUuuUUkOyYY', 'uUUu.uUUkOYWW', 'uUUu.uUUkoOOO',
      'uUUu.uUUkkkkk', 'ggg..uUUUUUUU', 'GGg..uUUUUUUU', '.....uuUUUUUU', '......gGGg...', '......gGGg...', '.....gGGGg...', '.....ggggg...'
    ]]
  });
  defSprite('boss_abyss', {
    sym: true, pal: { i: '#16343c', I: '#2f6a70', c: '#5aa0aa', C: '#9ad8dc', b: '#0e2026', W: '#e0ffff' }, frames: [[
      '..........iii', '........iiIII', '.......iIIIII', '.......iIcccc', '.......iIcCCC', '.......iIckWk', '.......iIcCCC',
      '.......iIccCC', '......iiIIcCC', '....iiIIIIIcc', '..iiIIIIIIIIc', '.iIIbIIIIIIIc', 'iIIbbIIIIIIIi', 'iIb.iIIIIIIIi',
      'ib..iIIIIIIIi', '....iIIbIIIbI', '....iIbIIIbIb', '...iIb.iIb.iI', '...ib..ib..ib', '..ib..ib..ib.', '..b...b...b..'
    ], [
      '..........iii', '........iiIII', '.......iIIIII', '.......iIcccc', '.......iIcCCC', '.......iIckWk', '.......iIcCCC',
      '.......iIccCC', '......iiIIcCC', '....iiIIIIIcc', '..iiIIIIIIIIc', '.iIIbIIIIIIIc', 'iIIbbIIIIIIIi', 'iIb.iIIIIIIIi',
      'ib..iIIIIIIIi', '....iIIbIIIbI', '....iIbIIIbIb', '....iIbiIbiIb', '....ib.ib.ib.', '...ib.ib.ib..', '...b..b..b...'
    ]]
  });
  defSprite('boss_devourer', {
    sym: true, pal: { K: '#2a1838', k: '#140a1c', v: '#5a2a6a', V: '#a24ab8', y: '#f6cf57', W: '#f2ead8', O: '#f29c38', Y: '#fff2a8' }, frames: [[
      '..........kkkkkk', '.......kkkKKKKKK', '.....kkKKKKKKKKK', '....kKKKvKKKKKKK', '...kKKvVvKKKKyKK', '..kKKKvVvKKKKKKK',
      '..kKKKKvKKKKKKKK', '.kKKKKKKKKKyKKKK', '.kKKyKKKKKKKKKkk', 'kKKKKKKKKKKKkkWW', 'kKKKKKKKKKkkWkkk', 'kKKKKKKKKkkkkkkk',
      'kKKKKKKKkkkkkOOO', 'kKKKKKKKkkkkOyYY', 'kKKKKKKKkkkkOyYW', 'kKKKKKKKkkkkOyYY', 'kKKKKKKKkkkkkOOO', 'kKKKKKKKKkkkkkkk',
      'kKKKKKKKKKkkWkkk', 'kKKKKKKKKKKKkkWW', '.kKKyKKKKKKKKKkk', '.kKKKKKKKKKKKKKK', '..kKKKKKKKyKKKKK', '..kKKKvKKKKKKKKK',
      '...kKvVvKKKKKKKK', '....kKvKKKKKKKKK', '.....kkKKKKKKKKK', '.......kkkKKKKKK', '..........kkkkkk'
    ], [
      '..........kkkkkk', '.......kkkKKKKKK', '.....kkKKKKKKKKK', '....kKKKvKKKKKKK', '...kKKvVvKKKKkKK', '..kKKKvVvKKKKKKK',
      '..kKKKKvKKKKKKKK', '.kKKKKKKKKKyKKKK', '.kKKkKKKKKKKKKkk', 'kKKKKKKKKKKKkkWW', 'kKKKKKKKKKkkWkkk', 'kKKKKKKKKkkkkkkk',
      'kKKKKKKKkkkkkOOO', 'kKKKKKKKkkkkOyYY', 'kKKKKKKKkkkkOYWW', 'kKKKKKKKkkkkOyYY', 'kKKKKKKKkkkkkOOO', 'kKKKKKKKKkkkkkkk',
      'kKKKKKKKKKkkWkkk', 'kKKKKKKKKKKKkkWW', '.kKKyKKKKKKKKKkk', '.kKKKKKKKKKKKKKK', '..kKKKKKKKkKKKKK', '..kKKKvKKKKKKKKK',
      '...kKvVvKKKKKKKK', '....kKvKKKKKKKKK', '.....kkKKKKKKKKK', '.......kkkKKKKKK', '..........kkkkkk'
    ]]
  });

  // ------------------------------------------------------------ raccoglibili
  defSprite('coin', { frames: [['.yyy.', 'yYYyo', 'yYyyo', 'yYyyo', 'yyyyo', '.ooo.'], ['..y..', '.yYo.', '.yyo.', '.yyo.', '.yyo.', '..o..']] });
  defSprite('coin5', { pal: { y: '#c8d0dc', Y: '#ffffff', o: '#6a7484' }, frames: [['.yyy.', 'yYYyo', 'yYyyo', 'yYyyo', 'yyyyo', '.ooo.'], ['..y..', '.yYo.', '.yyo.', '.yyo.', '.yyo.', '..o..']] });
  defSprite('heart', { sym: true, frames: [['.RR.', 'RWRR', 'RRRR', '.RRR', '..RR', '...R']] });
  defSprite('halfheart', { sym: true, pal: { R: '#e07a8a' }, frames: [['.RR.', 'RWRR', '.RRR', '..RR']] });
  defSprite('oil', { sym: true, frames: [['..o', '..O', '.oO', 'oOY', 'oOO', 'ooO', '.oo']] });
  defSprite('key', { frames: [['.yyy.....', 'yo.oyyyyy', 'yo.oy.y.y', '.yyy.....']] });
  const chestRowsClosed = [
    '.nnnnnnnnnnnn.', 'nNNNNNNNNNNNNn', 'nNtNNNNNNNNtNn', 'nNNNNNNNNNNNNn', 'uuuuuuyyuuuuuu', 'nNNNNNykyNNNNn',
    'nNNNNNyyyNNNNn', 'nNtNNNNNNNNtNn', 'nNNNNNNNNNNNNn', '.nnnnnnnnnnnn.'
  ];
  const chestRowsOpen = [
    '.nnnnnnnnnnnn.', 'nNNNNNNNNNNNNn', 'uuuuuuuuuuuuuu', 'nkkkkkkkkkkkkn', 'nkkkkkkkkkkkkn', 'uuuuuuuuuuuuuu',
    'nNNNNNNNNNNNNn', 'nNtNNNNNNNNtNn', 'nNNNNNNNNNNNNn', '.nnnnnnnnnnnn.'
  ];
  defSprite('chest', { frames: [chestRowsClosed, chestRowsOpen] });
  defSprite('goldchest', { pal: { n: '#7a5a20', N: '#c89a3a', t: '#fff2a8', u: '#5a4428', y: '#e0e0e0', k: '#2a1d18' }, frames: [chestRowsClosed, chestRowsOpen] });

  // ------------------------------------------------------------ consumabili
  defSprite('bomb', { frames: [['......y', '.....O.', '....n..', '..ggg..', '.gGsGg.', 'gGsGGGg', 'gGGGGGg', 'gGGGGGg', '.gGGGg.', '..ggg..']] });
  const bottle = ['..nnn..', '..sss..', '...s...', '..sLs..', '.sLWLs.', 'sLLWLLs', 'sLLLLLs', 'sLLLLls', '.sllls.'];
  defSprite('potion', { pal: { L: '#d04b3c', l: '#7e2530', W: '#ffb0a0', s: '#c8c0d0' }, frames: [bottle] });
  defSprite('bigpotion', { pal: { L: '#f2b84a', l: '#a0701f', W: '#fff2a8', s: '#e8d8a0' }, frames: [bottle] });
  defSprite('oilflask', { pal: { L: '#c8761f', l: '#7a4010', W: '#ffd080', s: '#9a8a70' }, frames: [bottle] });
  defSprite('antidote', { pal: { L: '#6fc04a', l: '#2e6a2a', W: '#d0ffb0', s: '#c8c0d0' }, frames: [bottle] });
  defSprite('rage', { pal: { L: '#e0702a', l: '#8a3010', W: '#ffd0a0', s: '#c8c0d0' }, frames: [bottle] });
  defSprite('frost', { pal: { L: '#7fd0f0', l: '#2f6a9a', W: '#ffffff', s: '#c8e0f0' }, frames: [bottle] });
  defSprite('holy', { pal: { L: '#e8f0ff', l: '#8aa0d0', W: '#ffffff', s: '#f6cf57' }, frames: [bottle] });
  defSprite('scroll', { frames: [['uu......', 'utttttt.', 'utYtYtt.', '.tttttt.', '.ttYtYt.', '.tttttu.', '......uu']], pal: { t: '#d8c49a', Y: '#6a5030', u: '#9a7a44' } });
  defSprite('jar', { pal: { s: '#a8c8d0' }, frames: [['.nnnnn.', '..sss..', '.s...s.', 's.y...s', 's...y.s', 's.y...s', 's.....s', '.sssss.'], ['.nnnnn.', '..sss..', '.s...s.', 's...y.s', 's.y...s', 's...y.s', 's.....s', '.sssss.']] });
  defSprite('dice', { frames: [['.wwwww.', 'wkwwwww', 'wwwwwww', 'wwwkwww', 'wwwwwww', 'wwwwwkw', '.wwwwws']] });
  defSprite('pouch', { pal: { n: '#2a2440', N: '#4a4068', t: '#8a80b0' }, frames: [['..n.n..', '...n...', '..nNn..', '.nNNNn.', 'nNNtNNn', 'nNtNNNn', 'nNNNNNn', '.nnnnn.']] });
  defSprite('feather', { frames: [['......Rr', '.....RRr', '....ORRr', '...OORr.', '..yOOr..', '..yOr...', '.yOr....', '.n......', 'n.......']] });

  // ------------------------------------------------------------ oggetti di scena
  defSprite('barrel', {
    frames: [[
      '..nnnnnnnn..', '.nNNNNNNNNn.', 'nNNtNNNNtNNn', 'gGGGGGGGGGGg', 'nNNNNNNNNNNn', 'nNNNRRRRNNNn', 'nNNRRyyRRNNn',
      'nNNNRRRRNNNn', 'nNNNNNNNNNNn', 'gGGGGGGGGGGg', 'nNNtNNNNtNNn', '.nNNNNNNNNn.', '..nnnnnnnn..'
    ]]
  });
  defSprite('urn', { sym: true, frames: [['..uuu', '...uU', '..uUU', '.uUtU', 'uUUUU', 'uUnnn', 'uUUUU', 'uUUtU', '.uUUU', '..uuu']] });
  defSprite('brazier', { sym: true, frames: [['gGGGGG', '.gGGGG', '..gGGG', '...ggg', '.....g', '.....g', '....gG', '...gGG', '..gggg']] });
  defSprite('pedestal', { sym: true, frames: [['sxxxxx', 'gsssss', '.gGGGG', '.gGGGG', '.gGGGG', 'gsssss', 'gggggg']] });
  defSprite('altar', {
    sym: true, pal: { q: '#3a1838', Q: '#6a2a5a' }, frames: [[
      'gsssssss', 'gGGGGGGG', '.gGqqqqq', '.gGqQQQQ', '.gGqQRRQ', '.gGqQRRQ', '.gGqQQQQ', '.gGqqqqq', '.gGGGGGG', 'gsssssss', 'gggggggg'
    ]]
  });
  defSprite('fountain', {
    sym: true, pal: { c: '#5aa0d0', C: '#a0d8f0' }, frames: [[
      '.......s', '......sx', '......sx', '..sssssx', '.sccCccc', 'sccccCcc', 'sxxxxxxx', '.sGGGGGG', '.sGGGGGG', 'ssssssss'
    ], [
      '.......s', '......sx', '......sx', '..sssssx', '.scCcccc', 'sccccccC', 'sxxxxxxx', '.sGGGGGG', '.sGGGGGG', 'ssssssss'
    ]]
  });
  defSprite('merchant', {
    sym: true, pal: { u: '#4a3a2a', U: '#6a5638', t: '#b8a080' }, frames: [[
      '....uu', '..uUUU', '.uuuuu', 'uuuuuu', '..nkkk', '..nkyk', '..nkkk', '..tttt', '.nNNtt', 'nNNNNt', 'nNtNNN', 'nN.NNN', '...NNN', '...NNN', '...nn.', '..mm..'
    ], [
      '....uu', '..uUUU', '.uuuuu', 'uuuuuu', '..nkkk', '..nkkk', '..nkkk', '..tttt', '.nNNtt', 'nNNNNt', 'nNtNNN', 'nN.NNN', '...NNN', '...NNN', '...nn.', '..mm..'
    ]]
  });

  // ------------------------------------------------------------ icone doni / reliquie (10x10)
  const I = (name, rows, pal, sym) => defSprite(name, { frames: [rows], pal: pal || {}, sym: !!sym });
  I('i_blade', ['........ss', '.......sWs', '......sWs.', '.....sWs..', '....sWs...', '.n.sWs....', '..nWs.....', '..yn......', '.y.yn.....', 'y.........']);
  I('i_rate', ['.O...O....', '..O...O...', '...O...O..', '....y...y.', '...O...O..', '..O...O...', '.O...O....']);
  I('i_boot', ['...nnnn...', '...nNNn...', '...nNNn...', '...nNNn...', '...nNNnn..', '..nNNNNNn.', '..nNNNNNNn', '..mmmmmmmm']);
  I('i_heart', ['.RR..', 'RWRR.', 'RRRRR', 'RRRRR', '.RRRR', '..RRR', '...RR', '....R'], null, true);
  I('i_shield', ['ggggg', 'gssss', 'gsxxx', 'gsxBB', 'gsxBB', '.gsxB', '.gsxx', '..gsx', '...gs', '....g'], null, true);
  I('i_eye', ['...kk', '.kkww', 'kwwcb', 'kwcbk', 'kwwcb', '.kkww', '...kk'], null, true);
  I('i_range', ['w.....y...', '.w....yy..', 'nnnnnnnyyy', '.w....yy..', 'w.....y...']);
  I('i_drop', ['...o', '...O', '..oO', '.oOO', 'oOYO', 'oOYO', 'oOOO', '.ooO', '..oo'], null, true);
  I('i_magnet', ['ww...', 'ww...', 'RR...', 'RR...', 'RR...', 'RRR..', '.RRRR', '..RRR'], null, true);
  I('i_coin', ['..yyy', '.yYYY', 'yYyyy', 'yYyoo', 'yYyoo', 'yyyyy', '.yooo', '..ooo'], null, true);
  I('i_star', ['....y', '....y', '...yY', 'yyyyY', '.yYYY', '..yYY', '..yYy', '.yy.y', 'yy...'], null, true);
  I('i_thorn', ['E...e...E.', '.e.eEe.e..', '..eE.Ee...', '.eE...Ee..', 'eE.....Ee.', '.eE...Ee..', '..eE.Ee...', '.e.eEe.e..', 'E...e...E.']);
  I('i_flask', ['..nnn..', '..sss..', '...s...', '..sLs..', '.sLWLs.', 'sLLWLLs', 'sLLLLLs', '.sllls.'], { L: '#6fc04a', l: '#2e6a2a', W: '#d0ffb0' });
  I('i_multi', ['y...y...y.', 'O...O...O.', 'O...O...O.', '.O..O..O..', '..O.O.O...', '...OOO....', '....n.....', '....n.....']);
  I('i_pierce', ['.........x', '........xW', '.......xx.', '......nx..', '.....n....', '....n.....', '...n......', '..n.......', '.nw.......', 'w.w.......']);
  I('i_bounce', ['O.........', '.O.......g', '..O.....gG', '...O...gG.', '....O.gG..', '.....OO...', '....O.O...', '...O...O..']);
  I('i_wisp', ['....c', '...cC', '..cCW', '.cCWW', '.cCWW', '..cCC', '...cc', '..c..', '.c...'], { c: '#5ab0c0', C: '#a0f0f0' }, true);
  I('i_flame', ['....R', '...RO', '..ROO', '.ROOy', '.ROyy', 'ROOyY', 'ROyYY', '.RyYY', '..RRR'], null, true);
  I('i_poison', ['...e', '...E', '..eE', '.eEl', 'eEll', 'eElk', 'eEll', '.eEE', '..ee'], null, true);
  I('i_snow', ['....C', '.C..c', '..C.c', '...cc', 'CcccW', '...cc', '..C.c', '.C..c', '....C'], { c: '#7fd0e0', C: '#c8f2f5' }, true);
  I('i_wing', ['........ww', '......wwws', '....wwwss.', '..wwwss...', '.wwss.....', 'wwss......', 'wss.......', 'ws........']);
  I('i_bolt', ['.....yy', '....yY.', '...yY..', '..yYYYy', '.....Y.', '....Y..', '...Y...', '..y....']);
  I('i_skull', ['..www', '.wwww', 'wwwww', 'wkkww', 'wkRww', 'wwwwk', '.wwww', '.wkwk'], null, true);
  I('i_sun', ['....y', '.y..y', '..yyy', '.yYYY', 'yyYWW', '.yYYY', '..yyy', '.y..y', '....y'], null, true);
  I('i_crown', ['y...y', 'yy.yy', 'yyyyy', 'yRyyy', 'yyyyy', 'ooooo'], null, true);
  I('i_moon', ['..sss....', '.sxx.....', 'sxx......', 'sxx......', 'sxx......', 'sxxs.....', '.sxxs..s.', '..sxxxxs.', '...ssss..']);
  I('i_bell', ['....y', '...yy', '..yYy', '.yYyy', '.yYyy', '.yYyy', 'yyyyy', '....o'], null, true);
  I('i_lens', ['..oooo', '.oyYYo', 'oyYWYo', 'oyYYyo', 'oyyyyo', '.oooo.', '....nn', '.....n']);
  I('i_tooth', ['wwwww', 'wWwww', 'wwwww', '.wwww', '..www', '..ww.', '..w..'], null, true);
  I('i_anvil', ['gggggggg..', 'gGGGGGGGGg', '.gGGGGGGg.', '...gGGg...', '...gGGg...', '..gGGGGg..', '.gggggggg.']);
  I('i_clover', ['.EE.', 'EllE', 'EllE', '.EEn', '...n', '...n'], null, true);
  I('i_hourglass', ['nnnnn', '.ttt.', '.tyy.', '..ty.', '...t.', '..t..', '.tyy.', '.tyy.', 'nnnnn'].map(r => r), null, false);
  I('i_mirror', ['..uuu', '.uccC', 'uccCc', 'ucCcc', 'uCcck', 'uccck', '.uccc', '..uuu', '...nn', '...nn'], { c: '#7fb0d0', C: '#e0f6ff', k: '#3a3a5a' }, true);
  I('i_coffin', ['..nnnn..', '.nNNNNn.', 'nNNyNNNn', 'nNyyyNNn', 'nNNyNNNn', '.nNyNNn.', '.nNNNNn.', '..nNNn..', '...nn...']);
  I('i_urn', ['..uuu', '...uU', '..uUU', '.uUtU', 'uUUUU', 'uUOOO', 'uUUUU', '.uUUU', '..uuu'], null, true);
  I('i_quiver', ['w..w..w...', '.w.w.w....', '..www.....', '..nNn.....', '..nNn.....', '..nNn.....', '..nNn.....', '..nnn.....']);
  I('i_shell', ['...EE', '..EeE', '.EeEe', 'EeEeE', 'EEEEE', 'ttttt'], { E: '#5d7a5a', e: '#8aa05a', t: '#c49a6a' }, true);
  I('i_storm', ['..ss.', '.sxxs', 'sxxxx', '.ssss', '...y.', '..y..', '...y.', '..y..'], null, true);
  I('i_lamp', ['...gg', '..gYY', '.gyYW', '.gyYY', '..gyy', 'ggggg', '..n..'], null, true);
  I('i_cup', ['RRRRR', 'yRRRR', 'yyyyy', '.yyyy', '..yyy', '...yy', '...yy', '..yyy'], null, true);
  I('i_key', ['.yyy......', 'yo.oyyyyyy', 'yo.oy..y.y', '.yyy......']);
  I('i_orbit', ['...yy...', '.y....y.', 'y..OO..y', '..OYYO..', '..OYYO..', 'y..OO..y', '.y....y.', '...yy...']);
  I('i_hand', ['..w.w.', '.wwwww', '.wwwww', 'wwwwww', '.wwwww', '..www.'], { w: '#d8b48a' });
  I('i_book', ['nnnn.nnnn', 'nwwwnwwwn', 'nwkwnwkwn', 'nwwwnwwwn', 'nwkwnwkwn', 'nwwwnwwwn', 'nnnnnnnnn']);
  I('i_ice', ['....C', '...Cc', '..Ccc', '.Cccc', 'CccWc', '.Cccc', '..Ccc', '...Cc', '....C'], { c: '#7fd0e0', C: '#c8f2f5' }, true);
  I('i_lantern', ['...gg', '..gnn', '.gnnn', '.gyYY', '.gyYW', '.gyYY', '.gnnn', '..ggg'], null, true);
  I('i_blood', ['....r', '...rR', '..rRR', '.rRRW', '.rRRR', '..rRR', '...rr'], null, true);
  I('i_mask', ['.wwww', 'wwwww', 'wkkww', 'wwwww', '.wwwk', '..www'], { w: '#c8c0d0' }, true);

  // ------------------------------------------------------------ icone di stato (7x7)
  I('s_burn', ['..R', '.RO', 'ROO', 'ROy', '.Ry'], null, true);
  I('s_poison', ['..e', '.eE', 'eEl', 'eEl', '.ee'], null, true);
  I('s_chill', ['C.c', '.Cc', 'ccW', '.Cc', 'C.c'], { c: '#7fd0e0', C: '#c8f2f5' }, true);
  I('s_slow', ['..ggg..', '.gGGGg.', 'gGsGGGg', 'gGGGGGg', 'EEEEEEE']);
  I('s_weak', ['....s', '...s.', '..s..', '.n...', 'y....', '..R.R', '...R.']);
  I('s_fragile', ['ggg', 'gsR', 'gRx', '.Rs', '..g'], null, true);
  I('s_blind', ['.kk', 'kww', 'kkk', '.kk'], null, true);
  I('s_curse', ['.VV', 'VVV', 'VkV', 'VVV', '.Vk'], { V: '#8a4fb0' }, true);
  I('s_rage', ['R...R', 'RR.RR', 'RRRRR', '.RRR.', '..R..']);
  I('s_shield', ['cc', 'cC', 'cC', '.c'], { c: '#7fd0e0', C: '#e0f6ff' }, true);
  I('s_invis', ['.sss.', 's.s.s', 'sssss', 'sssss', 's.s.s'], { s: '#8a8294' });
}
