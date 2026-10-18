// Canvas scanner. Reacts only to real readings passed via setData();
// with no data it is drawn static and dim. The sweep shows scan *time*, not a measurement.

export class Scanner {
  constructor(canvas) {
    this.c = canvas; this.g = canvas.getContext('2d');
    this.data = null; this.level = 0; this.sweep = null; this.raf = 0;
    const fit = () => { const r = canvas.getBoundingClientRect(); const dpr = Math.min(window.devicePixelRatio || 1, 3); canvas.width = Math.max(1, r.width * dpr); canvas.height = Math.max(1, r.height * dpr); };
    fit(); window.addEventListener('resize', fit);
  }
  setData(d) { this.data = d; }
  startSweep(ms) { this.sweep = { t0: performance.now(), ms }; }
  stopSweep() { this.sweep = null; }
  start() { const loop = () => { this.draw(); this.raf = requestAnimationFrame(loop); }; loop(); }

  draw() {
    const { c, g } = this, W = c.width, H = c.height, cx = W / 2, cy = H / 2, R = Math.min(W, H) / 2 - 4 * (W / 300);
    g.clearRect(0, 0, W, H);
    const d = this.data, live = !!d;
    const target = live && d.delta != null ? Math.min(1, Math.abs(d.delta) / (d.threshold * 2)) : 0;
    this.level += (target - this.level) * 0.12;     // gradual response
    const cyan = '31,209,255';

    // tick ring
    g.save(); g.translate(cx, cy);
    for (let i = 0; i < 120; i++) {
      const a = (i / 120) * Math.PI * 2 - Math.PI / 2, major = i % 10 === 0;
      const r1 = R * (major ? 0.9 : 0.94);
      g.strokeStyle = `rgba(${cyan},${live ? (major ? 0.55 : 0.22) : 0.1})`;
      g.lineWidth = W / 300 * (major ? 1.6 : 1);
      g.beginPath(); g.moveTo(Math.cos(a) * r1, Math.sin(a) * r1); g.lineTo(Math.cos(a) * R, Math.sin(a) * R); g.stroke();
    }
    // inner rings
    g.strokeStyle = `rgba(${cyan},${live ? 0.16 : 0.07})`; g.lineWidth = W / 300;
    [0.78, 0.62].forEach((k) => { g.beginPath(); g.arc(0, 0, R * k, 0, Math.PI * 2); g.stroke(); });

    // level arc (|Δ| relative to 2× threshold), threshold marker at 50%
    const start = -Math.PI / 2, lw = W / 300 * 6;
    g.lineCap = 'round';
    g.strokeStyle = 'rgba(255,255,255,0.05)'; g.lineWidth = lw;
    g.beginPath(); g.arc(0, 0, R * 0.84, 0, Math.PI * 2); g.stroke();
    if (live && this.level > 0.003) {
      const over = this.level >= 0.5;
      g.strokeStyle = over ? `rgba(${cyan},1)` : `rgba(${cyan},0.75)`;
      g.shadowColor = `rgba(${cyan},0.8)`; g.shadowBlur = over ? W / 300 * 14 : W / 300 * 6;
      g.beginPath(); g.arc(0, 0, R * 0.84, start, start + this.level * Math.PI * 2); g.stroke();
      g.shadowBlur = 0;
    }
    if (live && d.threshold) {
      const a = start + Math.PI; g.strokeStyle = 'rgba(255,255,255,0.45)'; g.lineWidth = W / 300 * 1.5;
      g.beginPath(); g.moveTo(Math.cos(a) * R * 0.79, Math.sin(a) * R * 0.79); g.lineTo(Math.cos(a) * R * 0.89, Math.sin(a) * R * 0.89); g.stroke();
    }
    // instability: amber jitter segment
    if (live && d.unstable) {
      g.strokeStyle = 'rgba(255,181,71,0.8)'; g.lineWidth = W / 300 * 2;
      const j = (performance.now() / 120) % (Math.PI * 2);
      g.beginPath(); g.arc(0, 0, R * 0.7, j, j + 0.5); g.stroke();
    }
    // scan sweep (timer)
    if (this.sweep) {
      const p = Math.min(1, (performance.now() - this.sweep.t0) / this.sweep.ms);
      const a = start + p * Math.PI * 2 * 2;
      const grad = g.createConicGradient ? g.createConicGradient(a - 0.6, 0, 0) : null;
      if (grad) {
        grad.addColorStop(0, `rgba(${cyan},0)`); grad.addColorStop(0.095, `rgba(${cyan},0.18)`); grad.addColorStop(0.1, `rgba(${cyan},0)`);
        g.fillStyle = grad; g.beginPath(); g.arc(0, 0, R * 0.6, 0, Math.PI * 2); g.fill();
      }
      g.strokeStyle = `rgba(${cyan},0.9)`; g.lineWidth = W / 300 * 1.5;
      g.beginPath(); g.moveTo(0, 0); g.lineTo(Math.cos(a) * R * 0.6, Math.sin(a) * R * 0.6); g.stroke();
      g.strokeStyle = `rgba(${cyan},0.6)`; g.lineWidth = W / 300 * 2;
      g.beginPath(); g.arc(0, 0, R * 0.97, start, start + p * Math.PI * 2); g.stroke();
    }
    g.restore();
  }
}
