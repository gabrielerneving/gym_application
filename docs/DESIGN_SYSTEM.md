# Repicore Design System

The visual language for the whole app. Every screen is built from the pieces
described here. If you are about to type a raw hex colour, a magic padding
number or a `Duration(milliseconds: 250)`, stop and use a token.

---

## 1. The look

**One UI 9 / modern Android premium.** Concretely:

- **Floating, detached chrome.** The nav bar is a narrow frosted pill that hovers
  over the content. Nothing is docked to a screen edge.
- **Generous rounding.** Cards are 24px, sheets 32px, anything interactive and
  small is a full pill.
- **Deep, calm surfaces.** Backgrounds are near-black (dark palettes) or
  near-white (light palettes), never pure. Elevation is expressed with a
  slightly lighter surface + a hairline border + a very soft shadow — not with
  heavy drop shadows.
- **One accent, used sparingly.** The primary gradient appears on *one* hero
  element per screen. Everything else is neutral with coloured text/icons.
- **Big confident numbers.** Metrics are large, tight-tracked and tabular.
  Labels are small, quiet and sentence case.
- **Everything moves — briefly.** Content fades and lifts in, taps dip, numbers
  roll up. Nothing bounces for longer than ~0.5s.

---

## 2. Imports

One import gets you the whole kit plus the tokens:

```dart
import '../widgets/ui/ui.dart';
```

(from `lib/widgets/…` it is `import 'ui/ui.dart';`)

Colours always come from the theme provider, which lives outside the UI barrel:

```dart
import '../providers/theme_provider.dart';
...
final t = ref.watch(themeProvider);   // ConsumerWidget / ConsumerState
```

Screens are `ConsumerWidget` / `ConsumerStatefulWidget` (flutter_riverpod).

---

## 3. Tokens

### Colour — `AppColors` (`lib/theme/app_theme.dart`)

Surface hierarchy, lowest → highest:
`backgroundDark` → `background` → `surface` (inset *inside* a card) →
`card` (default raised surface) → `elevated` (sheets, menus, nav bar).

| Token | Use |
|---|---|
| `primary`, `primaryLight`, `accent` | the brand accent + gradient stops |
| `onPrimary` | text/icons on top of `primary`. **Never hardcode `Colors.white`** — half the palettes are light. |
| `text`, `textSecondary`, `textTertiary` | three levels of text |
| `outline`, `divider` | hairlines |
| `success`, `warning`, `error` | semantic states |
| `primaryWash`, `primaryWashOutline` | soft tinted fills for selected states |
| `isDark` | branch on this instead of checking a theme *index* |

Helpers: `primaryGradient`, `primaryGradientDiagonal`, `chartFillGradient`,
`shadowSoft`, `shadowMedium`, `shadowFloating`, `shadowPrimaryGlow`,
`dataPalette` / `dataColor(i)` (categorical chart colours), `deltaColor(n)`,
`glass`, `scrim`.

> The old code branched on `themeIndex == 1` to decide whether to show a
> gradient. That is gone — every palette now has a real gradient and a real
> `isDark` flag. Delete any `themeIndex ==` checks you find.

### Spacing — `AppSpacing`
`xxs 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · xxxl 32 · huge 40`
- `AppSpacing.screenH` (20) — the horizontal gutter every screen uses.
- `AppSpacing.navBarClearance` — bottom padding that clears the floating nav bar.

### Radius — `AppRadius`
`xs 8 · sm 12 · md 16 · lg 20 · card 24 · xl 28 · xxl 32 · sheet 32 · pill 999`

### Motion — `AppMotion`
`instant 120ms · fast 200ms · normal 320ms · slow 480ms · lazy 700ms`
Curves: `standard` (default), `enter`, `exit`, `spring` (overshoots — clamp any
value you feed into `withOpacity` or `Color.lerp`).

### Type — `AppType`
`display(t)` · `title(t)` · `heading(t)` · `body(t)` · `secondary(t)` ·
`caption(t)` · `overline(t)` · `metric(t, size:)` · `mono(t)` · `button(t)`.
`metric` and `mono` use tabular figures so numbers do not jitter.

