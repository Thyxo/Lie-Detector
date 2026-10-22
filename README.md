# MindTrace – løgnedetektor med magnet

iPhone-app (SwiftUI) til close-up-magi. Tilskueren får en magnetisk mønt (med magnet i), tager hænderne om ryggen og gemmer den i hånden – eller ikke. Telefonen føres hen over hånden og siger **Sandt** eller **Falsk** (med lyd).

**Standard: magnet = Falsk** (kan vendes i menuen).

---

## 1. Installér (SideStore)
Kilde-URL:
```
https://raw.githubusercontent.com/Thyxo/Lie-Detector/main/sidestore/source.json
```
SideStore → **Sources** → **+** → indsæt URL → MindTrace → **Install**. Nye versioner kommer som opdateringer. Virker også i AltStore. IPA'er ligger også under *Releases*.

## 2. Tilstande
| Tilstand | Hvad sker der |
|---|---|
| **Normal** | Start ("Sandt eller falsk?") → tryk → *Tænker* 2–4 s → **Sandt** (turkis) / **Falsk** (rød) + lyd. Tryk = tilbage. |
| **Hemmelig vibration** | Sort skærm eller dit eget billede (fx skærmbillede af hjemmeskærmen). Tryk → scanning → vibration: **1 = Falsk, 2 = Sandt**, 1 s pause, *5 gange* eller *til du trykker*. Tryk igen stopper. |

## 3. Brug
1. Hold telefonen væk fra hånden og tryk (grundmåling tages lige før).
2. Før **toppen** af telefonen hen over hånden (1–3 cm), mens den tænker.
3. Volumenknapper vinder altid: **op = Sandt, ned = Falsk** (lille vibration bekræfter).

## 4. Hemmelig menu
**Åbn:** 5 hurtige tryk i øverste højre hjørne. **Færdig** lukker (første sekund ignoreres).

- **Sensor**: live-bjælke med udslag, top og tærskel-streg + "MAGNET"/"ingen magnet".
- **Følsomhed**: tærskel i µT (standard **40 µT**, knap "Standard"). Under tærsklen = ingen magnet.
- **Lær min mønt (anbefalet)**: 1) 3 s uden mønt, 2) 3 s hen over hånden med mønt → tærsklen sættes automatisk.
- **Afgørelse**: automatisk sensor, *magnet betyder* Falsk/Sandt, volumenknapper.
- **Tilstand**: Normal / Hemmelig vibration, gentagelse, billede, test-vibrationer.
- **Udseende og lyd**: dansk/English, lyd til/fra (+ test), 6 skrifter (Bungee, Rubik Mono, Lilita, Luckiest Guy, Pixel, Gill Sans).
- **Avanceret**: Tænker-tid, målinger i træk, målemetode, standard-svar, diskret prik, log.
- **Panik**: hold nederste venstre hjørne på startskærmen i ¾ s (eller PANIK-knappen).

## 5. Sådan virker detektionen
- Rå magnetometer (100 Hz) + telefonens orientering. Feltet regnes om til rummets akser, så **drejning af telefonen ikke giver udslag** – kun en magnet tæt på gør.
- Telefonens egen magnetisme (bias) læres løbende og **fryses under scanning**, så iOS' kalibrering ikke kan "æde" magneten.
- Udslag = største afvigelse fra grundmålingen, holdt i 3 målinger i træk (enkelt-spikes ignoreres) → sammenlignes med tærsklen.
- Logikken er dækket af automatiske tests (`ios/MindTraceTests`), som kører på GitHub før hver build.

## 6. Projekt
```
ios/project.yml             XcodeGen (app + logik-tests)
ios/MindTrace/              App (SwiftUI)
  Detector.swift, Vec3.swift  Detektion (ren logik, testet)
  MagnetSensor.swift          Core Motion
  Engine.swift                Forløb, afgørelse, lær-min-mønt, vibration
  RootView.swift              Skærme
  SecretPanel.swift           Hemmelig menu
  Resources/Fonts, Sounds     Skrifter (OFL/Apache) og lyde
ios/MindTraceTests/         Tests
.github/workflows/ipa.yml   Test → build → release → SideStore-kilde
demo/                       Klikbar web-demo af udseendet
```
Push til `dev` = test + build (ingen release). Push til `main` = release + ny SideStore-version.

## 7. Kendt / test på telefonen
- Lyden spiller også med lydløs-knappen slået til. Volumen nulstilles til 75 % for at kunne mærke knaptryk.
- Lydene er hentet fra myinstants.com (brugeruploadede) – tjek selv rettigheder til offentlige shows.
