# Neon Breaker

Arcade brick breaker in Flutter (Android, iOS, web) by Kallistesoft.

- Endless levels. A level is cleared when every breakable brick is gone; steel bricks don't count.
- Every level looks different: 16 brick shapes (the first cycle hand-ordered, later cycles shuffled, Waves and Scatter regenerated per level), 7 color themes, random mirroring.
- Difficulty rises each level: faster ball, smaller paddle, tougher bricks (up to 5 hits), explosive and steel bricks, swaying formations, more bad capsules.
- Every 5th level is a boss: Sentinel, Hive, Prism, Titan, then again with more HP and aggression. Boss shots stun the paddle.
- Game over sends you back to the level after the last boss you beat.
- Between levels, an intermission screen shows the results and a 300×250 ad slot (`AdSlot` in `lib/ui/overlays.dart`); `AdService.showInterstitial()` runs when the player continues. Both are placeholders until AdMob / a web portal SDK is wired in.

## Layout

- `lib/game/` — pure simulation: `levels.dart` (level generator, bosses), `world.dart` (physics, power-ups, boss AI), `model.dart`.
- `lib/ui/` — rendering (`world_painter.dart`), screens and overlays.
- `lib/services/` — ads, sound, saved progress.
- `tools/make_sfx.py` — synthesizes every sound effect into `assets/sfx` (no third-party audio).

## Develop

```sh
flutter test
flutter run -d chrome
```

Every push to `main` deploys the web version to https://breaker.kallistesoft.ca (GitHub Pages, `.github/workflows/web.yml`).