### Formatting — `AppFormat`
`weight(82.5)→"82.5"` · `compact(12500)→"12.5k"` · `duration(95)→"1h 35m"` ·
`delta(-2.5,'kg')→"−2.5 kg"` · `relativeDate(d)→"3 days ago"` · `dayMonth(d)`.

---

## 4. Components (`lib/widgets/ui/`)

### Page shells

```dart
AppScaffold(
  title: 'Statistics',
  subtitle: 'Last 30 days',            // optional
  actions: [AppIconButton(icon: Icons.settings, onPressed: ...)],
  headerBottom: AppSegmented(...),     // optional pinned row under the title
  onRefresh: _load,                    // optional pull-to-refresh
  floatingAction: AppFab(...),         // optional, sits above the nav bar
  children: [ ... ],                   // padded list  — OR —
  slivers: [ ... ],                    // raw slivers
  body: LoadingState(),                // replaces the scroll body entirely
)
```
Gives you the collapsing large title, the frosted toolbar, ambient glow,
status-bar styling and nav-bar clearance. The back chevron appears
automatically when the route can pop.

`AppPage(child: ...)` — bare shell (no header) for full-bleed screens.

### Surfaces
- `AppCard(child:, onTap:, gradient:, inset:, padding:, radius:)`
- `GlassSurface(child:)` — frosted; only where content scrolls underneath.
- `IconBadge(icon:, filled:, color:)` — the rounded icon square in a row.
- `AppTile(icon:, title:, subtitle:, onTap:, trailing:, bare:)` — nav row.
- `AppTileGroup(children: [AppTile(bare: true), ...])` — settings-style group.

### Controls
- `AppButton(label:, onPressed:, icon:, expand:, loading:, size:)` plus
  `.secondary` `.outline` `.ghost` `.danger` named constructors.
- `AppIconButton(icon:, onPressed:, tooltip:, active:)`
- `AppFab(icon:, label:, onPressed:)`
- `AppSegmented<T>(value:, segments: [AppSegment(value:, label:)], onChanged:)`
- `AppChip(label:, selected:, onTap:)`
- `AppBadge(label:, color:, icon:)`
- `DeltaBadge(delta:, percent:, unit:, compact:, higherIsWorse:)`

### Data display
- `StatTile(label:, value:, unit:, icon:, delta:, sparkline:, highlight:)`
- `StatGrid(children: [...])` — 2-up responsive grid, staggers its children.
- `MetricRow(label:, value:)` — label/value line inside a card.
- `StatBar(label:, value:, max:, valueLabel:, targetMin:, targetMax:)`
- `Sparkline(values:, color:)` — tiny trend line, no axes.
- `ProgressRing(progress:, label:, sublabel:)`
- `WeekStrip(days: [bool], labels: [...])`

### Motion
- `FadeSlideIn(index: i, child: ...)` — entrance; wrap list items with their index.
- `Pressable(onTap:, child:, scale:, haptic:)` — use instead of bare `GestureDetector`.
- `CountUp(value:, decimals:, style:)` — animated numbers.
- `SwapTransitionBox(value: key, child: ...)` — cross-fade on value change.

### Feedback
- `EmptyState(icon:, title:, message:, actionLabel:, onAction:)` — always offer an action.
- `LoadingState(message:)`, `ErrorState(message:, onRetry:)`
- `SkeletonBox`, `SkeletonCard` — shimmer placeholders, preferred over a lone spinner.
- `AppSnack.show(context, ref, 'Saved', isError: false)`

### Modals
```dart
AppSheet.show<T>(context: context, ref: ref, title: '…', builder: (c) => …);
AppSheet.actions(context: context, ref: ref, actions: [SheetAction(...)]);
final ok = await AppDialog.confirm(context: context, ref: ref,
    title: 'Delete workout?', message: '…', confirmLabel: 'Delete', destructive: true);
AppDialog.info(context: context, ref: ref, title: '…', message: '…');
```
**No raw `AlertDialog` / `showModalBottomSheet` / `SnackBar` anywhere.**

