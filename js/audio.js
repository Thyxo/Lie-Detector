// Two synthesized cues via Web Audio API. No audio files.
// A = magnet: deep, resonant "thrum" (~340 ms).
// B = no magnet: bright, short double tick (~260 ms).

export class AudioEngine {
  constructor() { this.ctx = null; this.master = null; this.volume = 0.8; }

  /** Must be called inside a user gesture (iOS requirement). */
  unlock() {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return false;
    if (!this.ctx) {
      this.ctx = new AC();
      this.comp = this.ctx.createDynamicsCompressor();
      this.comp.threshold.value = -10; this.comp.ratio.value = 4;
      this.master = this.ctx.createGain();
      this.master.gain.value = this.volume;
      this.master.connect(this.comp).connect(this.ctx.destination);
      // Silent buffer primes the iOS audio pipeline.
      const b = this.ctx.createBuffer(1, 1, 22050);
      const s = this.ctx.createBufferSource(); s.buffer = b; s.connect(this.ctx.destination); s.start(0);
    }
    if (this.ctx.state !== 'running') this.ctx.resume().catch(() => {});
    return true;
  }
  get ready() { return !!this.ctx; }
  setVolume(v) { this.volume = Math.max(0, Math.min(1, v)); if (this.master) this.master.gain.value = this.volume; }

  _env(g, t, a, peak, d) {
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(peak, t + a);
    g.gain.exponentialRampToValueAtTime(0.0001, t + d);
  }
  _ensure() { if (!this.ctx) return false; if (this.ctx.state !== 'running') this.ctx.resume().catch(() => {}); return true; }

  playMagnet() {
    if (!this._ensure()) return false;
    const c = this.ctx, t = c.currentTime + 0.02, D = 0.34;
    // Body: falling low sine + square harmonic through low-pass (audible on phone speaker)
    const o1 = c.createOscillator(); o1.type = 'sine';
    o1.frequency.setValueAtTime(196, t); o1.frequency.exponentialRampToValueAtTime(147, t + D);
    const o2 = c.createOscillator(); o2.type = 'square';
    o2.frequency.setValueAtTime(392, t); o2.frequency.exponentialRampToValueAtTime(294, t + D);
    const lp = c.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.setValueAtTime(1400, t); lp.frequency.exponentialRampToValueAtTime(500, t + D); lp.Q.value = 6;
    const g1 = c.createGain(); this._env(g1, t, 0.012, 0.9, D);
    const g2 = c.createGain(); this._env(g2, t, 0.012, 0.22, D * 0.85);
    o1.connect(g1).connect(this.master);
    o2.connect(lp).connect(g2).connect(this.master);
    // Attack click for definition
    const o3 = c.createOscillator(); o3.type = 'triangle'; o3.frequency.value = 1180;
    const g3 = c.createGain(); this._env(g3, t, 0.003, 0.25, 0.05);
    o3.connect(g3).connect(this.master);
    [o1, o2, o3].forEach((o) => { o.start(t); o.stop(t + D + 0.05); });
    return true;
  }

  playClear() {
    if (!this._ensure()) return false;
    const c = this.ctx, t = c.currentTime + 0.02;
    const tick = (start, f) => {
      const o = c.createOscillator(); o.type = 'sine'; o.frequency.setValueAtTime(f, start);
      const h = c.createOscillator(); h.type = 'sine'; h.frequency.setValueAtTime(f * 2.01, start);
      const g = c.createGain(); this._env(g, start, 0.004, 0.55, 0.11);
      const gh = c.createGain(); this._env(gh, start, 0.004, 0.12, 0.07);
      o.connect(g).connect(this.master); h.connect(gh).connect(this.master);
      o.start(start); h.start(start); o.stop(start + 0.14); h.stop(start + 0.14);
    };
    tick(t, 1318.5);          // E6
    tick(t + 0.13, 987.8);    // B5 — descending, "clear / empty"
    return true;
  }
}
