# 🏋️ Repicore — Workout Tracker

A Flutter app for logging training, tracking strength over time, and seeing
whether the work is actually adding up. Real-time sync across devices via
Firebase.

## ✨ Features

### 🎯 Workout management
- Build custom programs with any number of exercises
- Working sets and warm-up sets tracked separately, everywhere
- Live session timer that survives app restarts
- Previous session values pre-filled as placeholders for fast entry
- Per-set progression (reps and kg) computed against your last session

### 📊 Statistics & analytics
- **Period comparison** — every headline metric shows its change against the
  previous equivalent window (7d vs the 7d before, and so on)
- **Insights** — plain-language observations: volume trends, streaks,
  lagging muscle groups, plateaued lifts, fresh PRs
- **Exercise progression** — estimated 1RM, top weight and volume over time,
  with a trend in kg/week from a least-squares fit
- **Exercise comparison** — two lifts side by side, normalised so different
  absolute loads can actually be compared
- **Personal records** — every lift's best, when it was set, and its curve
- **Muscle balance** — weekly sets per muscle group scored against the
  10–20 sets/week hypertrophy band, with concrete "add N sets" guidance
- **1RM tools** — seven estimation formulas plus a percentage-of-1RM
  training table
- **Consistency** — weekly streaks, a training heatmap, and which weekdays
  you actually show up

### 🎨 Design
- Floating frosted navigation, collapsing large titles, edge-to-edge layout
- Eight palettes, light and dark, all fully themed — no hardcoded colours
- Motion on every state change: staggered entrances, press feedback,
  rolling numbers, spring-animated selection

## 🛠️ Tech stack

**Flutter** · **Riverpod** (state) · **Firebase Auth + Firestore** (backend) ·
**fl_chart** (visualisation) · **shared_preferences** (local settings)

## 🏗️ Architecture

```
lib/
├── main.dart                     # Entry point: Firebase, Riverpod, edge-to-edge
├── theme/
│   ├── app_theme.dart            # AppColors palettes + semantic colour tokens
│   ├── design_tokens.dart        # Spacing, radii, motion, type, formatting
│   └── app_theme_data.dart       # Material ThemeData built from a palette
├── widgets/ui/                   # The UI kit — every screen is built from this
│   ├── ui.dart                   # Barrel: one import gets the whole kit
│   ├── app_scaffold.dart         # Page shell w/ collapsing large title
│   ├── floating_nav_bar.dart     # The floating frosted nav pill
│   ├── app_card.dart             # Surfaces, tiles, icon badges
│   ├── app_buttons.dart          # Buttons, icon buttons, FAB
│   ├── app_chips.dart            # Segmented control, chips, delta badges
│   ├── stat_tile.dart            # Stat tiles, bars, sparklines
│   ├── progress_ring.dart        # Rings and the week strip
│   ├── app_sheet.dart            # Sheets and dialogs
│   ├── feedback.dart             # Empty / loading / error / snack bars
│   ├── section_header.dart
│   └── motion.dart               # FadeSlideIn, Pressable, CountUp
├── models/                       # Workout, Exercise, Session
├── pages/                        # Screens
├── providers/
│   ├── theme_provider.dart
│   ├── workout_provider.dart     # Live workout state machine
│   ├── workout_settings_provider.dart
│   └── analytics_provider.dart   # One cached history fetch for all stats
├── services/
│   ├── database_service.dart     # Firestore access
│   ├── analytics_service.dart    # Pure statistics engine (unit tested)
│   └── auth_service.dart
└── utils/one_rm_calculator.dart
```

### Statistics data flow

`analytics_service.dart` is pure: it takes `List<WorkoutSession>` and returns
value objects. `analytics_provider.dart` fetches the session history **once**
and caches it; every stats screen derives what it needs from that snapshot.

Consistent definitions across the whole app:

- **working set** — `!isWarmUp && weight > 0 && reps > 0`
- **volume / tonnage** — Σ `weight × reps` over working sets
- **estimated 1RM** — Epley, only from sets of ≤ 12 reps
- **week** — starts Monday

## 🎨 Contributing to the UI

Read `docs/DESIGN_SYSTEM.md` before changing anything visual. Short version:
never hardcode a colour, a padding number or an animation duration — every one
of them has a token.

## 🧪 Tests

```bash
flutter test
```

`test/analytics_service_test.dart` covers the statistics engine: working-set
rules, week boundaries, period comparison, streaks, progression, plateau
detection, muscle-group bucketing and formatting.

## 🔒 Security & privacy

- Firestore security rules isolate each user's data
- Firebase Auth for sign-in
- No tracking, no ads

## 📞 Contact

**Gabriel Erneving**
- GitHub: [@gabrielerneving](https://github.com/gabrielerneving)
- Website: https://gabrielerneving.se
