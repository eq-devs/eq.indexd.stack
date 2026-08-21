## Unreleased

### 🧹 Internal
- **`scaleIn` now shares `RenderLazyStack`** with every other animation type instead of a dedicated Flutter `Stack` + `Offstage` tree. `_ScaleInLayer` / `ScaleInPageTransition` are removed; `scaleIn`'s fade + tiny bilateral scale is unchanged, now driven by the same `StackTransitionAnimations` tweens/curves the other types already used (`IndexdPaintOrder.stack` was already the `scaleIn` default, now actually wired through `RenderLazyStack`).
  - **Not a measured performance win.** The refactor was originally motivated by a suspected relayout-boundary gap (hidden cached pages under `Stack`/`Offstage` supposedly unable to contain their own `markNeedsLayout()`, forcing a full-stack relayout). Benchmarking against the pre-refactor implementation disproved this: `RenderOffstage` sets `sizedByParent = offstage`, which independently satisfies Flutter's relayout-boundary condition regardless of the parent's `parentUsesSize` choice — so the old `Stack`+`Offstage` path was already correctly isolating hidden pages. Verified with `hidden_relayout_boundary_test.dart`'s new `scaleIn` case, which passes on both implementations.
  - The real payoff is code consolidation: one transition implementation instead of two near-duplicates that had already drifted once (the outgoing-ticker-freeze fix in 0.3.1 only touched the `scaleIn` path and had to be reasoned about separately), plus removing a one-time (not per-switch) `StackTransitionAnimations` tween/curve allocation that the old `scaleIn` path built via `ensureBuilt` but never consumed.

## 0.3.2

### ✨ Updates
- **`scaleIn` compositing**: participating pages use `StackFit.expand` (full-bleed) by default so the quiet `0.992` scale reads as a viewport settle, not a floating card shrink.
- **`scaleIn` paint order**: defaults to `IndexdPaintOrder.stack` (Flutter `Stack`: higher tab index on top). Override with `paintOrder:`.
- **`scaleIn` uses Flutter `Stack` + `Offstage`** (`_buildScaleInStack`); other types keep `RenderLazyStack`. The stack is **not** rebuilt every frame — `FadeTransition` / `ScaleTransition` tick on their own.
- **Type-default duration**: omit `animationDuration` and `scaleIn` uses `kScaleInDuration` (320ms); fade / shared-axis use `kDefaultAnimationDuration` (200ms).

### 💥 Breaking
- `animationDuration` is now `Duration?` (`null` = type default). Call sites that relied on the old implicit `200ms` for `scaleIn` now get `320ms` unless they pass a duration explicitly.

### 📝 Docs / example
- Exported `kScaleInCurve`, `kScaleInBegin`, `kScaleInDuration`, `kDefaultAnimationDuration`.
- Example uses `ComplexLazyStackDemo` with `scaleIn` as the default tab transition.

## 0.3.1

### 🐛 Fixes
- **Outgoing page ticks froze too late**: the outgoing page's `TickerMode` stayed enabled for the whole exit transition instead of freezing immediately once it started fading out. Now only the incoming/active page keeps ticking, matching the intended quiet-settle behavior exactly.

## 0.3.0

### ✨ Updates
- **`scaleIn` quiet iOS-style settle**: pure Flutter `FadeTransition` + `ScaleTransition`, shared soft iOS curve (`Cubic(0.22, 1.0, 0.36, 1.0)`), fade `0`↔`1` + tiny bilateral scale (`0.992`↔`1.0`), no slide. Prefer ~320ms.
- All other `IndexdAnimationType`s stay on pure Flutter transitions (`FadeTransition` / `ScaleTransition` / `SlideTransition`) with cached curved animations — no animation framework dependency.

### 📝 Docs
- Product guidance: tab shells → `scaleIn` @ ~320ms (or `fade` @ ~200–250ms); keep `none` as the zero-overhead package default; reserve shared-axis for directional flows.
- Dartdoc on `IndexdAnimationType` / `LazyLoadIndexedStack` documents recommended durations.

### ♻️ Refactor
- Split library into `src/` by concern: `widgets/`, `controller/`, `transitions/`, `rendering/` (public API unchanged via barrel export).

