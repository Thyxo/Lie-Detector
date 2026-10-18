// Secret performer control. Completely separate from detection: it can only
// decide the *reveal* (which sound is played) — never sensor values.

export const RevealMode = Object.freeze({ AUTOMATIC: 'AUTOMATIC', FORCE_MAGNET: 'FORCE_MAGNET', FORCE_NONE: 'FORCE_NONE' });

const KEY = 'mindtrace.settings.v1';
const DEFAULTS = {
  enabled: true, mode: RevealMode.AUTOMATIC, sticky: false, quickCue: false,
  gesture: 'hold-title', threshold: 25, duration: 2.5, consecutive: 5,
  series: false, stage: false, volume: 80,
};

export function loadSettings() {
  try { return { ...DEFAULTS, ...JSON.parse(localStorage.getItem(KEY) || '{}') }; }
  catch { return { ...DEFAULTS }; }
}
export function saveSettings(s) { try { localStorage.setItem(KEY, JSON.stringify(s)); } catch { /* private mode */ } }

export class PerformerControl {
  constructor(settings) { this.s = settings; }
  get active() { return this.s.enabled; }

  /**
   * Decide what to reveal. `cue` = optional quick-cue override for this scan.
   * Returns { source: 'performer'|'sensor', verdict } — or null when automatic.
   */
  resolveForced(cue) {
    if (!this.s.enabled) return null;
    const mode = cue || this.s.mode;
    if (mode === RevealMode.FORCE_MAGNET) return { source: 'performer', verdict: 'magnet', mode };
    if (mode === RevealMode.FORCE_NONE) return { source: 'performer', verdict: 'none', mode };
    return null;
  }
  /** Consume one-shot force after a reveal. */
  consume(cueUsed) {
    if (cueUsed) return;
    if (!this.s.sticky && this.s.mode !== RevealMode.AUTOMATIC) { this.s.mode = RevealMode.AUTOMATIC; saveSettings(this.s); }
  }
}

/**
 * Secret gesture detection. Two variants:
 *  - hold-title: press & hold the title ≥1500 ms without moving >12 px
 *  - corner-taps: 4 taps in the bottom-right corner zone within 1600 ms
 */
export function installGesture({ title, corner, getType, onOpen }) {
  let holdTimer = null, sx = 0, sy = 0;
  const cancelHold = () => { clearTimeout(holdTimer); holdTimer = null; };
  title.addEventListener('pointerdown', (e) => {
    if (getType() !== 'hold-title') return;
    sx = e.clientX; sy = e.clientY;
    cancelHold();
    holdTimer = setTimeout(() => { holdTimer = null; if (navigator.vibrate) navigator.vibrate(15); onOpen(); }, 1500);
  });
  title.addEventListener('pointermove', (e) => { if (holdTimer && Math.hypot(e.clientX - sx, e.clientY - sy) > 12) cancelHold(); });
  ['pointerup', 'pointercancel', 'pointerleave'].forEach((t) => title.addEventListener(t, cancelHold));
  title.addEventListener('contextmenu', (e) => e.preventDefault());

  let taps = [];
  corner.addEventListener('pointerdown', (e) => {
    if (getType() !== 'corner-taps') return;
    e.preventDefault();
    const now = performance.now();
    taps = taps.filter((t) => now - t < 1600); taps.push(now);
    if (taps.length >= 4) { taps = []; onOpen(); }
  });
}
