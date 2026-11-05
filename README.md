# MindTrace – the magnet lie detector

An iPhone app (SwiftUI) for close-up mentalism. The spectator gets a magnetic object (e.g. a coin with a magnet inside), puts their hands behind their back and hides it in one hand – or not.

**The question:** "Do you have the magnet in your hand?" The spectator answers yes or no. You move the phone over their hand and it **secretly vibrates in your hand** if the magnet is there. You work out whether they told the truth and reveal it in secret – the screen shows **True** or **False** with a sound.

**Credits:** the original idea behind MindTrace is a digital lie-detector by [Hector Mancha](https://hectormancha.com/hector-mancha-english/). Want to thank him? Send a Steam digital gift card to the Steam account **hdemancha1**. The iPhone version has been redesigned and improved by Daniel Tollan – contact: drytollan@gmail.com.

🌐 **Website:** https://thyxo.github.io/Lie-Detector/

---

## 1. Install
MindTrace is not on the App Store. Install it from a computer with **[iLoader](https://iloader.app)** – free, a normal Apple ID is enough.

1. Download iLoader from **https://iloader.app** (Mac, Windows, Linux).
2. Connect the iPhone with a cable, tap **Trust**, and sign in with your Apple ID in iLoader.
3. Install the IPA: **https://github.com/Thyxo/Lie-Detector/releases/latest/download/MindTrace.ipa**
4. **Or get auto-updates:** install SideStore with iLoader, then add this source in SideStore → **Sources** → **+**:
   ```
   https://raw.githubusercontent.com/Thyxo/Lie-Detector/main/sidestore/source.json
   ```
   New versions arrive as updates. Also works in AltStore.

First launch: turn on **Settings → Privacy & Security → Developer Mode**. With a free Apple ID, apps must be refreshed every 7 days (SideStore can do it for you).

## 2. Routine (Normal mode)
1. Start screen ("True or false?") → **tap**.
2. The screen shows **Thinking** (it stays). Move the **top** of the phone over the hand (1–3 cm).
3. The phone vibrates every second: **2 bumps = magnet**, **1 bump = no magnet** (1 long = no sensor data). Once it has found the magnet, it stays at 2 bumps.
4. The spectator answers. Reveal the result:
   - **Volume buttons:** **volume up = True**, **volume down = False**. Wrong button? Press the other one.
   - **Tap to reveal** (Menu → Display): touch the **top half = True** or the **bottom half = False** with your thumb. An optional faint grey mark on each side shows the middle. The volume buttons still work.
5. Tap the result → back to the start screen.

| Magnet? | Spectator says | You reveal |
|---|---|---|
| 2 bumps (magnet) | "Yes" | Up / top → **True** |
| 2 bumps (magnet) | "No" | Down / bottom → **False** |
| 1 bump (none) | "Yes" | Down / bottom → **False** |
| 1 bump (none) | "No" | Up / top → **True** |

## 3. Secret mode
A black screen or your own image (e.g. a screenshot of your home screen). Tap → the same vibration (2 = magnet, 1 = none) every second → tap again to stop. No True/False screen.

## 4. Secret menu
**Open:** 5 quick taps in the top-right corner (from the start screen). **Done** closes it (taps in the first second are ignored).

The menu is ordered by what you use most:

1. **Sound** – on/off, volume, play True/False.
2. **Vibration** – on/off, strength, when it starts, test 2/1 bumps.
3. **Magnet** – **Learn my magnet** (recommended, works with any magnetic object), live meter, sensitivity (default **40 µT**), secret grey dot (top left = magnet found).
4. **Text on screen** – your own True/False words with a preview and suggestions.
5. **Display** – Normal/Secret, **Tap to reveal** + divider (Normal), background image (Secret).
6. **Appearance** – language (English/Danish), font, app icon.
7. **Advanced** – for troubleshooting only.

Every new guess resets the reading and takes a fresh baseline (~0.3 s after the tap). "Learn my magnet" is kept.

## 5. How detection works
- Raw magnetometer (100 Hz) + the phone's orientation. The field is converted to room axes, so **turning the phone does not trigger it** – only a nearby magnet does.
- The phone's own magnetism (bias) is learned continuously and **frozen while scanning**, so iOS calibration can't "eat" the magnet.
- Signal = largest deviation from the baseline, held for 3 readings in a row (single spikes are ignored) → compared with the threshold.
- The logic is covered by automated tests (`ios/MindTraceTests`) that run on GitHub before every build.

## 6. Project
```
ios/project.yml               XcodeGen (app + tests)
ios/MindTrace/                App (SwiftUI)
  Detector.swift, Vec3.swift    Detection (pure logic, tested)
  MagnetSensor.swift            Core Motion
  Engine.swift                  Flow, reveal, learn my magnet, vibration
  RootView.swift                Screens (incl. tap to reveal)
  SecretPanel.swift             Secret menu
  Resources/Fonts, Sounds       Fonts (OFL/Apache) and sounds
ios/MindTraceTests/           Logic tests (block the build if they fail)
ios/MindTraceUITests/         UI tests on a simulator (informational, never block the build)
site/                         Website (landing page)
.github/workflows/ipa.yml     Test → build → release → SideStore source
.github/workflows/pages.yml   Publishes site/ to GitHub Pages
demo/                         Clickable web demo of the look
```
Push to `dev` = test + build (no release). Push to `main` = release + new SideStore version. Changes in `site/` on `main` update the website automatically.

## 7. Known / test on the phone
- Sound also plays with the silent switch on. Volume is reset to 75 % so button presses can be detected.
- The sounds are from myinstants.com (user uploads) – check the rights yourself for public shows.
- UI tests run in a simulator, which can't press the volume buttons or sense a magnet – always test on a real iPhone.
