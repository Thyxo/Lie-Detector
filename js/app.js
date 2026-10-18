import { RealMagnetometer, SimulatedMagnetometer, SensorStatus, probeCapabilities } from './sensor.js';
import { Detector, Verdict } from './detector.js';
import { AudioEngine } from './audio.js';
import { PerformerControl, RevealMode, loadSettings, saveSettings, installGesture } from './performer-mode.js';
import { Scanner } from './scanner.js';

const $ = (id) => document.getElementById(id);
const SIM = new URLSearchParams(location.search).has('sim');

const settings = loadSettings();
const perf = new PerformerControl(settings);
const audio = new AudioEngine();
const detector = new Detector({ threshold: settings.threshold, consecutive: settings.consecutive });
const sensor = SIM ? new SimulatedMagnetometer() : new RealMagnetometer({ frequency: 40 });
const scanner = new Scanner($('scanner'));

const state = {
  started: false,
  phase: 'init',            // init | calibrating | ready | scanning | result
  calibrated: false,
  calNote: '',
  last: null,               // { magnitude, filtered, delta, stability, real, t }
  busy: false,
  revealSeq: 0,
  playedSeq: 0,
  seriesLeft: 0,
  lastReveal: null,
};

// ---------- Sensor wiring ----------
sensor.on((ev) => {
  if (ev.type === 'reading') {
    const d = detector.push(ev.magnitude);
    state.last = { magnitude: ev.magnitude, ...d, real: ev.real, t: ev.t };
  } else if (ev.type === 'status') {
    if (ev.status !== SensorStatus.ACTIVE) state.last = null;
    if (ev.status === SensorStatus.UNAVAILABLE) { detector.cancelCalibration(); detector.cancelScan(); }
    if (ev.status === SensorStatus.ACTIVE && state.started && !state.calibrated && state.phase !== 'calibrating') calibrate();
    renderSensorInfo();
  }
  render();
});

async function calibrate(attempts = 3) {
  if (sensor.status !== SensorStatus.ACTIVE) { state.calNote = 'Sensor not active — cannot calibrate.'; render(); return false; }
  if (state.phase === 'scanning') return false;
  detector.cancelScan();
  state.phase = 'calibrating'; state.calibrated = false; detector.baseline = null; render();
  for (let i = 0; i < attempts; i++) {
    const r = await detector.calibrate();
    if (r.ok) {
      state.calibrated = true;
      state.calNote = `Baseline ${r.baseline.toFixed(1)} µT (σ ${r.std.toFixed(2)})`;
      state.phase = 'ready'; render(); renderSensorInfo();
      return true;
    }
    state.calNote = r.reason;
    if (sensor.status !== SensorStatus.ACTIVE) break;
  }
  state.phase = 'ready'; render(); renderSensorInfo();
  return false;
}

// ---------- Scan / reveal ----------
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function runScan(cue = null) {
  if (state.busy || !state.started) return;
  state.busy = true;
  audio.unlock();
  const seq = ++state.revealSeq;
  const forced = perf.resolveForced(cue);
  const sensorOk = sensor.status === SensorStatus.ACTIVE && state.calibrated && state.phase !== 'calibrating';
  const durMs = settings.duration * 1000;

  if (!forced && !sensorOk) {
    // No valid data and no performer decision → never play a verdict sound.
    setResult(sensor.status === SensorStatus.ACTIVE ? 'Not calibrated' : 'No sensor data', 'warn');
    state.busy = false; render();
    return;
  }

  state.phase = 'scanning'; setResult(''); render();
  scanner.startSweep(durMs);
  const sensorResult = sensorOk ? await detector.scan(durMs) : (await sleep(durMs), null);
  scanner.stopSweep();

  const reveal = forced
    ? { source: 'performer', verdict: forced.verdict, mode: forced.mode, cue: !!cue, sensorResult }
    : { source: 'sensor', verdict: sensorResult.verdict, sensorResult };
  reveal.at = new Date().toISOString();
  state.lastReveal = reveal;

  if (reveal.verdict === Verdict.INSUFFICIENT) {
    state.phase = 'ready';
    setResult('Insufficient data', 'warn');
  } else {
    if (state.playedSeq !== seq) {           // exactly one sound per reveal
      state.playedSeq = seq;
      reveal.verdict === Verdict.MAGNET ? audio.playMagnet() : audio.playClear();
    }
    state.phase = 'result';
    setResult(reveal.verdict === Verdict.MAGNET ? 'Positive' : 'Negative');
    if (reveal.source === 'performer') perf.consume(reveal.cue);
  }
  renderLog(); renderPerf(); render();

  await sleep(1800);
  state.busy = false;
  if (state.phase === 'result') state.phase = 'ready';
  render();

  if (settings.series && reveal.verdict !== Verdict.INSUFFICIENT) {
    if (state.seriesLeft === 0) state.seriesLeft = 1;     // one more scan for the other hand
    else { state.seriesLeft = 0; return; }
    await sleep(1200);
    if (state.seriesLeft === 1 && !state.busy) runScan();
  } else state.seriesLeft = 0;
}

