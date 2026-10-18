// Magnet detection from measured magnetometer data only.
// Uses change in |B| relative to a calibrated baseline (orientation-tolerant,
// because Earth's field magnitude is roughly constant when the phone rotates).

export const Verdict = Object.freeze({ MAGNET: 'magnet', NONE: 'none', INSUFFICIENT: 'insufficient' });

const mean = (a) => a.reduce((s, v) => s + v, 0) / (a.length || 1);
const std = (a) => { const m = mean(a); return Math.sqrt(mean(a.map((v) => (v - m) ** 2))); };

export class Detector {
  constructor(opts = {}) {
    this.alpha = opts.alpha ?? 0.25;               // EMA smoothing
    this.threshold = opts.threshold ?? 25;         // µT change required
    this.consecutive = opts.consecutive ?? 5;      // samples in a row above threshold
    this.minScanSamples = opts.minScanSamples ?? 15;
    this.calSamples = opts.calSamples ?? 40;
    this.maxCalStd = opts.maxCalStd ?? 3;          // µT; calibration rejected if noisier
    this.reset();
  }

  reset() {
    this.filtered = null;
    this.baseline = null;
    this.recent = [];        // raw magnitudes for stability
    this._cal = null;
    this._scan = null;
  }

  /** Feed one real reading. Returns derived values for display. */
  push(magnitude) {
    this.filtered = this.filtered == null ? magnitude : this.filtered + this.alpha * (magnitude - this.filtered);
    this.recent.push(magnitude);
    if (this.recent.length > 20) this.recent.shift();

    if (this._cal) {
      this._cal.samples.push(magnitude);
      if (this._cal.samples.length >= this.calSamples) this._finishCal();
    }
    const delta = this.baseline == null ? null : this.filtered - this.baseline;
    if (this._scan && delta != null) this._scanStep(Math.abs(delta));
    return { filtered: this.filtered, delta, stability: this.stability() };
  }

  stability() { return this.recent.length < 5 ? null : std(this.recent); }
  isUnstable() { const s = this.stability(); return s != null && s > this.maxCalStd * 2; }

  calibrate() {
    return new Promise((resolve) => {
      this._cal = { samples: [], resolve };
    });
  }
  _finishCal() {
    const { samples, resolve } = this._cal;
    this._cal = null;
    const s = std(samples);
    if (s > this.maxCalStd) return resolve({ ok: false, reason: `Field unstable during calibration (σ ${s.toFixed(1)} µT). Hold still, away from metal.`, std: s });
    this.baseline = mean(samples);
    this.filtered = this.baseline;
    resolve({ ok: true, baseline: this.baseline, std: s });
  }
  cancelCalibration() { if (this._cal) { this._cal.resolve({ ok: false, reason: 'Cancelled' }); this._cal = null; } }

  /** Start a timed scan. Resolves with a sensor-based result. */
  scan(durationMs) {
    return new Promise((resolve) => {
      if (this.baseline == null) return resolve({ verdict: Verdict.INSUFFICIENT, reason: 'Not calibrated' });
      this._scan = { samples: 0, run: 0, bestRun: 0, peak: 0, resolve };
      this._scanTimer = setTimeout(() => this._finishScan(), durationMs);
    });
  }
  _scanStep(absDelta) {
    const sc = this._scan;
    sc.samples++;
    sc.peak = Math.max(sc.peak, absDelta);
    sc.run = absDelta >= this.threshold ? sc.run + 1 : 0;
    sc.bestRun = Math.max(sc.bestRun, sc.run);
  }
  _finishScan(cancel = false) {
    const sc = this._scan; if (!sc) return;
    this._scan = null; clearTimeout(this._scanTimer);
    if (cancel) return sc.resolve({ verdict: Verdict.INSUFFICIENT, reason: 'Cancelled' });
    if (sc.samples < this.minScanSamples) {
      return sc.resolve({ verdict: Verdict.INSUFFICIENT, reason: `Only ${sc.samples} readings during scan`, samples: sc.samples });
    }
    const verdict = sc.bestRun >= this.consecutive ? Verdict.MAGNET : Verdict.NONE;
    sc.resolve({ verdict, peakDelta: sc.peak, bestRun: sc.bestRun, samples: sc.samples, threshold: this.threshold });
  }
  cancelScan() { this._finishScan(true); }
}
