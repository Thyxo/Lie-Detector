# MINDTRACE — Magnetic Field Analysis

A mobile web app used as a prop for close-up magic and mentalism. It is an entertainment illusion, not a scientific instrument.

## Browser limitation (read this first)
- **iPhone / iOS Safari has no raw magnetometer data.** WebKit does not implement the Generic Sensor API `Magnetometer`. Every iOS browser runs on WebKit, so Chrome on iOS doesn't have it either. No website can read the iPhone's magnetometer in µT.
- `deviceorientation` / `webkitCompassHeading` give a compass **direction**, not field strength. MINDTRACE deliberately does not use them.
- On iPhone the app therefore shows **Sensor Unavailable**, displays `—` instead of readings, and never plays a verdict sound in AUTOMATIC mode. **Performer-controlled reveals work fully.**
- Real automatic detection: **Chrome on Android** → `chrome://flags` → enable **Generic Sensor Extra Classes** → open the site over HTTPS.
- `?sim=1` = test mode with a permanent red **SIMULATED DATA** banner. Tap the banner or press `M` to toggle a fake magnet.

## Structure
```
index.html            UI + secret menu markup
styles.css            Design (dark, cyan, portrait, safe areas)
js/sensor.js          Sensor adapter: capability probe, permissions, validation, watchdog; simulator (explicit, ?sim=1)
js/detector.js        EMA filter, baseline calibration (rejects unstable data), |Δ|B|| threshold + N consecutive samples
js/audio.js           Web Audio: A = deep falling thrum (340 ms), B = bright descending double tick (260 ms)
js/performer-mode.js  Settings (localStorage), reveal override, secret gesture
js/scanner.js         Canvas dial: reacts only to real data; static when there is none
js/app.js             State machine and wiring
vercel.json           Headers (Permissions-Policy magnetometer=self)
```

## Usage (performer)
1. Open the site and tap **START**. This unlocks audio, starts the sensor and calibrates automatically if a sensor is available.
2. **Secret menu:** hold the **MINDTRACE** title for 1.5 s, or switch to "4 taps in the bottom-right corner".
3. Modes: **AUTOMATIC** / **FORCE MAGNET** / **FORCE NO MAGNET**. A forced mode applies once by default; turn on "Keep forced mode" to make it stick.
4. **Quick cue** (optional): hold SCAN ≥0.6 s to force magnet, or tap normally to use the current mode. You never need to open the menu mid-show.
5. **Series mode** runs a second scan automatically (left hand, then right hand). **Stage view** hides the raw data panel.
6. You can also reset, recalibrate, adjust threshold, duration and samples, set the volume and test both sounds.

## Source separation
- A reveal is always `{ source: 'sensor' | 'performer', verdict, sensorResult }`.
- A performer reveal never changes the sensor values. The status line shows **Analysis Complete** instead of "Magnetic Field Detected", plus a nearly invisible dot. The menu log shows the source.
- Each reveal has a sequence number, and a sound plays only if `playedSeq !== seq`. That means exactly one sound per reveal.
- With no sensor data and no forced mode, no sound plays and the result reads "No sensor data".

## Local run
```
python3 -m http.server 8000      # http://localhost:8000  (localhost counts as a secure context)
```
To test on a phone you need HTTPS, for example a Vercel preview or `npx localtunnel`.

## Hosting
Static files with no build step. Vercel: import the repo, Framework "Other", no build command. Every push to `main` deploys automatically.

## Test plan — iPhone 15 Pro (Safari)
| # | Step | Expected |
|---|------|----------|
| 1 | Open over HTTPS | Start sheet: HTTPS yes, Magnetometer API **no**, explanation |
| 2 | START, then SCAN (AUTOMATIC) | "Sensor Unavailable", `—`, **no sound**, "No sensor data" |
| 3 | Hold title 1.5 s | Secret menu opens. A short tap does nothing |
| 4 | Test A / Test B (mute switch off, volume up) | Two clearly different sounds through the speaker |
| 5 | FORCE MAGNET → Back → SCAN | Scanning ~2.5 s → sound A once → "Analysis Complete" / "Positive" |
| 6 | SCAN again | Mode has reverted to AUTOMATIC → no sound (unless sticky) |
| 7 | Quick cue on: hold SCAN | Sound A. Normal tap = current mode |
| 8 | Series mode | Two scans in a row, one sound each |
| 9 | Lock screen / switch app, come back | Audio resumes on the next tap |
| 10 | Add to Home Screen | Fullscreen, portrait |

Android Chrome (flag on): calibrate (hold still) → SCAN while moving a neodymium magnet within 1–3 cm of the top of the phone → "Magnetic Field Detected". Adjust the threshold to match your magnet.

## Verified (headless Chromium, iPhone 15 Pro viewport)
- No JS errors. All buttons and the secret gesture work.
- Without the sensor API: Sensor Unavailable, no readings, no automatic verdict sound.
- Forced reveal: correct sound path, labelled "performer", sensor values untouched, one-shot reverts to AUTOMATIC.
- Simulator: calibration → "No Significant Change" (peak Δ 0.2 µT) and with a magnet → "Magnetic Field Detected" (Δ 76 µT).

## Needs testing on real hardware
- Sound level and character on the iPhone speaker. Note the iPhone **mute switch / Action button** silences Web Audio.
- Real detection on an Android device with your magnet (threshold, distance, metal in the room).
- Secret gesture ergonomics with one hand.

## Privacy
No account, no server data, no tracking, no camera, microphone or GPS. Only settings are stored in localStorage.