## 0.2.0

### ✨ Updates
- **`scaleIn` quiet settle**: shared soft iOS curve (`Cubic(0.22, 1.0, 0.36, 1.0)`), fade + tiny bilateral scale (`0.992`↔`1.0`) on both pages, still a complementary crossfade (no luminance dip).

### 💥 Breaking
- **Removed `scaleBegin`**: the offset is fixed at `0.992`; tune feel with `animationDuration` (example/docs recommend ~320ms for `scaleIn`).

## 0.1.9

### ⚡ Performance
- **Hidden pages are now relayout boundaries**: `_RenderLazyStack` lays out hidden cached pages with `parentUsesSize: false`, so a size change inside a hidden page (async data arriving, a growing list) relays out that page alone instead of dirtying the whole stack. Active and outgoing children are also resolved in a single child traversal instead of repeated linked-list walks.
- **Repaint boundaries around pages**: every loaded page is wrapped in a `RepaintBoundary` (at constant tree depth, so page state is preserved), letting transitions composite each page's cached raster instead of re-rasterizing both pages every animation frame.
- **Fewer allocations on the switch path**: cached transition animations are rebuilt only when the animation type (or direction, for shared-axis) changes; `LazyStackController.loadedIndexes` caches its unmodifiable view instead of copying a `Set` per rebuild; protected-index checks use a precomputed set.

### ✅ Tests
- Regression test proving hidden-page relayout stops at its own boundary.
- Regression test proving the outgoing page's `State` survives an eviction mid-transition (one `initState`, one `dispose`).

## 0.1.8

### ✨ Features
- Added `IndexdAnimationType.scaleIn`: a subtle iOS-style transition where the incoming page scales from `scaleBegin` (default `0.98`, configurable `0.95`–`0.99`) to `1.0` while cross-dissolving with the outgoing page. The two opacities are exact complements, so there is no Material fade-through "dip".

### 🐛 Fixes
- **`switchTo` validation**: `LazyStackController.switchTo(index, totalPages)` now validates `index` against `totalPages` (previously ignored), preventing an out-of-range crash on negative indexes and a blank page on too-large ones.
- **Controller swap**: swapping the `controller` on `LazyLoadIndexedStack` now re-syncs the current index immediately, so the correct page renders instead of a stale/blank one until the new controller emits.
- **Double rebuild**: `switchTo` with `disposeUnused: true` no longer notifies listeners twice — a single rebuild per switch.