function resetScan() {
  detector.cancelScan(); scanner.stopSweep();
  state.seriesLeft = 0; state.busy = false;
  state.phase = state.started ? 'ready' : 'init';
  setResult(''); render();
}

// ---------- Rendering ----------
let resultTimer = null;
function setResult(text, cls = '') {
  const el = $('result');
  el.textContent = text; el.style.color = cls === 'warn' ? 'var(--warn)' : '';
  clearTimeout(resultTimer);
  if (text) resultTimer = setTimeout(() => { if (state.phase !== 'scanning') el.textContent = ''; }, 6000);
}

function statusInfo() {
  const s = sensor.status;
  if (!state.started || s === SensorStatus.STARTING) return ['Initializing', 'busy'];
  if (state.phase === 'scanning') return ['Scanning', 'busy'];
  if (state.phase === 'result' && state.lastReveal) {
    const r = state.lastReveal;
    if (r.source === 'sensor') return r.verdict === Verdict.MAGNET ? ['Magnetic Field Detected', 'ok'] : ['No Significant Change', 'ok'];
    return ['Analysis Complete', 'ok'];      // performer reveal: never labelled as a sensor detection
  }
  if (s === SensorStatus.UNAVAILABLE || s === SensorStatus.STALE || s === SensorStatus.IDLE) return ['Sensor Unavailable', s === SensorStatus.STALE ? 'warn' : 'bad'];
  if (state.phase === 'calibrating') return ['Initializing', 'busy'];
  return ['Ready', 'ok'];
}

function render() {
  const [txt, led] = statusInfo();
  $('status-text').textContent = txt;
  $('status-led').className = 'led ' + led;
  $('src-mark').className = 'src-mark' + (state.phase === 'result' && state.lastReveal?.source === 'performer' ? ' perf' : '');

  const L = state.last;
  const live = L && sensor.status === SensorStatus.ACTIVE;
  $('reading').textContent = live ? L.filtered.toFixed(1) : '—';
  $('delta').textContent = live && L.delta != null ? `Δ ${L.delta >= 0 ? '+' : ''}${L.delta.toFixed(1)}` : 'Δ —';
  $('p-mag').textContent = live ? L.magnitude.toFixed(1) + ' µT' : '—';
  $('p-base').textContent = detector.baseline != null ? detector.baseline.toFixed(1) + ' µT' : '—';
  $('p-stab').textContent = live && L.stability != null ? (detector.isUnstable() ? 'Unstable' : 'σ ' + L.stability.toFixed(2)) : '—';
  $('p-rate').textContent = live ? sensor.rate + ' Hz' : '—';

  const btn = $('scan-btn');
  btn.disabled = !state.started || state.busy;
  btn.classList.toggle('running', state.phase === 'scanning');
  document.body.classList.toggle('stage', !!settings.stage);

  scanner.setData(live ? { delta: L.delta, threshold: settings.threshold, unstable: detector.isUnstable(), t: L.t } : null);
}

