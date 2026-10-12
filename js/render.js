'use strict';
// =====================================================================
// World rendering: room, entities, lights and shadows
// =====================================================================

const Render = { light: null, lctx: null, time: 0 };
function initRender() {
  Render.light = makeCanvas(W, H);
  Render.lctx = Render.light.getContext('2d');
}
function spikesUp(room) { return (room.spikeT % 3) > 2.0; }
function spikesWarn(room) { const k = room.spikeT % 3; return k > 1.6 && k <= 2.0; }

function drawWorld(ctx) {
  const room = run.room, p = run.player;
  let sx = 0, sy = 0;
  if (FX.shake > 0.1) { sx = Math.round(rnd(-1, 1) * FX.shake); sy = Math.round(rnd(-1, 1) * FX.shake); }
  ctx.save();
  ctx.translate(sx, sy);
  if (room.bgDirty || !room.bg) renderRoomBg(room, run.floor);
  ctx.drawImage(room.bg, RX, RY);
  drawSecretHints(ctx, room);
  drawDoors(ctx, room);
  drawDynamicTiles(ctx, room);
  drawGroundFx(ctx);
  drawObjects(ctx, room);
  drawPickups(ctx, room);

  // entities sorted by depth
  const list = [];
  for (const e of run.enemies) list.push(e);
  if (!p.dead) list.push(p);
  list.sort((a, b) => a.y - b.y);
  for (const e of list) { if (e === p) drawPlayer(ctx, p); else drawEnemy(ctx, e); }
  drawPlayerBullets(ctx);
  Particles.draw(ctx, false);
  drawAirFx(ctx);
  ctx.restore();

  drawLighting(ctx, sx, sy);

  ctx.save();
  ctx.translate(sx, sy);
  drawTelegraphs(ctx);
  drawEyes(ctx);
  drawEnemyBullets(ctx);
  Particles.draw(ctx, true);
  Floaters.draw(ctx);
  drawPrompt(ctx);
  ctx.restore();
}

// ---------------------------------------------------------------------
// Doors
// ---------------------------------------------------------------------
function doorStyle(room, d) {
  const n = room.doors[d];
  if (room.type === 'boss' || n.type === 'boss') return { frame: '#7e2530', hi: '#d04b3c', kind: 'boss' };
  if (n.type === 'treasure' || room.type === 'treasure') return { frame: '#9a7a44', hi: '#f6cf57', kind: 'treasure' };
  if (n.type === 'shop' || room.type === 'shop') return { frame: '#5a4428', hi: '#c49a6a', kind: 'shop' };
  if (n.type === 'elite' || room.type === 'elite') return { frame: '#3a1020', hi: '#e0574a', kind: 'elite' };
  if (n.type === 'shrine' || room.type === 'shrine') return { frame: '#4b2a5c', hi: '#c57ae0', kind: 'shrine' };
  if (n.type === 'secret' || room.type === 'secret') return { frame: '#2a2430', hi: '#55505e', kind: 'secret' };
  return { frame: '#2a2230', hi: '#6b6478', kind: 'normal' };
}
function drawDoors(ctx, room) {
  for (const d in room.doors) {
    if (!doorVisible(room, d)) continue;
    const st = doorStyle(room, d);
    const t0 = DIRS[d].tiles[0];
    const horiz = d === 'n' || d === 's';
    const x = RX + t0[0] * TS, y = RY + t0[1] * TS;
    const w = horiz ? TS * 3 : TS, h = horiz ? TS : TS * 3;
    const open = doorOpen(room, d), locked = doorLocked(room, d);
    if (st.kind === 'secret') {
      // irregular gap
      pxRect(ctx, x + 2, y + 2, w - 4, h - 4, '#050308');
      ctx.fillStyle = '#3b3546';
      for (let i = 0; i < 6; i++) { const k = hash2(i, x, y); ctx.fillRect(x + (horiz ? k * w : (k > 0.5 ? 1 : w - 3)), y + (horiz ? (k > 0.5 ? 1 : h - 3) : k * h), 2, 2); }
      continue;
    }
    // frame
    pxRect(ctx, x, y, w, h, '#0b0810');
    pxRect(ctx, x + 1, y + 1, w - 2, h - 2, st.frame);
    pxRect(ctx, x + 4, y + 4, w - 8, h - 8, open ? '#050308' : '#120c16');
    // glowing thread
    if (horiz) { pxRect(ctx, x + 2, d === 'n' ? y + 2 : y + h - 3, w - 4, 1, st.hi); }
    else { pxRect(ctx, d === 'w' ? x + 2 : x + w - 3, y + 2, 1, h - 4, st.hi); }
    if (!open) {
      // bars
      ctx.fillStyle = locked ? '#c49a3a' : '#6b6478';
      if (horiz) for (let i = 0; i < 6; i++) ctx.fillRect(x + 7 + i * 6, y + 3, 2, h - 6);
      else for (let i = 0; i < 6; i++) ctx.fillRect(x + 3, y + 7 + i * 6, w - 6, 2);
      if (locked) {
        const cx = x + w / 2, cy = y + h / 2;
        pxRect(ctx, cx - 4, cy - 2, 8, 7, '#0b0810'); pxRect(ctx, cx - 3, cy - 1, 6, 5, '#f6cf57');
        pxRect(ctx, cx - 2, cy - 5, 4, 1, '#f6cf57'); pxRect(ctx, cx - 3, cy - 4, 1, 3, '#f6cf57'); pxRect(ctx, cx + 2, cy - 4, 1, 3, '#f6cf57');
        pxRect(ctx, cx - 1, cy + 1, 2, 2, '#5a4428');
      }
    }
    // symbols
    const cx = x + w / 2, cy = y + h / 2;
    const sx = horiz ? cx : (d === 'w' ? x + w + 6 : x - 6), sy = horiz ? (d === 'n' ? y + h + 6 : y - 6) : cy;
    if (st.kind === 'boss') drawSpr(ctx, 'i_skull', 0, sx, sy, { alpha: 0.8 });
    else if (st.kind === 'treasure') drawSpr(ctx, 'i_crown', 0, sx, sy, { alpha: 0.8 });
    else if (st.kind === 'shop') drawSpr(ctx, 'i_coin', 0, sx, sy, { alpha: 0.8 });
    else if (st.kind === 'elite') drawSpr(ctx, 'i_blade', 0, sx, sy, { alpha: 0.8 });
    else if (st.kind === 'shrine') drawSpr(ctx, 'i_star', 0, sx, sy, { alpha: 0.7 });
  }
}
function drawSecretHints(ctx, room) {
  for (const d in room.doors) {
    const n = room.doors[d];
    if (n.type !== 'secret' || n.found) continue;
    const c = doorCenter(d);
    const reveal = run.player.stats.mapReveal || n.mapped;
    ctx.fillStyle = reveal ? 'rgba(246,207,87,0.55)' : 'rgba(5,3,8,0.6)';
    ctx.fillRect(c.x - 3, c.y - 4, 1, 4); ctx.fillRect(c.x - 2, c.y, 2, 1); ctx.fillRect(c.x, c.y + 1, 1, 3);
    ctx.fillRect(c.x + 2, c.y - 3, 1, 3); ctx.fillRect(c.x + 3, c.y - 1, 2, 1);
  }
}

