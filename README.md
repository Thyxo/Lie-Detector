# MindTrace – løgnedetektor med magnet

iPhone-app (SwiftUI) til close-up-magi. Tilskueren får en magnetisk mønt (med magnet i), tager hænderne om ryggen og gemmer den i hånden – eller ikke.

**Spørgsmålet:** "Har du mønten i hånden?" Tilskueren svarer ja eller nej. Telefonen føres hen over hånden og **vibrerer i din hånd**, om mønten er der. Du regner selv ud, om svaret var sandt, og trykker i det skjulte – skærmen viser **Sandt** eller **Falsk** med lyd.

---

## 1. Installér (SideStore)
Kilde-URL:
```
https://raw.githubusercontent.com/Thyxo/Lie-Detector/main/sidestore/source.json
```
SideStore → **Sources** → **+** → indsæt URL → MindTrace → **Install**. Nye versioner kommer som opdateringer. Virker også i AltStore. IPA'er ligger også under *Releases*.

## 2. Forløb (normal tilstand)
1. Startskærm ("Sandt eller falsk?") → **tryk**.
2. Skærmen viser **Tænker** (bliver stående). Før **toppen** af telefonen hen over hånden (1–3 cm).
3. Telefonen vibrerer hvert sekund: **2 bump = mønt**, **1 bump = ingen mønt** (1 lang = ingen sensordata). Har den først fundet mønten, bliver det ved med at være 2 bump.
4. Tilskueren svarer. Du trykker **volumen op = Sandt**, **volumen ned = Falsk** → resultat + lyd. Forkert knap? Tryk den anden.
5. Tryk på resultatet → tilbage til start.

| Mønt? | Tilskueren siger | Du trykker |
|---|---|---|
| 2 bump (mønt) | "Ja" | Op → **Sandt** |
| 2 bump (mønt) | "Nej" | Ned → **Falsk** |
| 1 bump (ingen) | "Ja" | Ned → **Falsk** |
| 1 bump (ingen) | "Nej" | Op → **Sandt** |

## 3. Hemmelig tilstand
Sort skærm eller dit eget billede (fx skærmbillede af hjemmeskærmen). Tryk → samme vibration (2 = mønt, 1 = ingen) hvert sekund → tryk igen for at stoppe. Ingen Sandt/Falsk-skærm.

## 4. Hemmelig menu
**Åbn:** 5 hurtige tryk i øverste højre hjørne. **Færdig** lukker (første sekund ignoreres).

- **Sensor**: live-bjælke med udslag, top og tærskel-streg + "MAGNET"/"ingen magnet".
- **Følsomhed**: tærskel i µT (standard **40 µT**, knap "Standard"). Under tærsklen = ingen mønt.
- **Lær min mønt (anbefalet)**: 1) 3 s uden mønt, 2) 3 s hen over hånden med mønt → tærsklen sættes automatisk.
- **Vibration og tilstand**: Normal/Hemmelig, hvornår vibrationen starter (standard 1 s), test-vibrationer, billede.
- **Udseende og lyd**: English (standard)/dansk, lyd til/fra + lydstyrke (+ test), 6 skrifter, **app-ikon** (Fingeraftryk, Neon, Klassisk – iOS viser en kort besked, når ikonet skiftes).
- **Avanceret**: målinger i træk, målemetode, kalibrering, log.

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