function capHtml(c) {
  const y = (b) => b ? '<span class="ok">yes</span>' : '<span class="bad">no</span>';
  let h = `<b>Sensor check</b><br>HTTPS: ${y(c.secureContext)}<br>Raw magnetometer API: ${y(c.magnetometerApi)}<br>Permission: ${c.permissionState}<br>`;
  if (SIM) h += '<br><span class="warn">Test mode: values are SIMULATED (tap the red banner or press M to add a fake magnet).</span>';
  else if (!c.magnetometerApi) {
    h += `<br><span class="warn">${c.isIOS ? 'iOS Safari (and every iOS browser, all WebKit) does not expose raw magnetometer data to websites.' : 'This browser does not expose raw magnetometer data.'}</span>
    Automatic detection is unavailable here; the app will show <b>Sensor Unavailable</b> and never invent readings.
    Performer-controlled reveals still work.<br><br>
    To try real detection: Chrome on Android → <b>chrome://flags</b> → enable <b>Generic Sensor Extra Classes</b> → reload over HTTPS.
    Or open <b>?sim=1</b> for a clearly marked simulation.`;
  }
  return h;
}

function renderSensorInfo() {
  const lines = [
    `<b>Source:</b> ${sensor.label}`,
    `<b>Status:</b> ${sensor.status}${sensor.reason ? ' — ' + sensor.reason : ''}`,
    `<b>Calibration:</b> ${state.calibrated ? '<span class="ok">ok</span>' : '<span class="warn">none</span>'} ${state.calNote || ''}`,
  ];
  $('pf-sensor').innerHTML = lines.join('<br>');
}

function renderLog() {
  const r = state.lastReveal;
  if (!r) { $('pf-log').textContent = '—'; return; }
  const sr = r.sensorResult;
  $('pf-log').textContent = [
    `source:  ${r.source === 'performer' ? 'PERFORMER (forced' + (r.cue ? ', quick cue' : '') + ')' : 'SENSOR (automatic)'}`,
    `reveal:  ${r.verdict}`,
    `sensor:  ${sr ? `${sr.verdict}${sr.peakDelta != null ? ` · peak Δ ${sr.peakDelta.toFixed(1)} µT · run ${sr.bestRun} · n=${sr.samples}` : ''}${sr.reason ? ' · ' + sr.reason : ''}` : 'no data'}`,
    `time:    ${r.at}`,
  ].join('\n');
}

// ---------- Performer menu ----------
function renderPerf() {
  $('pf-enabled').checked = settings.enabled;
  document.querySelectorAll('.seg button').forEach((b) => b.classList.toggle('on', b.dataset.mode === settings.mode));
  document.querySelector('.seg').classList.toggle('off', !settings.enabled);
  $('pf-mode-note').textContent = !settings.enabled ? 'Secret control is OFF — every reveal uses the sensor.'
    : settings.mode === RevealMode.AUTOMATIC ? 'Reveal follows the real detector.'
    : `Next reveal is forced${settings.sticky ? ' (stays until changed)' : ' (one time, then AUTOMATIC)'}. Sensor values are untouched.`;
  $('pf-sticky').checked = settings.sticky;
  $('pf-quick').checked = settings.quickCue;
  $('pf-thr').value = settings.threshold; $('pf-thr-v').textContent = settings.threshold;
  $('pf-dur').value = settings.duration; $('pf-dur-v').textContent = settings.duration;
  $('pf-cons').value = settings.consecutive; $('pf-cons-v').textContent = settings.consecutive;
  $('pf-series').checked = settings.series;
  $('pf-stage').checked = settings.stage;
  $('pf-gesture').value = settings.gesture;
  $('pf-vol').value = settings.volume; $('pf-vol-v').textContent = settings.volume;
}
function commit() { saveSettings(settings); detector.threshold = settings.threshold; detector.consecutive = settings.consecutive; audio.setVolume(settings.volume / 100); renderPerf(); render(); }