// ---------------------------------------------------------------------
// Dynamic tiles
// ---------------------------------------------------------------------
function drawDynamicTiles(ctx, room) {
  const up = spikesUp(room), warn = spikesWarn(room);
  for (let ty = 1; ty < RH - 1; ty++) for (let tx = 1; tx < RW - 1; tx++) {
    const t = room.grid[ty][tx];
    if (t === T.FLOOR || t === T.ROCK || t === T.CRACK) continue;
    const x = RX + tx * TS, y = RY + ty * TS, cx = x + 8, cy = y + 8;
    if (t === T.SPIKE) {
      pxRect(ctx, x + 1, y + 1, 14, 14, '#16111c');
      pxRect(ctx, x + 2, y + 2, 12, 12, '#2a2430');
      for (const [ox, oy] of [[4, 4], [10, 4], [4, 10], [10, 10]]) {
        pxRect(ctx, x + ox - 1, y + oy, 3, 1, '#0b0810');
        if (up) { pxRect(ctx, x + ox, y + oy - 4, 1, 4, '#e8e4dc'); pxRect(ctx, x + ox - 1, y + oy - 2, 3, 2, '#a59fb0'); }
        else if (warn) { pxRect(ctx, x + ox, y + oy - 1, 1, 1, '#a59fb0'); }
      }
    } else if (t === T.BARREL) {
      shadow(ctx, cx, cy + 6, 6);
      const hp = room.tileHp[ty * RW + tx];
      drawSpr(ctx, 'barrel', 0, cx, cy, { flash: hp < 18 && Math.sin(Render.time * 20) > 0.6 });
    } else if (t === T.URN) {
      shadow(ctx, cx, cy + 5, 5);
      drawSpr(ctx, 'urn', 0, cx, cy);
    } else if (t === T.BRAZIER) {
      shadow(ctx, cx, cy + 6, 6);
      drawSpr(ctx, 'brazier', 0, cx, cy + 2);
      drawFlame(ctx, cx, cy - 3, 1);
    }
  }
}
function drawFlame(ctx, x, y, s) {
  const t = Render.time * 10 + x;
  for (let i = 0; i < 6; i++) {
    const h = (3 + Math.sin(t + i * 1.7) * 2 + (i % 3)) * s;
    const ox = (i - 2.5) * 1.5 * s;
    pxRect(ctx, x + ox, y - h, 1.5 * s, h, i % 2 ? '#f29c38' : '#d04b3c');
  }
  pxRect(ctx, x - 2 * s, y - 3 * s, 4 * s, 3 * s, '#f6cf57');
  pxRect(ctx, x - 1 * s, y - 2 * s, 2 * s, 2 * s, '#fff2a8');
}

