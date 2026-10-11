'use strict';
// =====================================================================
//  Audio sintetizzato: effetti sonori e musica generativa (WebAudio)
// =====================================================================

const Sound = {
  ctx: null, master: null, sfxGain: null, musicGain: null, noiseBuf: null,
  unlocked: false, last: Object.create(null),

  unlock() {
    if (this.ctx) { if (this.ctx.state === 'suspended') this.ctx.resume(); return; }
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    try {
      this.ctx = new AC();
    } catch (e) { return; }
    const c = this.ctx;
    this.master = c.createGain(); this.master.gain.value = 0.9;
    const comp = c.createDynamicsCompressor();
    comp.threshold.value = -14; comp.ratio.value = 4;
    this.master.connect(comp); comp.connect(c.destination);
    this.sfxGain = c.createGain(); this.sfxGain.connect(this.master);
    this.musicGain = c.createGain(); this.musicGain.connect(this.master);
    const len = c.sampleRate * 1.0;
    this.noiseBuf = c.createBuffer(1, len, c.sampleRate);
    const d = this.noiseBuf.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    this.unlocked = true;
    this.applyVolumes();
    Music.init();
    if (Music.pending !== null) { const p = Music.pending; Music.pending = null; Music.play(p); }
  },
  applyVolumes() {
    if (!this.ctx) return;
    const s = Save.data.settings;
    this.sfxGain.gain.value = s.sfx * 0.8;
    this.musicGain.gain.value = s.music * 0.55;
  },

  tone(type, f0, f1, dur, vol, o = {}) {
    const c = this.ctx, t = c.currentTime + (o.delay || 0);
    const osc = c.createOscillator(), g = c.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(Math.max(20, f0), t);
    if (f1 !== f0) osc.frequency.exponentialRampToValueAtTime(Math.max(20, f1), t + dur);
    if (o.detune) osc.detune.value = o.detune;
    const atk = o.attack || 0.005;
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(vol, t + atk);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    let node = osc;
    if (o.lp) { const f = c.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = o.lp; node.connect(f); node = f; }
    node.connect(g); g.connect(o.dest || this.sfxGain);
    osc.start(t); osc.stop(t + dur + 0.05);
  },
  noise(dur, vol, o = {}) {
    const c = this.ctx, t = c.currentTime + (o.delay || 0);
    const src = c.createBufferSource(); src.buffer = this.noiseBuf;
    src.playbackRate.value = o.rate || 1;
    const f = c.createBiquadFilter();
    f.type = o.type || 'lowpass';
    f.frequency.setValueAtTime(o.f0 || 2000, t);
    if (o.f1) f.frequency.exponentialRampToValueAtTime(o.f1, t + dur);
    f.Q.value = o.q || 0.8;
    const g = c.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(vol, t + (o.attack || 0.005));
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    src.connect(f); f.connect(g); g.connect(o.dest || this.sfxGain);
    src.start(t, Math.random() * 0.5); src.stop(t + dur + 0.05);
  },

  play(name, vol = 1) {
    if (!this.ctx || !this.unlocked || Save.data.settings.sfx <= 0) return;
    const now = this.ctx.currentTime;
    const gap = { shoot: 0.045, hit: 0.035, xp: 0.03, coin: 0.04, enemyShoot: 0.05, kill: 0.04, tick: 0.05 }[name] || 0.02;
    if (this.last[name] && now - this.last[name] < gap) return;
    this.last[name] = now;
    const v = vol;
    switch (name) {
      case 'shoot': this.tone('square', rnd(560, 620), 240, 0.07, 0.035 * v, { lp: 2400 }); this.noise(0.04, 0.03 * v, { type: 'highpass', f0: 3000 }); break;
      case 'hit': this.noise(0.06, 0.12 * v, { type: 'bandpass', f0: 1400, q: 1.5 }); this.tone('triangle', 220, 90, 0.06, 0.08 * v); break;
      case 'crit': this.tone('square', 980, 420, 0.09, 0.06 * v, { lp: 3000 }); this.noise(0.08, 0.14 * v, { type: 'bandpass', f0: 2200 }); break;
      case 'kill': this.noise(0.2, 0.2 * v, { f0: 1200, f1: 150 }); this.tone('sawtooth', 170, 40, 0.18, 0.08 * v, { lp: 900 }); break;
      case 'hurt': this.tone('sawtooth', 320, 60, 0.28, 0.2 * v, { lp: 1400 }); this.noise(0.22, 0.2 * v, { f0: 2500, f1: 300 }); break;
      case 'coin': this.tone('square', 988, 988, 0.06, 0.05 * v, { lp: 4000 }); this.tone('square', 1319, 1319, 0.12, 0.05 * v, { delay: 0.055, lp: 4000 }); break;
      case 'xp': this.tone('sine', rnd(1100, 1400), 1800, 0.06, 0.03 * v); break;
      case 'pickup': this.tone('triangle', 520, 980, 0.12, 0.12 * v); break;
      case 'heal': [523, 659, 784].forEach((f, i) => this.tone('sine', f, f, 0.2, 0.1 * v, { delay: i * 0.06 })); break;
      case 'oil': this.tone('sine', 300, 600, 0.15, 0.1 * v); this.noise(0.1, 0.05 * v, { f0: 800 }); break;
      case 'levelup': [523, 659, 784, 1047, 1319].forEach((f, i) => this.tone('square', f, f, 0.18, 0.05 * v, { delay: i * 0.07, lp: 3000 })); break;
      case 'dash': this.noise(0.16, 0.12 * v, { type: 'bandpass', f0: 600, f1: 3000, q: 1 }); break;
      case 'flare': this.noise(0.5, 0.35 * v, { f0: 4000, f1: 200 }); this.tone('sawtooth', 140, 40, 0.45, 0.15 * v, { lp: 800 }); break;
      case 'explosion': this.noise(0.6, 0.45 * v, { f0: 1600, f1: 80 }); this.tone('sine', 120, 28, 0.5, 0.35 * v); break;
      case 'door': this.tone('square', 180, 110, 0.14, 0.06 * v, { lp: 900 }); this.noise(0.18, 0.1 * v, { f0: 500 }); break;
      case 'lock': this.tone('square', 110, 90, 0.12, 0.08 * v, { lp: 600 }); this.noise(0.1, 0.12 * v, { f0: 900 }); break;
      case 'enemyShoot': this.tone('triangle', 420, 180, 0.09, 0.04 * v); break;
      case 'spawn': this.tone('sine', 180, 620, 0.3, 0.04 * v); break;
      case 'roar': this.tone('sawtooth', 95, 45, 1.1, 0.25 * v, { lp: 700, attack: 0.08 }); this.tone('sawtooth', 98, 47, 1.1, 0.2 * v, { lp: 600, attack: 0.1 }); this.noise(1.0, 0.25 * v, { f0: 700, f1: 120, attack: 0.1 }); break;
      case 'select': this.tone('square', 660, 660, 0.03, 0.04 * v, { lp: 3000 }); break;
      case 'confirm': this.tone('square', 660, 990, 0.09, 0.06 * v, { lp: 3000 }); break;
      case 'deny': this.tone('square', 180, 150, 0.14, 0.07 * v, { lp: 1200 }); break;
      case 'chest': [392, 523, 659, 784].forEach((f, i) => this.tone('triangle', f, f, 0.22, 0.1 * v, { delay: i * 0.05 })); break;
      case 'buy': this.tone('square', 1319, 1319, 0.06, 0.05 * v, { lp: 4000 }); this.tone('square', 1760, 1760, 0.14, 0.05 * v, { delay: 0.06, lp: 4000 }); break;
      case 'curse': this.tone('sawtooth', 220, 105, 0.6, 0.12 * v, { lp: 900 }); this.tone('sawtooth', 233, 110, 0.6, 0.1 * v, { lp: 900 }); break;
      case 'shield': this.tone('sine', 1800, 600, 0.25, 0.1 * v); this.noise(0.2, 0.12 * v, { type: 'highpass', f0: 3000 }); break;
      case 'freeze': this.tone('sine', 2400, 1200, 0.3, 0.08 * v); this.tone('sine', 3000, 1600, 0.3, 0.05 * v, { delay: 0.04 }); break;
      case 'thud': this.tone('sine', 140, 50, 0.18, 0.2 * v); this.noise(0.12, 0.1 * v, { f0: 400 }); break;
      case 'bolt': this.noise(0.15, 0.18 * v, { type: 'highpass', f0: 2000 }); this.tone('sawtooth', 1200, 200, 0.12, 0.05 * v); break;
      case 'tick': this.tone('square', 1200, 1200, 0.02, 0.03 * v); break;
      case 'descend': this.tone('sine', 400, 60, 1.2, 0.15 * v); this.noise(1.2, 0.1 * v, { f0: 1200, f1: 100 }); break;
      case 'warn': this.tone('square', 440, 440, 0.08, 0.04 * v, { lp: 1500 }); break;
      case 'block': this.tone('square', 900, 700, 0.05, 0.05 * v, { lp: 2500 }); this.noise(0.04, 0.06 * v, { type: 'highpass', f0: 2500 }); break;
    }
  }
};

