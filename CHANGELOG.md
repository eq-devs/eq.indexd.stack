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