// ---------------------------------------------------------------------
// Ground effects
// ---------------------------------------------------------------------
function drawGroundFx(ctx) {
  for (const f of run.fx) {
    if (f.delay > 0) continue;
    const k = f.t / f.life;
    switch (f.type) {
      case 'cloud': {
        const r = f.r * Math.min(1, f.t * 3);
        ctx.save(); ctx.globalAlpha = 0.35 * (1 - Math.max(0, k - 0.7) / 0.3);
        pxCircle(ctx, f.x, f.y, r, '#4f8a3a');
        ctx.globalAlpha *= 0.6; pxCircle(ctx, f.x + Math.sin(f.t * 2) * 3, f.y - 2, r * 0.6, '#9fd05a');
        ctx.restore();
        break;
      }
      case 'fire': {
        ctx.save(); ctx.globalAlpha = 0.55 * (1 - k);
        pxCircle(ctx, f.x, f.y, f.r * 0.7, f.owner === 'player' ? '#b5571f' : '#d04b3c');
        ctx.restore();
        break;
      }
      case 'spawn': {
        const r = 4 + k * 7;
        ctx.save(); ctx.globalAlpha = 0.4 + 0.4 * Math.sin(f.t * 20);
        pxRing(ctx, f.x, f.y, r, '#c57ae0'); pxRing(ctx, f.x, f.y, r * 0.5, '#e8e4dc');
        ctx.restore();
        break;
      }
      case 'bomb': {
        shadow(ctx, f.x, f.y + 4, 4);
        const blink = f.t > 1 ? Math.sin(f.t * 40) > 0 : Math.sin(f.t * 14) > 0.4;
        drawSpr(ctx, 'bomb', 0, f.x, f.y, { flash: blink, scale: 1 });
        break;
      }
    }
  }
}
function drawAirFx(ctx) {
  for (const f of run.fx) {
    if (f.delay > 0) continue;
    const k = f.t / f.life;
    switch (f.type) {
      case 'explosion': {
        const r = f.r * (0.4 + 0.6 * Math.min(1, k * 3));
        ctx.save(); ctx.globalAlpha = 1 - k;
        pxCircle(ctx, f.x, f.y, r, k < 0.3 ? '#fff2a8' : '#f29c38');
        ctx.globalAlpha = (1 - k) * 0.7; pxCircle(ctx, f.x, f.y, r * 0.6, k < 0.3 ? '#ffffff' : '#f6cf57');
        ctx.restore();
        break;
      }
      case 'flare': {
        ctx.save(); ctx.globalAlpha = 1 - k;
        pxRing(ctx, f.x, f.y, f.r * (0.3 + k * 0.9), '#fff2a8', 3);
        pxRing(ctx, f.x, f.y, f.r * (0.2 + k * 0.7), '#f29c38', 2);
        ctx.restore();
        break;
      }
      case 'shockwave': {
        ctx.save(); ctx.globalAlpha = Math.max(0, 1 - f.r / f.maxR);
        const col = f.owner === 'player' ? '#f29c38' : f.owner === 'visual' ? '#a24ab8' : '#e8e4dc';
        pxRing(ctx, f.x, f.y, f.r, col, 3);
        ctx.restore();
        break;
      }
      case 'bolt': {
        ctx.save(); ctx.globalAlpha = 1 - k;
        ctx.strokeStyle = '#c8f2f5'; ctx.lineWidth = 2;
        ctx.beginPath();
        f.pts.forEach(([x, y], i) => {
          if (i === 0) ctx.moveTo(x, y);
          else {
            const [px, py] = f.pts[i - 1];
            for (let j = 1; j <= 3; j++) ctx.lineTo(lerp(px, x, j / 4) + rnd(-4, 4), lerp(py, y, j / 4) + rnd(-4, 4));
            ctx.lineTo(x, y);
          }
        });
        ctx.stroke();
        ctx.strokeStyle = '#ffffff'; ctx.lineWidth = 1; ctx.stroke();
        ctx.restore();
        break;
      }
    }
  }
}