// =====================================================================
//  Musica generativa: drone + arpeggi + percussioni in base all'intensita'
// =====================================================================
const TRACKS = {
  title:  { root: 110.0, scale: [0, 2, 3, 5, 7, 8, 10], tempo: 64, chords: [0, 5, 3, 4], wave: 'sawtooth' },
  crypt:  { root: 110.0, scale: [0, 2, 3, 5, 7, 8, 10], tempo: 84, chords: [0, 3, 5, 4], wave: 'sawtooth' },
  fungus: { root: 82.41, scale: [0, 1, 3, 5, 7, 8, 10], tempo: 76, chords: [0, 1, 5, 3], wave: 'triangle' },
  forge:  { root: 130.8, scale: [0, 2, 3, 5, 7, 8, 11], tempo: 104, chords: [0, 5, 4, 0], wave: 'sawtooth' },
  abyss:  { root: 92.5,  scale: [0, 2, 3, 5, 7, 9, 10], tempo: 66, chords: [0, 2, 5, 4], wave: 'sine' },
  heart:  { root: 123.5, scale: [0, 1, 3, 5, 6, 8, 10], tempo: 96, chords: [0, 1, 4, 3], wave: 'sawtooth' },
};

const Music = {
  track: null, name: null, intensity: 0, pending: null,
  step: 0, nextTime: 0, timer: null, drone: null, delay: null, bus: null, chord: 0,

  init() {
    const c = Sound.ctx;
    this.bus = c.createGain(); this.bus.gain.value = 1; this.bus.connect(Sound.musicGain);
    this.delay = c.createDelay(1.5);
    const fb = c.createGain(); fb.gain.value = 0.38;
    const dl = c.createBiquadFilter(); dl.type = 'lowpass'; dl.frequency.value = 1800;
    this.delay.connect(dl); dl.connect(fb); fb.connect(this.delay); dl.connect(this.bus);
    this.delayIn = c.createGain(); this.delayIn.gain.value = 0.5; this.delayIn.connect(this.delay);
  },
  play(name) {
    if (!Sound.ctx) { this.pending = name; return; }
    if (this.name === name) return;
    this.name = name;
    this.track = TRACKS[name];
    this.stopDrone();
    this.startDrone();
    this.step = 0;
    this.nextTime = Sound.ctx.currentTime + 0.1;
    this.delay.delayTime.value = 60 / this.track.tempo * 0.75;
    if (!this.timer) this.timer = setInterval(() => this.schedule(), 40);
  },
  setIntensity(i) { this.intensity = i; },
  startDrone() {
    const c = Sound.ctx, tr = this.track, t = c.currentTime;
    const g = c.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.13, t + 2.5);
    const f = c.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 380; f.Q.value = 2;
    const lfo = c.createOscillator(); lfo.frequency.value = 0.07;
    const lfoG = c.createGain(); lfoG.gain.value = 160;
    lfo.connect(lfoG); lfoG.connect(f.frequency);
    const oscs = [];
    for (const [mul, det] of [[1, -6], [1, 7], [1.5, 0], [0.5, 3]]) {
      const o = c.createOscillator(); o.type = tr.wave; o.frequency.value = tr.root * mul; o.detune.value = det;
      o.connect(f); o.start(); oscs.push(o);
    }
    f.connect(g); g.connect(this.bus); lfo.start();
    this.drone = { g, oscs, lfo };
  },
  stopDrone() {
    if (!this.drone) return;
    const c = Sound.ctx, d = this.drone, t = c.currentTime;
    d.g.gain.cancelScheduledValues(t);
    d.g.gain.setValueAtTime(Math.max(0.0001, d.g.gain.value), t);
    d.g.gain.exponentialRampToValueAtTime(0.0001, t + 1.2);
    d.oscs.forEach(o => o.stop(t + 1.3)); d.lfo.stop(t + 1.3);
    this.drone = null;
  },
  noteFreq(deg, oct) {
    const sc = this.track.scale;
    const n = sc.length;
    const o = Math.floor(deg / n);
    const semi = sc[((deg % n) + n) % n] + 12 * (o + oct);
    return this.track.root * Math.pow(2, semi / 12);
  },
  schedule() {
    if (!this.track || !Sound.ctx) return;
    const c = Sound.ctx;
    const stepDur = 60 / this.track.tempo / 2 * (this.intensity >= 2 ? 0.8 : 1);
    while (this.nextTime < c.currentTime + 0.15) {
      this.playStep(this.step, this.nextTime);
      this.nextTime += stepDur;
      this.step++;
    }
  },
  playStep(s, t) {
    const c = Sound.ctx, tr = this.track, I = this.intensity;
    if (s % 16 === 0) this.chord = tr.chords[(s / 16 | 0) % tr.chords.length];
    const ch = this.chord;
    // pluck arpeggiato
    const pProb = I === 0 ? 0.3 : I === 1 ? 0.5 : 0.65;
    if (Math.random() < pProb || (s % 8 === 0)) {
      const tones = [0, 2, 4, 7];
      const deg = ch + pick(tones) + (Math.random() < 0.2 ? 1 : 0);
      const f = this.noteFreq(deg, 2 + (Math.random() < 0.3 ? 1 : 0));
      const o = c.createOscillator(), g = c.createGain();
      o.type = I >= 2 ? 'square' : 'triangle'; o.frequency.value = f;
      const vol = I >= 2 ? 0.035 : 0.06;
      g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + 0.008);
      g.gain.exponentialRampToValueAtTime(0.0001, t + 0.6);
      const lp = c.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 1600;
      o.connect(lp); lp.connect(g); g.connect(this.bus); g.connect(this.delayIn);
      o.start(t); o.stop(t + 0.65);
    }
    // basso
    if (I >= 1 && s % 4 === 0) {
      const f = this.noteFreq(ch, 0);
      const o = c.createOscillator(), g = c.createGain(), lp = c.createBiquadFilter();
      o.type = 'sawtooth'; o.frequency.value = f; lp.type = 'lowpass'; lp.frequency.value = 300;
      g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.09, t + 0.01);
      g.gain.exponentialRampToValueAtTime(0.0001, t + 0.35);
      o.connect(lp); lp.connect(g); g.connect(this.bus); o.start(t); o.stop(t + 0.4);
    }
    // cassa
    if (I >= 1 && (s % 4 === 0 || (I >= 2 && s % 4 === 2 && Math.random() < 0.5))) {
      const o = c.createOscillator(), g = c.createGain();
      o.frequency.setValueAtTime(110, t); o.frequency.exponentialRampToValueAtTime(38, t + 0.15);
      g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(I >= 2 ? 0.22 : 0.15, t + 0.005);
      g.gain.exponentialRampToValueAtTime(0.0001, t + 0.2);
      o.connect(g); g.connect(this.bus); o.start(t); o.stop(t + 0.25);
    }
    // charleston
    if (I >= 1 && s % 2 === 1) {
      const src = c.createBufferSource(); src.buffer = Sound.noiseBuf;
      const f = c.createBiquadFilter(); f.type = 'highpass'; f.frequency.value = 6000;
      const g = c.createGain();
      g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(I >= 2 ? 0.05 : 0.03, t + 0.003);
      g.gain.exponentialRampToValueAtTime(0.0001, t + 0.05);
      src.connect(f); f.connect(g); g.connect(this.bus); src.start(t, Math.random() * 0.5); src.stop(t + 0.06);
    }
  },
  stop() {
    this.stopDrone();
    this.name = null; this.track = null;
  }
};
