# MindTrace – løgnedetektor med magnet

En iPhone-app (SwiftUI) til close-up-magi. Tilskueren får en magnetisk ting, tager hænderne om ryggen og putter den i hånden – eller lader være. Telefonen føres hen over hånden og siger **Sandt** eller **Falsk**.

**Magnet registreret = Falsk.** Rutinen er "Jeg har ingenting i hånden", så en magnet afslører løgnen.

---

## 1. Skærme
| Skærm | Udseende |
|---|---|
| Start | Sort, "Sandt eller falsk?". Tryk hvor som helst for at starte |
| Tænker | Sort, "Tænker" + pulserende turkis prik, 2–4 s (tilfældig) |
| Sandt | Turkis (#3BC4CA), hvid tekst |
| Falsk | Rød (#FF0000), hvid tekst |

Tryk på Sandt/Falsk → tilbage til start.

## 2. Sådan afgøres det
1. **Volumenknapper** (vinder altid): op = Sandt, ned = Falsk. Virker på start-, Tænker- og resultatskærmen (gælder næste/aktuelle afsløring). Lille vibration bekræfter.
2. **Automatisk sensor**: ægte magnetometer via Core Motion. Grundmåling = median af de sidste 1,5 s før Tænker. Magnet = |B| afviger mindst *tærsklen* i *N målinger i træk*.
3. **Ingen af delene**: standard-svar fra menuen (Sandt).

**Workflow:** hold telefonen væk fra hånden → tryk → før telefonens top hen over hånden (1–3 cm) mens den tænker.

## 3. Hemmelig menu
- **Åbn:** 5 hurtige tryk (inden for 2½ s) i **øverste højre hjørne**.
- **Færdig** lukker (tryk det første sekund ignoreres).
- **Sensor-test:** live µT, grundmåling og Δ fra reference + "MAGNET"-markør – brug den til at finde tærsklen til din magnet.
- Indstillinger: automatisk sensor, volumenknapper, vibration, diskret prik, standard-svar, tærskel, målinger i træk, sensorkilde (kalibreret/rå), Tænker-tid, log.
- **Diskret prik:** næsten usynlig mørkegrå prik øverst på startskærmen, når en volumenknap er trykket (venstre = Sandt, højre = Falsk).
- **Panik:** hold **nederste venstre hjørne** på startskærmen i ¾ s (eller PANIK-knappen). Volumenknapper slås fra, kun ærlig sensor.

## 4. Hent og installér (sideload)

### SideStore-kilde (anbefalet – automatiske opdateringer)
Kilde-URL:
```
https://raw.githubusercontent.com/Thyxo/Lie-Detector/main/sidestore/source.json
```
SideStore → **Sources** → **+** → indsæt URL → MindTrace → **Free/Install**. Nye builds vises som opdateringer i SideStore. Virker også i AltStore.

### Manuelt
Hvert push til `main` bygger en **usigneret IPA** via GitHub Actions (macOS) og lægger den under **Releases**.

- Seneste IPA: `https://github.com/Thyxo/lie-detector/releases/latest/download/MindTrace.ipa`
- Også som artefakt under fanen *Actions*.

**Med AltStore (gratis Apple ID):** installér AltServer på PC/Mac → AltStore på iPhone → hent IPA'en i Filer → AltStore → *My Apps* → **+** → vælg IPA. Fornyes hver 7. dag (AltStore gør det automatisk på samme wifi som AltServer).

**Med Sideloadly:** træk IPA'en ind, log ind med Apple ID, tryk Start.

På iPhone: *Indstillinger → Generelt → VPN og enhedsadministration* → stol på dit Apple ID. iOS 16+: slå **Udviklertilstand** til (*Indstillinger → Anonymitet og sikkerhed*).

## 5. Projekt
```
ios/project.yml           XcodeGen-projekt (Xcode-projektet genereres i CI)
ios/MindTrace/
  MindTraceApp.swift      App-indgang
  RootView.swift          Start / Tænker / Sandt / Falsk + hemmelig zone
  SecretPanel.swift       Hemmelig menu
  Engine.swift            Forløb og afgørelse
  MagnetSensor.swift      Core Motion (kalibreret felt eller rå magnetometer)
  Detector.swift          Grundmåling, tærskel, N i træk
  VolumeButtons.swift     Volumenknapper (skjult lydstyrke-boble)
  AppSettings.swift       Indstillinger (UserDefaults)
.github/workflows/ipa.yml Bygger IPA og release
```
Med Mac: `brew install xcodegen && cd ios && xcodegen generate && open MindTrace.xcodeproj`.

## 6. Kendte begrænsninger / test på telefonen
- Afstand: magnetometeret sidder øverst i iPhonen. En lille neodym-magnet giver typisk stort udslag på 1–3 cm, næsten intet på 10 cm. Find tærsklen i Sensor-test.
- "Kalibreret" kilde: iOS kan langsomt kalibrere et konstant felt væk. Scanningen er kort, så det er sjældent et problem – ellers skift til "Rå".
- Volumenknapper sætter lydstyrken til 50 % for at kunne mærke både op og ned.
- Lydløs-knappen påvirker ikke appen (ingen lyd).
- Appen er ikke kørt på fysisk iPhone af udvikleren – test sensor, volumenknapper og hemmelig menu før første show.