// warnings always visible even in the dark
function drawTelegraphs(ctx) {
  for (const f of run.fx) {
    if (f.type === 'warn') {
      const k = f.t / f.life;
      ctx.save();
      ctx.globalAlpha = 0.25 + 0.25 * Math.sin(f.t * 18);
      pxCircle(ctx, f.x, f.y, f.r, f.hit === 'cloud' ? '#4f8a3a' : '#7e2530');
      ctx.globalAlpha = 0.9;
      pxRing(ctx, f.x, f.y, f.r, f.hit === 'cloud' ? '#9fd05a' : '#e0574a');
      pxRing(ctx, f.x, f.y, f.r * k, '#ffffff');
      ctx.restore();
    } else if (f.type === 'beam') {
      const ex = f.x + Math.cos(f.ang) * f.len, ey = f.y + Math.sin(f.ang) * f.len;
      ctx.save();
      if (f.t < f.warm) {
        ctx.globalAlpha = 0.4 + 0.3 * Math.sin(f.t * 25);
        ctx.strokeStyle = '#e0574a'; ctx.lineWidth = 1; ctx.setLineDash([4, 3]);
        ctx.beginPath(); ctx.moveTo(f.x, f.y); ctx.lineTo(ex, ey); ctx.stroke();
      } else {
        ctx.strokeStyle = '#7a3a9a'; ctx.lineWidth = f.w + 4; ctx.globalAlpha = 0.5;
        ctx.beginPath(); ctx.moveTo(f.x, f.y); ctx.lineTo(ex, ey); ctx.stroke();
        ctx.globalAlpha = 1; ctx.strokeStyle = '#e0a0ff'; ctx.lineWidth = f.w;
        ctx.beginPath(); ctx.moveTo(f.x, f.y); ctx.lineTo(ex, ey); ctx.stroke();
        ctx.strokeStyle = '#ffffff'; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.moveTo(f.x, f.y); ctx.lineTo(ex, ey); ctx.stroke();
      }
      ctx.restore();
    }
  }
  for (const e of run.enemies) {
    if (e.chargeLine !== null && e.chargeLine !== undefined) {
      ctx.save(); ctx.globalAlpha = 0.5 + 0.3 * Math.sin(Render.time * 30);
      ctx.strokeStyle = '#e0574a'; ctx.lineWidth = e.r; ctx.setLineDash([6, 4]);
      ctx.beginPath(); ctx.moveTo(e.x, e.y); ctx.lineTo(e.x + Math.cos(e.chargeLine) * 300, e.y + Math.sin(e.chargeLine) * 300); ctx.stroke();
      ctx.restore();
    }
    if (e.slamTarget) {
      ctx.save(); ctx.globalAlpha = 0.5;
      pxCircle(ctx, e.slamTarget.x, e.slamTarget.y, e.r + 4, '#7e2530');
      pxRing(ctx, e.slamTarget.x, e.slamTarget.y, e.r + 4, '#e0574a');
      ctx.restore();
    }
    if (e.ai === 'charger' && e.state === 'wind') {
      ctx.save(); ctx.globalAlpha = 0.35;
      ctx.strokeStyle = '#e0574a'; ctx.lineWidth = 2; ctx.setLineDash([3, 3]);
      ctx.beginPath(); ctx.moveTo(e.x, e.y); ctx.lineTo(e.x + Math.cos(e.chargeA) * 120, e.y + Math.sin(e.chargeA) * 120); ctx.stroke();
      ctx.restore();
    }
    if (e.ai === 'dasher' && e.state === 'aim') {
      ctx.save(); ctx.globalAlpha = 0.35;
      ctx.strokeStyle = '#7fd8e6'; ctx.lineWidth = 2; ctx.setLineDash([3, 3]);
      ctx.beginPath(); ctx.moveTo(e.x, e.y); ctx.lineTo(e.x + Math.cos(e.dashA) * 110, e.y + Math.sin(e.dashA) * 110); ctx.stroke();
      ctx.restore();
    }
    // attack warning: spark above the head
    if (e.wind > 0 && !e.dead && e.alpha > 0.3) {
      const blink = Math.sin(Render.time * 40) > 0;
      if (blink) { pxRect(ctx, e.x - 1, e.y - e.r - 9 - e.z, 2, 4, '#f6cf57'); pxRect(ctx, e.x - 1, e.y - e.r - 4 - e.z, 2, 1, '#f6cf57'); }
    }
  }
}

// ---------------------------------------------------------------------
// Objects
// ---------------------------------------------------------------------
function drawObjects(ctx, room) {
  const tt = Render.time;
  for (const o of room.objects) {
    if (o.gone) continue;
    switch (o.type) {
      case 'relic': {
        shadow(ctx, o.x, o.y + 8, 7);
        drawSpr(ctx, 'pedestal', 0, o.x, o.y + 4);
        const by = o.y - 9 + Math.sin(tt * 2.5 + o.x) * 2;
        glow(ctx, o.x, by, 18, '#f6cf57', 0.25);
        drawSpr(ctx, RELICS[o.id].icon, 0, o.x, by);
        break;
      }
      case 'shopitem': {
        shadow(ctx, o.x, o.y + 8, 7);
        drawSpr(ctx, 'pedestal', 0, o.x, o.y + 4);
        const by = o.y - 8 + Math.sin(tt * 2 + o.x) * 1.5;
        const it = o.item;
        if (it.kind === 'cons') drawSpr(ctx, CONS[it.id].spr, 0, o.x, by);
        else if (it.kind === 'heal') drawSpr(ctx, 'heart', 0, o.x, by);
        else if (it.kind === 'key') drawSpr(ctx, 'key', 0, o.x, by);
        else if (it.kind === 'relic') { glow(ctx, o.x, by, 16, '#f6cf57', 0.2); drawSpr(ctx, RELICS[it.id].icon, 0, o.x, by); }
        const price = priceOf(o);
        const can = run.player.coins >= price;
        drawSpr(ctx, 'coin', 0, o.x - Font.width(String(price)) / 2 - 3, o.y + 16);
        Font.draw(ctx, String(price), o.x + 3, o.y + 13, { align: 'center', color: can ? TEXT_COLORS.y : TEXT_COLORS.r });
        break;
      }
      case 'chest':
        shadow(ctx, o.x, o.y + 6, 8);
        drawSpr(ctx, o.gold ? 'goldchest' : 'chest', o.open ? 1 : 0, o.x, o.y);
        if (o.gold && !o.open) glow(ctx, o.x, o.y, 16, '#f6cf57', 0.15);
        break;
      case 'shrine': {
        const used = o.uses <= 0;
        shadow(ctx, o.x, o.y + 10, 12);
        if (o.kind === 'fortune' || o.kind === 'fountain') drawSpr(ctx, 'fountain', Math.floor(tt * 3) % 2, o.x, o.y, { alpha: used ? 0.6 : 1 });
        else {
          drawSpr(ctx, 'altar', 0, o.x, o.y, { alpha: used ? 0.6 : 1 });
          if (!used) drawFlame(ctx, o.x, o.y - 10, 1);
        }
        break;
      }
      case 'merchant': {
        shadow(ctx, o.x, o.y + 8, 7);
        drawSpr(ctx, 'merchant', Math.floor(tt * 1.5) % 4 === 0 ? 1 : 0, o.x, o.y);
        // merchant's lantern
        pxRect(ctx, o.x + 8, o.y - 2, 3, 4, '#f6cf57'); pxRect(ctx, o.x + 8, o.y - 3, 3, 1, '#3b3546');
        if (dist(o.x, o.y, run.player.x, run.player.y) < 70) {
          const w = Math.min(200, Font.width(o.line) + 12);
          panel(ctx, o.x - w / 2, o.y - 34, w, 16, { alpha: 0.9 });
          Font.draw(ctx, o.line, o.x, o.y - 30, { align: 'center', color: '#e8dcc0' });
        }
        break;
      }
      case 'trapdoor': {
        const x = o.x - 12, y = o.y - 12;
        pxRect(ctx, x - 1, y - 1, 26, 26, '#0b0810');
        pxRect(ctx, x, y, 24, 24, '#5a3a24');
        pxRect(ctx, x + 2, y + 2, 20, 20, '#050308');
        for (let i = 0; i < 4; i++) pxRect(ctx, x + 5, y + 4 + i * 5, 14, 1, '#4a3020');
        glow(ctx, o.x, o.y, 26, '#c57ae0', 0.15 + 0.08 * Math.sin(tt * 3));
        break;
      }
    }
  }
}

