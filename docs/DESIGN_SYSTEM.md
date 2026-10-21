# Repicore Design System

The visual language for the whole app. Every screen is built from the pieces
described here. If you are about to type a raw hex colour, a magic padding
number or a `Duration(milliseconds: 250)`, stop and use a token.

---

## 1. The look

**One UI 9 / modern Android premium.** Concretely:

- **Floating, detached chrome.** The nav bar is a narrow frosted pill that hovers
  over the content. Nothing is docked to a screen edge. On light palettes the
  pill (and the live-workout capsule) is near-opaque white with a real rim and
  a stronger floating shadow, so it separates from a near-white page.
- **Generous rounding.** Cards are 24px, sheets 32px, anything interactive and
  small is a full pill.
- **Deep, calm surfaces.** Backgrounds are near-black (dark palettes) or
  near-white (light palettes), never pure. Elevation is expressed with a
  slightly lighter surface + a hairline border + a very soft shadow — not with
  heavy drop shadows.
- **One accent, used sparingly.** The primary gradient appears on *one* hero
  element per screen (the CTA: Finish / Resume / Save, or one hero tile).
  Everything else is flat. The nav bar's active tab is a quiet primary wash,
  never the gradient, so it does not compete with the screen's CTA.
- **Neutral surfaces carry the layout; colour carries meaning** (colour roles
  in section 3). Idle, untouched things are neutral, never accent-tinted.
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
| `text`, `textSecondary`, `textTertiary` | three levels of text (contrast targets below) |
| `textHint` | placeholders / hints in input wells (last time's value, "Note", "Search…") — one quiet step under tertiary |
| `outline`, `divider` | hairlines |
| `success`, `warning`, `error` | semantic states (roles below) |
| `onSuccess`, `onError` | text/icons on a solid `success` / `error` fill |
| `successWash`, `successWashOutline` | done tile / chip fill and its border — the success twin of `primaryWash` |
| `successBand` | the faint full-width band behind a finished row |
| `errorWash` | soft fill for destructive tiles / chips |
| `primaryWash`, `primaryWashOutline` | soft tinted fills for selected states |
| `neutralWash` | translucent neutral fill that reads one step up from *any* surface — idle icon tiles, off switch tracks |
| `raised`, `raisedRim`, `shadowRaised` | a control raised off its track (segmented thumb). On dark, raised = **lighter** |
| `isDark` | branch on this instead of checking a theme *index* |

Helpers: `primaryGradient`, `primaryGradientDiagonal`, `chartFillGradient`,
`shadowSoft`, `shadowMedium`, `shadowFloating`, `shadowPrimaryGlow`,
`dataPalette` / `dataColor(i)` (categorical chart colours), `deltaColor(n)`,
`glass`, `scrim`, `AppColors.contrastOn(c)` (near-black or white, whichever
has more contrast on `c`).

**Colour roles.** Every palette is built so these never collide:

| Role | Colour | Never for |
|---|---|---|
| Actions, CTAs, the current selection | `primary` (gradient only on the one hero) | idle / untouched things |
| Done, positive change | `success` | decoration |
| Negative change, destructive actions | `error` | anything merely "important" |
| Warm-up marker | `warning`, sparingly | general emphasis |
| Everything else | neutrals (`text*`, `surface`, `neutralWash`) | — |

Per-palette guarantees (checked with WCAG contrast and CIEDE2000 ΔE):
`primary` vs `error` ΔE00 ≥ 25 and a different hue family — Ember's primary
is an ember orange-red and its error a rose; Blossom's primary is pink and its
error a true red. `primary` vs `success` likewise — Evergreen's success is
lime, not green; Aqua's gradient stays on the blue side of teal.

**Contrast targets.** `text` ≥ 15:1. `textSecondary` ≈ 6.8:1 on `card`.
`textTertiary` is an opaque per-palette colour at ≈ 4.6:1 on `card` (≥ 4:1 on
`surface`/`elevated`): readable for table headers, hints, exercise lists and
descriptions at arm's length, still a clear step below secondary.
Placeholders/hints use `textHint`: ≈ 3.6:1 on `surface` (≥ 3.4:1 on
`elevated` and on a `successBand` row) in every palette — legible at arm's
length, never mistaken for an entered value. Input decoration hints use it. Light palettes' `success` is `#0B8457`
(4.7:1 on white). On the primary gradient, labels and deltas are `onPrimary`,
never semantic green/red (≈ 1.5:1 there).

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
Gives you the collapsing large title, ambient glow, status-bar styling and
nav-bar clearance. The back chevron appears automatically when the route can
pop.

Header behaviour:
- **Root pages** (no back chevron: the tabs) put the large title directly
  under the status bar, on the same row as `actions` — no empty toolbar row
  above it. **Pushed pages** keep a toolbar row (back + actions) with the
  large title under it.
- The large title moves 1:1 with the content and fades; a compact inline
  title fades in once it has gone.
- Collapsed, the header paints the page itself (background plus the same
  ambient glow at the same screen position) and dissolves into the content
  over a 20pt eased fade below its edge. No frosted band, no blur, no hard
  bottom line.

`AppPage(child: ...)` — bare shell (no header) for full-bleed screens.

### Surfaces
- `AppCard(child:, onTap:, gradient:, inset:, padding:, radius:)`
- `GlassSurface(child:)` — frosted; only where content scrolls underneath.
- `IconBadge(icon:, filled:, color:, neutral:)` — the rounded icon square in
  a row. `neutral: true` = `neutralWash` tile with a `text` icon (idle rows);
  `color:` tints it (rows whose icon *means* something); `filled:` = gradient.
- `AppTile(icon:, title:, subtitle:, onTap:, trailing:, bare:, destructive:)` —
  nav row. Its icon tile is **neutral by default**; `iconColor:` tints it;
  `destructive: true` (or `iconColor: t.error`) makes tile *and* title
  error-toned.
- `AppTileGroup(children: [AppTile(bare: true), ...])` — settings-style group.

### Controls
- `AppButton(label:, onPressed:, icon:, expand:, loading:, size:)` plus
  `.secondary` `.outline` `.ghost` `.danger` named constructors. The primary
  variant glows (tightly) at medium/large size only; a `small` primary in a
  toolbar or row has no glow. `radius:` overrides the 16pt corners — pass
  `AppRadius.pill` for a button inside a pill/capsule so the corners nest.
- `AppIconButton(icon:, onPressed:, tooltip:, active:)`
- `AppFab(icon:, label:, onPressed:)`
- `AppSegmented<T>(value:, segments: [AppSegment(value:, label:)], onChanged:)` —
  the selected thumb is `raised` (lighter than the track on dark, white on
  light), so it reads as selected, never as a hole.
- `AppChip(label:, selected:, onTap:)`
- `AppBadge(label:, color:, icon:)`
- `DeltaBadge(delta:, percent:, unit:, compact:, higherIsWorse:, color:, onGradient:)` —
  `success` up / `error` down. `onGradient: true` on the primary gradient
  (renders `onPrimary`); `color:` forces one colour.

### Data display
- `StatTile(label:, value:, unit:, icon:, delta:, sparkline:, highlight:)` —
  `highlight` paints the gradient; everything on it (label, icon, delta)
  turns `onPrimary`.
- `StatGrid(children: [...])` — 2-up responsive grid, staggers its children.
  Adds no padding of its own (it used to inherit the safe-area insets).
- `MetricRow(label:, value:)` — label/value line inside a card.
- `StatBar(label:, value:, max:, valueLabel:, targetMin:, targetMax:)`
- `Sparkline(values:, color:)` — tiny trend line, no axes.
- `ProgressRing(progress:, label:, sublabel:)`
- `WeekStrip(days: [bool], labels: [...])` — a trained day is *done*: flat
  `success` dot with an `onSuccess` check.

### Motion
- `FadeSlideIn(index: i, child: ...)` — entrance; wrap list items with their index.
- `Pressable(onTap:, child:, scale:, haptic:)` — use instead of bare `GestureDetector`.
- `CountUp(value:, decimals:, style:)` — animated numbers.
- `SwapTransitionBox(value: key, child: ...)` — cross-fade on value change.

### Feedback
- `EmptyState(icon:, title:, message:, actionLabel:, onAction:)` — always offer an action.
- `LoadingState(message:)`, `ErrorState(message:, onRetry:)`
- `SkeletonBox`, `SkeletonCard` — shimmer placeholders, preferred over a lone
  spinner. `SkeletonCard` fits its placeholder lines to its height.
- `BalancedText(text, style:, textAlign:)` — short centred copy that wraps into
  even lines instead of leaving an orphan word (CSS `text-wrap: balance`).
  `AppDialog`, `EmptyState` and `ErrorState` use it for title and message.
- `AppSnack.show(context, ref, 'Saved', isError: false)`

### Modals
```dart
AppSheet.show<T>(context: context, ref: ref, title: '…', builder: (c) => …);
AppSheet.actions(context: context, ref: ref, actions: [SheetAction(...)]);
final ok = await AppDialog.confirm(context: context, ref: ref,
    title: 'Delete workout?', message: '…', confirmLabel: 'Delete', destructive: true);
AppDialog.info(context: context, ref: ref, title: '…', message: '…');
```
Sheet titles are 19pt bold (`sheetTitleStyle(t)` if you draw your own
header). `AppSheet.actions` takes `subtitle:` too ("Set 3" / "Bench Press"). `SheetAction` rows use neutral icon tiles; `destructive: true` rows
get an error tile and an error label.

The Material `Switch` is themed: on = `primary` track; off = `neutralWash`
track with a `textTertiary` rim and a `textSecondary` knob, legible in every
palette.

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
- *logged / done set* = `reps > 0` — weight 0 is a bodyweight set
  (`isSetLogged` in `lib/utils/placeholder_history.dart`)
- *working set* = `!isWarmUp && reps > 0` (`AnalyticsService.isWorkingSet`)
- *weighted set* = working set with `weight > 0` (`isWeightedSet`) — the only
  input to top weight, estimated 1RM and weight PRs
- *volume / tonnage* = Σ `weight × reps` over working sets (bodyweight adds 0)
- *estimated 1RM* = Epley, only from sets of ≤ 12 reps
- *week* starts Monday
- Step dates with calendar arithmetic (`AnalyticsService.addDays`), never
  `Duration(days: …)` — across a DST change that lands on 23:00 the day before.
- Empty sets and skipped exercises are not saved by new sessions, but old
  sessions may contain them; `TrainingData.sessions` already excludes
  sessions with nothing logged.

**Active workout hints.** Empty fields show last time's value as a grey hint,
built by `buildPlaceholders` from the most recent session where that set was
logged (same program first, then any program). Typing only one of weight/reps
adopts the hint for the other.

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
    `AppSpacing.navBarClearance` + `MediaQuery.padding.bottom` of bottom
    padding (`AppScaffold` does it). Read the inset — never hardcode it: while
    a workout is live the shell inflates `padding.bottom` by
    `NavBarMetrics.accessoryClearance` so content clears the floating
    workout pill (`FloatingCapsule`) above the nav bar.
12. Prefer `Icons.*_rounded` variants — they match the soft geometry.