### 📝 Docs & Example
- README now accurately describes layout vs. paint: every attached child is laid out (Flutter's layout contract), while only the active and outgoing child are painted.
- Example: replaced deprecated `Switch.activeColor` with `activeThumbColor`.

## 0.1.7

### 🐛 Fixes
- **Layout-contract crash with cached pages**: `_RenderLazyStack.performLayout` now lays out *every* attached child each pass, not just the active and outgoing ones. Cached (loaded but inactive) pages are real, mounted subtrees; skipping their layout left them in `NEEDS-LAYOUT`, so a cached page containing a `TextField` (or anything whose size is later read by the host `Scaffold`) would throw `RenderBox was not laid out: RenderEditable... NEEDS-LAYOUT`. Only the active child — and the outgoing child during a transition — still drive the stack's size; painting and hit-testing remain restricted to those, so inactive pages stay invisible.
- **Semantics**: Added `visitChildrenForSemantics` so only the active page is exposed to the accessibility tree, matching stock `IndexedStack` behavior now that inactive pages are laid out.

## 0.1.5

### ✨ Updates & Polish
- **Faster Animations**: Decreased default animation duration from 250ms to 200ms for a snappier feel.
- **Improved Animation Curves**: Changed the shared axis slide animation curve to `fastOutSlowIn` and adjusted the slide offset from 15% to 7%.

## 0.1.4

### ✨ Updates & Cleanups
- **Premium Animation Curves**: Upgraded the `Fade Through` and `Shared Axis` transition curves to `fastLinearToSlowEaseIn` for a much smoother, iOS/Material 3 style spring-damped feel.
- **Optimized Transition Offsets**: Reduced the slide offset scale in Shared Axis transitions from 15% to 8% to create a more premium, subtle depth effect. 
- **Smoother Cross-fades**: Fine-tuned opacity intervals for cross-fading, completely eliminating brief frame flashes during dark mode transitions.
- **Codebase Polish**: Cleaned up all artificial comments and explanatory text for a pristine, production-ready source code.

## 0.1.3

### ⚡ Performance & Fixes
- **Strict Widget Tree Stabilization**: Fixed the critical bug where tabs would rebuild on every switch. The `AnimatedBuilder` wrapper depth is now perfectly stable across all `IndexdAnimationType` transitions, ensuring Flutter never unmounts the page element.
- **Zero Per-Frame Allocations**: Eliminated all dynamic `Animation` object creation within the `build()` method. All `ReverseAnimation` and derived animation objects are now tightly pre-cached once per transition, guaranteeing `ScaleTransition` and `FadeTransition` never invoke `didUpdateWidget` rebuilds during layout.
- **Const Inert Animations**: Optimized non-participating loaded tabs to use `static const kInertScale = AlwaysStoppedAnimation(1.0)` and similar static wrappers. This allocates 0 bytes of memory per frame for background tabs while perfectly maintaining widget tree depth.

## 0.0.3
# refactor: rename IndexdStackController to LazyStackController

## 0.0.4
# enhance README.md with detailed feature descriptions and usage examples

## 0.0.5
# update README.md 

## 0.0.6
# add canPop getter to LazyStackController

## 0.0.7
# add memory pressure handling in 

## 0.0.8
# refactor: improved memory management and lazy loading

## 0.0.9
# chore: rename package to indexd_stack_dev

## 0.1.1

### 🐛 Fixes
- **Fixed page rebuild bug**: Pages no longer rebuild continuously when animations are enabled. `AnimatedBuilder` is now only attached during the active 300ms transition and stripped immediately after.
- **Eliminated unnecessary setState**: Cache/loaded changes now use a targeted `Set` equality check instead of blindly calling `setState(() {})`.

## 0.1.0

### ⚡ Performance (Breaking)
- **Custom RenderObject**: Replaced Flutter's native `IndexedStack` with a custom `_RenderLazyStack` that skips layout computation entirely for inactive children. Only the active child participates in layout/paint.
- **Cached Animations**: All `CurvedAnimation` and `Tween` objects are now created once per transition and cached as state fields — zero per-frame allocations.
- **Optimized `loadedIndexes`**: Returns `Set<int>.unmodifiable()` instead of allocating a new `Set` on every access.
- **Eliminated double eviction**: `switchTo` no longer calls `_enforceMaxSize` twice.
- **Removed `dart:math` dependency**: Inlined max comparisons.

### ✨ Features
- **Native Tab Animations**: Added `IndexdAnimationType` enum with 5 transition styles:
  - `none` (zero-overhead, no AnimationController allocated)
  - `fade`
  - `fadeThrough` (Material Design spec)
  - `sharedAxisHorizontal`
  - `sharedAxisVertical`
- **Dynamic Animation Toggling**: Switching between `none` and animated types at runtime is fully supported with proper resource lifecycle management.
- **Nullable AnimationController**: When `animation: IndexdAnimationType.none`, no `AnimationController` is created — true zero allocation.

### 🔧 Breaking Changes
- **Removed `EQ` prefix**: `EQLazyStackController` → `LazyStackController`, `EQLazyLoadIndexedStack` → `LazyLoadIndexedStack`.
- **Removed `removableIndexes`**: Dead field that was never used internally.
- **Changed base class**: `LazyLoadIndexedStack` is now a `StatefulWidget` (was `ListenableBuilder`).
- **Removed `StackFit sizing` parameter**: The custom RenderObject handles sizing internally.

### 🐛 Fixes
- Controller now uses `ChangeNotifier` instead of manual listener management.
- `switchTo` performs synchronous eviction before `notifyListeners()` — no double-frame builds.
- Memory pressure handler (`didHaveMemoryPressure`) aggressively flushes all inactive pages.