function openPerf() { renderPerf(); renderSensorInfo(); renderLog(); $('perf').hidden = false; }
function closePerf() { $('perf').hidden = true; }

$('perf-close').addEventListener('click', closePerf);
$('pf-enabled').addEventListener('change', (e) => { settings.enabled = e.target.checked; commit(); });
document.querySelectorAll('.seg button').forEach((b) => b.addEventListener('click', () => { settings.mode = b.dataset.mode; commit(); }));
$('pf-sticky').addEventListener('change', (e) => { settings.sticky = e.target.checked; commit(); });
$('pf-quick').addEventListener('change', (e) => { settings.quickCue = e.target.checked; commit(); });
$('pf-thr').addEventListener('input', (e) => { settings.threshold = +e.target.value; commit(); });
$('pf-dur').addEventListener('input', (e) => { settings.duration = +e.target.value; commit(); });
$('pf-cons').addEventListener('input', (e) => { settings.consecutive = +e.target.value; commit(); });
$('pf-series').addEventListener('change', (e) => { settings.series = e.target.checked; commit(); });
$('pf-stage').addEventListener('change', (e) => { settings.stage = e.target.checked; commit(); });
$('pf-gesture').addEventListener('change', (e) => { settings.gesture = e.target.value; commit(); });
$('pf-vol').addEventListener('input', (e) => { settings.volume = +e.target.value; commit(); });
$('pf-test-a').addEventListener('click', () => { audio.unlock(); audio.playMagnet(); });
$('pf-test-b').addEventListener('click', () => { audio.unlock(); audio.playClear(); });
$('pf-reset').addEventListener('click', () => { resetScan(); closePerf(); });
$('pf-cal').addEventListener('click', async () => { resetScan(); await calibrate(); renderSensorInfo(); });

installGesture({ title: $('title'), corner: $('corner-zone'), getType: () => settings.gesture, onOpen: openPerf });

// ---------- SCAN button (tap; optional hold = quick cue) ----------
let downAt = 0;
const btn = $('scan-btn');
btn.addEventListener('pointerdown', () => { downAt = performance.now(); audio.unlock(); });
btn.addEventListener('pointerup', () => {
  if (!downAt) return;
  const held = performance.now() - downAt; downAt = 0;
  const cue = settings.enabled && settings.quickCue && held >= 600 ? RevealMode.FORCE_MAGNET : null;
  runScan(cue);
});
btn.addEventListener('pointercancel', () => { downAt = 0; });
btn.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); runScan(); } });
btn.addEventListener('contextmenu', (e) => e.preventDefault());

// ---------- Start ----------
let wakeLock = null;
async function keepAwake() { try { if ('wakeLock' in navigator) wakeLock = await navigator.wakeLock.request('screen'); } catch { /* optional */ } }
document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible' && state.started) { keepAwake(); audio.unlock(); } });

$('start-btn').addEventListener('click', async () => {
  audio.unlock();
  audio.setVolume(settings.volume / 100);
  state.started = true;
  $('start').hidden = true;
  keepAwake();
  render();
  await sensor.start();
  renderSensorInfo(); render();
});

if (SIM) {
  const ban = $('sim-banner'); ban.hidden = false; document.body.classList.add('sim');
  const toggle = () => { sensor.extra = sensor.extra ? 0 : 80; ban.textContent = `SIMULATED DATA — TEST MODE — fake magnet ${sensor.extra ? 'ON' : 'OFF'}`; };
  ban.addEventListener('click', toggle);
  window.addEventListener('keydown', (e) => { if (e.key === 'm' || e.key === 'M') toggle(); });
  window.__mindtrace = { sensor, detector, state, settings };
}

probeCapabilities().then((c) => { $('cap-report').innerHTML = capHtml(c); });
renderPerf(); renderSensorInfo(); render();
scanner.start();