---

## 5. Data & analytics

`lib/services/analytics_service.dart` is pure: it takes
`List<WorkoutSession>` and returns value objects. `lib/providers/analytics_provider.dart`
fetches the history **once** and caches it.

```dart
final async = ref.watch(trainingDataProvider);
return async.when(
  loading: () => const LoadingState(),
  error: (e, _) => ErrorState(message: '…', onRetry: () => ref.invalidate(workoutSessionsProvider)),
  data: (data) {
    data.sessions;                       // List<WorkoutSession>, newest first
    data.exerciseNames;                  // sorted by recency
    data.progressFor('Bench Press');     // ExerciseProgress
    data.personalBests;                  // List<PersonalBest>
    data.streak;                         // StreakInfo (weekly)
    data.muscleBalance;                  // List<MuscleBalance> vs 10–20 sets/week
    data.insights;                       // plain-language observations
    data.weeklyVolume;                   // last 12 weeks of tonnage
    data.lastSevenDays;                  // List<bool>
    data.programs;                       // List<ProgramUsage>
    data.summaryFor(StatsPeriod.month);  // PeriodSummary incl. vs previous period
  },
);
```

Shared period selection: `ref.watch(statsPeriodProvider)` (`StatsPeriod.week/month/quarter/year/all`,
each with `.label`, `.longLabel`, `.range()`).

Refresh after a workout is saved: `ref.invalidate(workoutSessionsProvider)`.

**Do not** add new `DatabaseService` methods that read the whole session
collection per exercise — that N+1 pattern is what the analytics layer replaces.

Definitions used consistently everywhere:
- *working set* = `!isWarmUp && weight > 0 && reps > 0`
- *volume / tonnage* = Σ `weight × reps` over working sets
- *estimated 1RM* = Epley, only from sets of ≤ 12 reps
- *week* starts Monday

---

## 6. Rules

1. **Never hardcode a colour.** Read from `t`. `Colors.white` is only correct
   via `t.onPrimary`.
2. **Never branch on the theme index.** Use `t.isDark`.
3. **No `AlertDialog`, `SnackBar`, `showModalBottomSheet`, `AppBar`, or
   `BottomNavigationBar`.** Use the kit.
4. **Do not change any screen's or widget's public constructor signature.**
   Other screens navigate to yours; keep the parameters exactly as they are.
5. **Do not edit shared files you do not own** — `lib/theme/**`,
   `lib/widgets/ui/**`, `lib/services/analytics_service.dart`,
   `lib/providers/**`, `lib/main.dart`, `lib/pages/main_screen.dart`.
6. **The old one-off widgets are gone** — `stat_card.dart`,
   `gradient_button.dart` and `gradient_text.dart` were deleted once nothing
   referenced them. Use `StatTile`, `AppButton` and the `AppScaffold` title.
   Do not reintroduce screen-local copies of kit components; if something is
   missing and will be used twice, add it to `lib/widgets/ui/`.
7. **`withValues(alpha: …)`, not `withOpacity`.** `withOpacity` is deprecated
   and loses precision; the whole codebase was migrated. It is available on
   every Flutter version this project's SDK constraint allows.
8. **Keep `fl_chart` API calls as they are** (v0.69) — restyle the chart data
   and decorations, do not migrate to a different chart API.
9. **Every list gets `FadeSlideIn(index: i, …)`.** Every tap target gets
   haptics (via `Pressable`/`AppButton`, which do it for you).
10. **Every screen handles all four states**: loading (skeleton), empty
    (`EmptyState` with an action), error (`ErrorState` with retry), content.
11. Scroll views inside the four main tabs must end with
    `AppSpacing.navBarClearance` of bottom padding (`AppScaffold` does it).
12. Prefer `Icons.*_rounded` variants — they match the soft geometry.
