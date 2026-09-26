# indexd_stack_dev

A high-performance lazy-loading `IndexedStack` for Flutter with a custom `RenderObject` pipeline and native tab transitions. Pages are initialized only when first accessed, and only the active tab (plus the outgoing one mid-transition) is **painted** — inactive cached pages consume no paint resources.

## Features

- 🚀 **Custom RenderObject**: Only the active child — and the outgoing child during a transition — is painted and sizes the stack. Attached children are still laid out (Flutter's layout contract requires it), while lazy initialization keeps unvisited pages from being built at all.
- ⚡ **Native Animations**: Fade, FadeThrough, ScaleIn, and SharedAxis transitions with pure Flutter APIs (no animation package dependency)
- 💾 **LRU Cache**: Configurable `maxCachedPages` with automatic least-recently-used eviction
- 🧹 **Memory Pressure**: Automatic cache flush on OS memory warnings via `WidgetsBindingObserver`
- 🔄 **TickerMode**: Animations in background tabs are automatically paused
- 🎯 **Zero Overhead**: When `animation: IndexdAnimationType.none`, no `AnimationController` is allocated

## Installation

```yaml
dependencies:
  indexd_stack_dev: ^0.3.9
```

```bash
flutter pub get
```

## Quick Start

```dart
import 'package:indexd_stack_dev/indexd_stack_dev.dart';

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late LazyStackController controller;
  
  @override
  void initState() {
    super.initState();
    controller = LazyStackController(
      initialIndex: 0,
      maxCachedPages: 3,
      disposeUnused: true,
      isListenMemoryPressure: true,
    );
  }
  
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LazyLoadIndexedStack(
        controller: controller,
        // Tab shell: scaleIn defaults to 320ms, expand, IndexdPaintOrder.stack.
        animation: IndexdAnimationType.scaleIn,
        children: [
          HomePage(),
          ProfilePage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: controller.currentIndex,
        onTap: (index) => controller.switchTo(index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
```

## Animations

Pass `IndexdAnimationType` to control tab transitions:

```dart
LazyLoadIndexedStack(
  controller: controller,
  animation: IndexdAnimationType.scaleIn, // duration → kScaleInDuration (320ms)
  children: [...],
)
```

### Recommendations

| Use case | Type | Duration |
|---|---|---|
| Bottom-nav / tab shell (recommended) | `scaleIn` | **320ms** (type default) |
| Light crossfade | `fade` | ~200–250ms (type default 200ms) |
| Material-style switch | `fadeThrough` | ~200–250ms |
| Directional / spatial motion | `sharedAxisHorizontal` or `sharedAxisVertical` | ~200–250ms |
| Zero overhead | `none` (package default) | n/a |

Prefer `scaleIn` or `fade` for main tabs. Reserve shared-axis for flows where axis direction should feel intentional — it paints two moving pages and costs a bit more than fade/scaleIn.

`scaleIn` also defaults to full-bleed (`StackFit.expand`) and `IndexdPaintOrder.stack` (same as Flutter `Stack`: higher tab index on top). Pages should be **opaque** (a `ColoredBox` / `Scaffold` background) — transparent lists ghost during the fade. Tab icon springs / haptics stay in the host app.

### Types

| Type | Description | Suggested duration |
|---|---|---|
| `none` | Instant switch, zero allocation (**package default**) | — |
| `fade` | Simple crossfade | ~200–250ms |
| `fadeThrough` | Material Design fade through (scale + fade) | ~200–250ms |
| `scaleIn` | Quiet iOS settle (fade + tiny bilateral scale `0.992`↔`1.0`) | **320ms** |
| `sharedAxisHorizontal` | Slide + fade on the X axis | ~200–250ms |
| `sharedAxisVertical` | Slide + fade on the Y axis | ~200–250ms |

Animation type can be changed dynamically at runtime. Switching to `none` immediately disposes the `AnimationController`.

> Omit `animationDuration` to use type defaults (`scaleIn` → 320ms, others → 200ms). Pass an explicit duration to override.

## API Reference

### LazyStackController

```dart
LazyStackController({
  int initialIndex = 0,
  List<int> preloadIndexes = const [],
  bool disposeUnused = false,
  int maxCachedPages = 3,
  bool isListenMemoryPressure = false,
})
```

| Property | Type | Description |
|---|---|---|
| `currentIndex` | `int` | Currently visible page |
| `loadedIndexes` | `Set<int>` | Pages currently in memory |
| `canGoBack` | `bool` | Whether current index > 0 |
| `pageCount` | `int?` | Total pages; synced automatically from `LazyLoadIndexedStack.children.length` — don't set this yourself in normal use |

| Method | Description |
|---|---|
| `switchTo(index)` | Switch to a page with automatic cache management |
| `disposePage(index)` | Remove a specific page from memory |
| `disposePages(indexes)` | Remove multiple pages from memory |
| `reset()` | Clear all pages except current and preloaded |
| `preloadPage(index)` | Eagerly load a page into cache |
| `preloadAdjacentPages([range])` | Preload pages adjacent to current. Called right after `switchTo`, the preloaded pages build once the transition finishes (or on the next frame with `animation: none`), not in the switch frame |
| `isLoaded(index)` | Check if a page is in memory |
| `didHaveMemoryPressure()` | Manually trigger memory flush |

### LazyLoadIndexedStack

```dart
LazyLoadIndexedStack({
  required LazyStackController controller,
  required List<Widget> children,
  IndexdAnimationType animation = IndexdAnimationType.none,
  Duration? animationDuration, // null → type default (scaleIn 320ms, else 200ms)
  StackFit fit = StackFit.expand,
  IndexdPaintOrder? paintOrder, // null → IndexdPaintOrder.stack for scaleIn
  AlignmentGeometry alignment = AlignmentDirectional.topStart,
  TextDirection? textDirection,
})
```

### Performance tips

- Hidden cached pages keep their last layout while the stack resizes (keyboard, rotation) and are re-laid out when shown. They still **rebuild** if they depend on `MediaQuery.of(context)`, so prefer the narrow accessors — `MediaQuery.sizeOf`, `MediaQuery.viewInsetsOf`, `MediaQuery.paddingOf` — which only rebuild for the value you read.

## Architecture

```
lib/
  indexd_stack_dev.dart          # public exports
  src/
    indexd_animation_type.dart
    indexd_paint_order.dart
    controller/lazy_stack_controller.dart
    widgets/lazy_load_indexed_stack.dart
    transitions/stack_transition_animations.dart
    rendering/lazy_render_stack.dart

LazyLoadIndexedStack
  └── AnimationController? (null when animation == none)
  └── StackTransitionAnimations (cached curves)
  └── LazyRenderStack / RenderLazyStack
       ├── performLayout: expand participating pages (StackFit.expand)
       ├── paint: scaleIn defaults to IndexdPaintOrder.stack (Flutter Stack order)
       └── hitTest: only active child receives touches
```

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