function drawPickups(ctx, room) {
  const tt = Render.time;
  for (const k of room.pickups) {
    const y = k.y - k.z;
    if (k.type !== 'xp') shadow(ctx, k.x, k.y + 3, 3);
    switch (k.type) {
      case 'xp': {
        const c = (Math.floor(tt * 8 + k.x) % 2) ? '#c57ae0' : '#e0a0ff';
        pxRect(ctx, k.x - 1, y - 1, 2, 2, c); pxRect(ctx, k.x, y - 2, 1, 1, '#ffffff');
        break;
      }
      case 'coin': drawSpr(ctx, 'coin', Math.floor(tt * 5 + k.x) % 2, k.x, y); break;
      case 'coin5': drawSpr(ctx, 'coin5', Math.floor(tt * 5 + k.x) % 2, k.x, y); break;
      case 'heart': drawSpr(ctx, 'heart', 0, k.x, y + Math.sin(tt * 4 + k.x) * 0.8); break;
      case 'oil': drawSpr(ctx, 'oil', 0, k.x, y); break;
      case 'key': drawSpr(ctx, 'key', 0, k.x, y); break;
      case 'cons': drawSpr(ctx, CONS[k.id].spr, 0, k.x, y - 2 + Math.sin(tt * 3 + k.x)); break;
    }
  }
}

// ---------------------------------------------------------------------
// Player and enemies
// ---------------------------------------------------------------------
function drawLantern(ctx, p) {
  const L = LANTERNS.find(l => l.id === p.lantern) || LANTERNS[0];
  const lx = Math.round(p.x + Math.cos(p.aim) * 7), ly = Math.round(p.y - 1 + Math.sin(p.aim) * 4);
  pxRect(ctx, lx - 2, ly - 4, 5, 7, '#0b0810');
  pxRect(ctx, lx - 1, ly - 5, 3, 1, '#3b3546');
  pxRect(ctx, lx - 1, ly - 3, 3, 4, L.glass);
  pxRect(ctx, lx, ly - 2, 1, 2, '#ffffff');
  pxRect(ctx, lx - 1, ly + 2, 3, 1, '#3b3546');
  return { x: lx, y: ly };
}
function drawPlayer(ctx, p) {
  const blink = p.inv > 0 && Math.floor(p.inv * 20) % 2 === 0;
  shadow(ctx, p.x, p.y + 7, 5);
  const alpha = p.statuses.invis ? 0.35 : blink ? 0.4 : 1;
  const frame = p.moving ? Math.floor(p.anim * 8) % 2 : 0;
  const bob = p.moving && frame ? -1 : 0;
  const behind = Math.sin(p.aim) < -0.3;
  ctx.save(); ctx.globalAlpha = alpha;
  if (behind) drawLantern(ctx, p);
  drawSpr(ctx, 'player', frame, p.x, p.y + bob, { flip: p.facing < 0, flash: p.dashT > 0 && Math.random() < 0.3 });
  if (!behind) drawLantern(ctx, p);
  ctx.restore();
  if (p.guardUp) { ctx.save(); ctx.globalAlpha = 0.5 + 0.2 * Math.sin(Render.time * 6); pxRing(ctx, p.x, p.y, 11, '#7fd8e6'); ctx.restore(); }
  for (const o of orbitalPositions(p)) {
    pxRect(ctx, o.x - 2, o.y - 2, 4, 4, '#f29c38'); pxRect(ctx, o.x - 1, o.y - 1, 2, 2, '#fff2a8');
  }
}

