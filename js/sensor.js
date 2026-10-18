// Sensor adapter. Only real magnetometer readings (µT, three axes) are emitted
// as `real: true`. Compass heading (webkitCompassHeading / deviceorientation)
// is intentionally NOT used: it is a direction, not a field strength.

export const SensorStatus = Object.freeze({
  IDLE: 'idle',
  STARTING: 'starting',
  ACTIVE: 'active',
  STALE: 'stale',            // was delivering, stopped updating
  UNAVAILABLE: 'unavailable',
});

/** Capability report — no side effects. */
export async function probeCapabilities() {
  const ua = navigator.userAgent || '';
  const isIOS = /iPhone|iPad|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  const report = {
    secureContext: !!window.isSecureContext,
    magnetometerApi: 'Magnetometer' in window,
    uncalibratedApi: 'UncalibratedMagnetometer' in window,
    permissionState: 'unknown',
    isIOS,
    compassHeadingOnly: 'DeviceOrientationEvent' in window && !('Magnetometer' in window),
  };
  try {
    if (navigator.permissions && navigator.permissions.query) {
      const p = await navigator.permissions.query({ name: 'magnetometer' });
      report.permissionState = p.state;
    }
  } catch { report.permissionState = 'unsupported'; }
  return report;
}

function errReason(e) {
  const name = e && (e.name || (e.error && e.error.name));
  if (name === 'NotAllowedError') return 'Permission denied for magnetometer.';
  if (name === 'NotReadableError') return 'Magnetometer exists but cannot be read.';
  if (name === 'SecurityError') return 'Blocked by security policy (HTTPS / permissions policy).';
  if (name === 'NotSupportedError') return 'Magnetometer not supported on this device.';
  return (e && (e.message || (e.error && e.error.message))) || 'Unknown sensor error.';
}

export class RealMagnetometer {
  constructor({ frequency = 40 } = {}) {
    this.frequency = frequency;
    this.listeners = new Set();
    this.status = SensorStatus.IDLE;
    this.reason = '';
    this.sensor = null;
    this.lastT = 0;
    this.count = 0;
    this.rate = 0;
    this._rateWin = [];
    this._watch = null;
    this.real = true;
    this.label = 'Generic Sensor API · Magnetometer';
  }
  on(fn) { this.listeners.add(fn); return () => this.listeners.delete(fn); }
  _emit(ev) { for (const fn of this.listeners) fn(ev); }
  _setStatus(s, reason = '') {
    if (this.status === s && this.reason === reason) return;
    this.status = s; this.reason = reason;
    this._emit({ type: 'status', status: s, reason });
  }

  async start() {
    if (this.status === SensorStatus.ACTIVE || this.status === SensorStatus.STARTING) return;
    if (!window.isSecureContext) return this._setStatus(SensorStatus.UNAVAILABLE, 'Page is not served over HTTPS.');
    if (!('Magnetometer' in window)) {
      return this._setStatus(SensorStatus.UNAVAILABLE,
        'This browser does not expose raw magnetometer data (Generic Sensor API “Magnetometer” is missing). iOS Safari does not provide it.');
    }
    this._setStatus(SensorStatus.STARTING);
    try {
      if (navigator.permissions && navigator.permissions.query) {
        try {
          const p = await navigator.permissions.query({ name: 'magnetometer' });
          if (p.state === 'denied') return this._setStatus(SensorStatus.UNAVAILABLE, 'Permission denied for magnetometer.');
        } catch { /* query name unsupported — continue */ }
      }
      // eslint-disable-next-line no-undef
      const s = new Magnetometer({ frequency: this.frequency });
      this.sensor = s;
      s.addEventListener('reading', () => this._onReading(s));
      s.addEventListener('error', (e) => {
        this._stopWatch();
        this._setStatus(SensorStatus.UNAVAILABLE, errReason(e));
      });
      s.start();
      this._startWatch();
    } catch (e) {
      this._setStatus(SensorStatus.UNAVAILABLE, errReason(e));
    }
  }

  _onReading(s) {
    const { x, y, z } = s;
    if (![x, y, z].every((v) => typeof v === 'number' && Number.isFinite(v))) return;
    const t = performance.now();
    this._rateWin.push(t);
    while (this._rateWin.length && t - this._rateWin[0] > 1000) this._rateWin.shift();
    this.rate = this._rateWin.length;
    this.lastT = t; this.count++;
    if (this.status !== SensorStatus.ACTIVE) this._setStatus(SensorStatus.ACTIVE);
    this._emit({ type: 'reading', real: true, x, y, z, magnitude: Math.hypot(x, y, z), t });
  }

  _startWatch() {
    const started = performance.now();
    this._stopWatch();
    this._watch = setInterval(() => {
      const now = performance.now();
      if (this.count === 0 && now - started > 4000) {
        this._setStatus(SensorStatus.UNAVAILABLE, 'Sensor started but delivered no readings.');
        this.stop(false);
      } else if (this.count > 0 && now - this.lastT > 1500) {
        this.rate = 0;
        this._setStatus(SensorStatus.STALE, 'Sensor stopped updating.');
      }
    }, 300);
  }
  _stopWatch() { if (this._watch) clearInterval(this._watch); this._watch = null; }

  stop(reset = true) {
    this._stopWatch();
    try { this.sensor && this.sensor.stop(); } catch { /* ignore */ }
    this.sensor = null;
    if (reset) this._setStatus(SensorStatus.IDLE);
  }
}

/**
 * Explicit test-only source (URL ?sim=1). Every reading carries real:false and
 * the UI shows a permanent "SIMULATED DATA" banner. Never used automatically.
 */
export class SimulatedMagnetometer {
  constructor() {
    this.listeners = new Set();
    this.status = SensorStatus.IDLE;
    this.reason = '';
    this.rate = 0;
    this.real = false;
    this.label = 'SIMULATION (test mode)';
    this.extra = 0;   // µT added by the test slider / keyboard
    this._timer = null;
  }
  on(fn) { this.listeners.add(fn); return () => this.listeners.delete(fn); }
  _emit(ev) { for (const fn of this.listeners) fn(ev); }
  async start() {
    this.status = SensorStatus.ACTIVE;
    this._emit({ type: 'status', status: this.status, reason: 'Simulated source' });
    const base = [22, -8, -38];
    this._timer = setInterval(() => {
      const n = () => (Math.random() - 0.5) * 0.8;
      const x = base[0] + n(), y = base[1] + n(), z = base[2] - this.extra + n();
      this.rate = 40;
      this._emit({ type: 'reading', real: false, x, y, z, magnitude: Math.hypot(x, y, z), t: performance.now() });
    }, 25);
  }
  stop() { clearInterval(this._timer); this.status = SensorStatus.IDLE; }
}