const SIDE_SPRITES = { rat: 1, grub: 1, grubling: 1, eel: 1 };
function drawEnemy(ctx, e) {
  const spr = e.boss ? e.B.spr : e.D.spr;
  const S = SPR[spr];
  if (!S) return;
  const yy = e.y - e.z;
  if (e.alpha > 0.05) shadow(ctx, e.x, e.y + S.h / 2 - 1, Math.max(4, e.r * (e.z > 0 ? 0.8 : 1)));
  if (e.spawning) return;
  const fr = Math.floor(e.anim * (e.D.anim || 5)) % S.frames.length;
  let flip = false;
  if (SIDE_SPRITES[e.type]) flip = Math.cos(e.facing) < 0;
  else if (!e.boss) flip = Math.cos(angTo(e.x, e.y, run.player.x, run.player.y)) < 0 && e.ai !== 'turret';
  const windBlink = e.wind > 0 && Math.sin(Render.time * 40) > 0;
  const o = { flip, flash: e.flash > 0 || (windBlink && !e.boss), alpha: e.alpha };
  if (e.boss && e.wind > 0) { o.tint = '#e0574a'; o.tintA = 0.25 + 0.2 * Math.sin(Render.time * 30); }
  if (e.frozen > 0) { o.tint = '#9fe0ff'; o.tintA = 0.55; }
  else if (o.tint) { }
  else if (e.statuses.burn && Math.sin(Render.time * 12) > 0.3) { o.tint = '#f29c38'; o.tintA = 0.35; }
  else if (e.statuses.poison && Math.sin(Render.time * 9) > 0.3) { o.tint = '#8fd35a'; o.tintA = 0.35; }
  else if (e.statuses.chill) { o.tint = '#7fd8e6'; o.tintA = 0.3; }
  if (e.elite && e.alpha > 0.3) {
    const col = ELITE_MODS[e.mod].col;
    ctx.save(); ctx.globalAlpha = 0.45 + 0.25 * Math.sin(Render.time * 6);
    const sil = sprTint(spr, col)[fr];
    const dx = Math.round(e.x - S.w / 2), dy = Math.round(yy - S.h / 2);
    for (const [ox, oy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      if (flip) { ctx.save(); ctx.translate(dx + S.w + ox, dy + oy); ctx.scale(-1, 1); ctx.drawImage(sil, 0, 0); ctx.restore(); }
      else ctx.drawImage(sil, dx + ox, dy + oy);
    }
    ctx.restore();
  }
  drawSpr(ctx, spr, fr, e.x, yy, o);
  // front shield
  if (e.D && e.D.shield) {
    const a = e.shieldDown ? e.facing + 1.3 : e.facing, r = e.r + 4;
    ctx.save();
    ctx.strokeStyle = '#0b0810'; ctx.lineWidth = 4;
    ctx.beginPath(); ctx.arc(e.x, yy, r, a - 0.9, a + 0.9); ctx.stroke();
    ctx.strokeStyle = e.type === 'knight' ? '#c0c8d0' : '#8a5a34'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(e.x, yy, r, a - 0.85, a + 0.85); ctx.stroke();
    ctx.restore();
  }
  // health bar
  if (!e.boss && e.hp < e.maxHp && e.alpha > 0.4) {
    const w = Math.max(10, e.r * 2 + 2);
    bar(ctx, e.x - w / 2, yy - S.h / 2 - 4, w, 1, e.hp / e.maxHp, e.elite ? ELITE_MODS[e.mod].col : '#d04b3c');
  }
}

function drawPlayerBullets(ctx) {
  for (const b of run.bullets) {
    if (b.kind === 'comet') {
      pxCircle(ctx, b.x, b.y, b.r + 1, '#0b0810');
      pxCircle(ctx, b.x, b.y, b.r, '#7fd8e6');
      pxCircle(ctx, b.x, b.y, b.r - 1.5, '#ffffff');
    } else if (b.kind === 'shard') {
      pxRect(ctx, b.x - 1, b.y - 1, 2, 2, '#f6cf57');
    } else {
      const r = b.r + (b.crit ? 0.6 : 0);
      pxCircle(ctx, b.x, b.y, r + 0.7, b.crit ? '#fff2a8' : '#b5571f');
      pxCircle(ctx, b.x, b.y, r - 0.3, b.crit ? '#ffffff' : '#f29c38');
      pxRect(ctx, b.x - 1, b.y - 1, 2, 2, '#fff2a8');
    }
  }
}
function drawEnemyBullets(ctx) {
  for (const b of run.ebullets) {
    const col = bulletColor(b);
    if (b.kind === 'bone') {
      const a = b.t * 14;
      const dx = Math.cos(a) * 3, dy = Math.sin(a) * 3;
      ctx.save(); ctx.strokeStyle = '#0b0810'; ctx.lineWidth = 4; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(b.x - dx, b.y - dy); ctx.lineTo(b.x + dx, b.y + dy); ctx.stroke();
      ctx.strokeStyle = '#e8e4dc'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(b.x - dx, b.y - dy); ctx.lineTo(b.x + dx, b.y + dy); ctx.stroke();
      ctx.restore();
      continue;
    }
    pxCircle(ctx, b.x, b.y, b.r + 1, '#0b0810');
    pxCircle(ctx, b.x, b.y, b.r, col);
    pxRect(ctx, b.x - 1, b.y - 1, 2, 2, b.kind === 'void' ? '#140a1c' : '#ffffff');
  }
}

// enemy eyes in the darkness
function drawEyes(ctx) {
  const p = run.player;
  const lr = pLight(p);
  for (const e of run.enemies) {
    if (e.alpha < 0.5 || e.spawning || e.boss) continue;
    const d = dist(e.x, e.y, p.x, p.y);
    const a = clamp((d - lr * 0.55) / (lr * 0.4), 0, 1);
    if (a <= 0) continue;
    const S = SPR[e.D.spr];
    const ey = Math.round(e.y - e.z - S.h * 0.18);
    const col = e.elite ? ELITE_MODS[e.mod].col : '#ff5a4a';
    ctx.save(); ctx.globalAlpha = a * (0.7 + 0.3 * Math.sin(Render.time * 3 + e.x));
    pxRect(ctx, e.x - 3, ey, 2, 1, col); pxRect(ctx, e.x + 1, ey, 2, 1, col);
    ctx.restore();
  }
}

// ---------------------------------------------------------------------
// Light and shadows
// ---------------------------------------------------------------------
function collectLights() {
  const p = run.player, room = run.room;
  const L = [];
  const fl = 1 + Math.sin(Render.time * 13) * 0.015 + Math.sin(Render.time * 7.3) * 0.012;
  if (!p.dead) L.push({ x: p.x, y: p.y - 2, r: pLight(p) * fl, a: 1, col: '#f2a040', ga: 0.10 });
  for (let i = 0; i < run.bullets.length && i < 40; i++) { const b = run.bullets[i]; L.push({ x: b.x, y: b.y, r: b.kind === 'comet' ? 30 : 16, a: 0.7 }); }
  for (let ty = 1; ty < RH - 1; ty++) for (let tx = 1; tx < RW - 1; tx++) {
    if (room.grid[ty][tx] === T.BRAZIER) { const c = tileCenter(tx, ty); L.push({ x: c.x, y: c.y - 4, r: 72 * (1 + Math.sin(Render.time * 9 + tx) * 0.04), a: 0.95, col: '#f29c38', ga: 0.12 }); }
  }
  for (const f of run.fx) {
    if (f.type === 'fire') L.push({ x: f.x, y: f.y, r: 24, a: 0.6, col: '#f29c38', ga: 0.08 });
    else if (f.type === 'explosion' && f.t < 0.3) L.push({ x: f.x, y: f.y, r: f.r * 2.5, a: 1, col: '#f6cf57', ga: 0.25 });
    else if (f.type === 'beam' && f.t > f.warm) L.push({ x: f.x + Math.cos(f.ang) * 60, y: f.y + Math.sin(f.ang) * 60, r: 90, a: 0.6 });
    else if (f.type === 'bomb') L.push({ x: f.x, y: f.y, r: 14, a: 0.5 });
  }
  for (const o of room.objects) {
    if (o.gone) continue;
    if (o.type === 'relic' || o.type === 'shopitem') L.push({ x: o.x, y: o.y - 8, r: 34, a: 0.7 });
    else if (o.type === 'merchant') L.push({ x: o.x + 9, y: o.y, r: 80, a: 0.9, col: '#f6cf57', ga: 0.08 });
    else if (o.type === 'trapdoor') L.push({ x: o.x, y: o.y, r: 50, a: 0.8, col: '#c57ae0', ga: 0.1 });
    else if (o.type === 'shrine' && o.uses > 0) L.push({ x: o.x, y: o.y - 8, r: 60, a: 0.8, col: o.kind === 'pact' || o.kind === 'blood' ? '#d04b3c' : '#7fd8e6', ga: 0.08 });
    else if (o.type === 'chest' && !o.open) L.push({ x: o.x, y: o.y, r: 22, a: 0.5 });
  }
  for (const e of run.enemies) {
    if (e.boss) L.push({ x: e.x, y: e.y, r: 70, a: 0.55, col: '#c57ae0', ga: 0.06 });
    else if (e.type === 'spark' || e.type === 'slag') L.push({ x: e.x, y: e.y, r: 26, a: 0.7, col: '#f29c38', ga: 0.1 });
  }
  for (const b of run.ebullets) if (L.length < 120) L.push({ x: b.x, y: b.y, r: 12, a: 0.45 });
  for (const k of room.pickups) if (k.type === 'coin' || k.type === 'coin5' || k.type === 'cons') L.push({ x: k.x, y: k.y, r: 10, a: 0.4 });
  if (run.flashLight && run.flashLight.t > 0) L.push({ x: run.flashLight.x, y: run.flashLight.y, r: (run.flashLight.r || 150) * run.flashLight.t * 2, a: 1, col: '#fff2a8', ga: 0.2 * run.flashLight.t });
  return L;
}
function drawLighting(ctx, sx, sy) {
  const room = run.room, biome = biomeOf(run.depth), p = run.player;
  let amb = biome.dark + Math.min(0.08, Math.max(0, run.depth - 5) * 0.015);
  if (room.cleared && room.type !== 'boss') amb *= 0.84;
  if (p.oil <= 0 && room.combat) amb = Math.min(0.94, amb + 0.06);
  const lc = Render.lctx;
  lc.globalCompositeOperation = 'source-over';
  lc.clearRect(0, 0, W, H);
  lc.fillStyle = 'rgba(5,3,9,' + amb.toFixed(3) + ')';
  lc.fillRect(0, 0, W, H);
  lc.globalCompositeOperation = 'destination-out';
  const lights = collectLights();
  for (const L of lights) {
    const x = L.x + sx, y = L.y + sy, r = Math.max(4, L.r);
    const g = lc.createRadialGradient(x, y, r * 0.12, x, y, r);
    g.addColorStop(0, 'rgba(0,0,0,' + L.a + ')');
    g.addColorStop(0.55, 'rgba(0,0,0,' + (L.a * 0.6) + ')');
    g.addColorStop(1, 'rgba(0,0,0,0)');
    lc.fillStyle = g;
    lc.fillRect(x - r, y - r, r * 2, r * 2);
  }
  lc.globalCompositeOperation = 'source-over';
  ctx.drawImage(Render.light, 0, 0);
  // additive warm glow
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  for (const L of lights) {
    if (!L.col) continue;
    const x = L.x + sx, y = L.y + sy, r = L.r * 0.8;
    const g = ctx.createRadialGradient(x, y, 0, x, y, r);
    g.addColorStop(0, L.col); g.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.globalAlpha = L.ga || 0.1;
    ctx.fillStyle = g; ctx.fillRect(x - r, y - r, r * 2, r * 2);
  }
  ctx.restore();
  // vignette
  const vg = ctx.createRadialGradient(W / 2, H / 2 + 14, H * 0.35, W / 2, H / 2 + 14, H * 0.95);
  vg.addColorStop(0, 'rgba(0,0,0,0)'); vg.addColorStop(1, 'rgba(0,0,0,0.55)');
  ctx.fillStyle = vg; ctx.fillRect(0, 0, W, H);
}

// interaction hint
function drawPrompt(ctx) {
  const o = run.focus;
  if (!o) return;
  let title = '', desc = '', verb = 'Interact', col = TEXT_COLORS.w, extra = '';
  switch (o.type) {
    case 'relic': title = RELICS[o.id].name; desc = RELICS[o.id].desc; verb = 'Take'; col = TEXT_COLORS.y; if (o.group) extra = '^dYou can only choose one.'; break;
    case 'chest': title = o.gold ? 'Golden chest' : 'Chest'; desc = o.gold ? 'Needs a key. Holds precious treasures.' : 'Who knows what it holds.'; verb = 'Open'; break;
    case 'shopitem': {
      const it = o.item;
      if (it.kind === 'cons') { title = CONS[it.id].name; desc = CONS[it.id].desc; }
      else if (it.kind === 'heal') { title = 'Salve'; desc = 'Heals ^y40%^w of max health.'; }
      else if (it.kind === 'key') { title = 'Key'; desc = 'Opens golden chests and treasure rooms.'; }
      else { title = RELICS[it.id].name; desc = RELICS[it.id].desc; col = TEXT_COLORS.y; }
      verb = 'Compra (' + priceOf(o) + ')';
      break;
    }
    case 'shrine':
      if (o.kind === 'blood') { title = 'Blood Altar'; desc = 'Offer ^r15^w max health in exchange for a ^brare^w or better perk.'; verb = 'Offer'; }
      else if (o.kind === 'fortune') { title = 'Wishing Fountain'; desc = 'Throw in ^y5^w coins and hope. (Uses left: ' + o.uses + ')'; verb = 'Throw'; }
      else if (o.kind === 'fountain') { title = 'Pure Spring'; desc = run.player.curses.length ? 'Purify a curse for ^y20^w coins.' : 'Fully restores you, once.'; verb = 'Drink'; }
      else { title = 'Forbidden Idol'; desc = 'Gain a ^yrelic^w. Receive a ^pcurse^w.'; verb = 'Accept'; }
      if (o.uses <= 0) { desc = '^dThe power is spent.'; verb = ''; }
      col = TEXT_COLORS.p;
      break;
    case 'trapdoor': title = 'Trapdoor'; desc = 'Descend to the next depth.'; verb = 'Descend'; break;
  }
  const w = 168;
  const lines = Font.wrap(desc, w - 12);
  const h = 22 + lines.length * 10 + (extra ? 10 : 0) + (verb ? 12 : 0);
  let x = clamp(o.x - w / 2, 4, W - w - 4), y = o.y - 26 - h;
  if (y < RY + 2) y = o.y + 22;
  panel(ctx, x, y, w, h);
  Font.draw(ctx, title, x + w / 2, y + 7, { align: 'center', color: col });
  lines.forEach((l, i) => Font.draw(ctx, l, x + 6, y + 19 + i * 10, { color: '#d8d0c0' }));
  let yy = y + 19 + lines.length * 10;
  if (extra) { Font.draw(ctx, extra, x + 6, yy, {}); yy += 10; }
  if (verb) {
    const kw = keycap(ctx, x + 6, yy + 1, Input.lastDevice === 'pad' ? 'X' : 'E');
    Font.draw(ctx, verb, x + 10 + kw, yy + 2, { color: TEXT_COLORS.y });
  }
}
