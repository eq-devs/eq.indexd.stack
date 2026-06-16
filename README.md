# indexd_stack_dev

A high-performance lazy-loading `IndexedStack` for Flutter with a custom `RenderObject` pipeline and native tab transitions. Pages are initialized only when first accessed, and only the active tab (plus the outgoing one mid-transition) is **painted** — inactive cached pages consume no paint resources.

## Features

- 🚀 **Custom RenderObject**: Only the active child — and the outgoing child during a transition — is painted and sizes the stack. Attached children are still laid out (Flutter's layout contract requires it), while lazy initialization keeps unvisited pages from being built at all.
- ⚡ **Native Animations**: Fade, FadeThrough, SharedAxis transitions built without external dependencies
- 💾 **LRU Cache**: Configurable `maxCachedPages` with automatic least-recently-used eviction
- 🧹 **Memory Pressure**: Automatic cache flush on OS memory warnings via `WidgetsBindingObserver`
- 🔄 **TickerMode**: Animations in background tabs are automatically paused
- 🎯 **Zero Overhead**: When `animation: IndexdAnimationType.none`, no `AnimationController` is allocated

## Installation

```yaml
dependencies:
  indexd_stack_dev: ^0.1.0
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
        animation: IndexdAnimationType.fadeThrough, // or .none for zero overhead
        children: [
          HomePage(),
          ProfilePage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: controller.currentIndex,
        onTap: (index) => controller.switchTo(index, 3),
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
  animation: IndexdAnimationType.sharedAxisHorizontal,
  animationDuration: const Duration(milliseconds: 200),
  children: [...],
)
```

| Type | Description |
|---|---|
| `none` | Instant switch, zero allocation (default) |
| `fade` | Simple crossfade |
| `fadeThrough` | Material Design fade through (scale + fade) |
| `sharedAxisHorizontal` | Slide + fade on the X axis |
| `sharedAxisVertical` | Slide + fade on the Y axis |

Animation type can be changed dynamically at runtime. Switching to `none` immediately disposes the `AnimationController`.

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

| Method | Description |
|---|---|
| `switchTo(index, totalPages)` | Switch to a page with automatic cache management |
| `disposePage(index)` | Remove a specific page from memory |
| `disposePages(indexes)` | Remove multiple pages from memory |
| `reset()` | Clear all pages except current and preloaded |
| `preloadPage(index, totalPages)` | Eagerly load a page into cache |
| `preloadAdjacentPages(totalPages, [range])` | Preload pages adjacent to current |
| `isLoaded(index)` | Check if a page is in memory |
| `didHaveMemoryPressure()` | Manually trigger memory flush |

### LazyLoadIndexedStack

```dart
LazyLoadIndexedStack({
  required LazyStackController controller,
  required List<Widget> children,
  IndexdAnimationType animation = IndexdAnimationType.none,
  Duration animationDuration = const Duration(milliseconds: 200),
  AlignmentGeometry alignment = AlignmentDirectional.topStart,
  TextDirection? textDirection,
})
```

## Architecture

```
LazyLoadIndexedStack (StatefulWidget)
  └── AnimationController? (null when animation == none)
  └── _LazyRenderStack (MultiChildRenderObjectWidget)
       └── _RenderLazyStack (RenderBox)
            ├── performLayout: only active + transitioning child
            ├── paint: outgoing first, incoming on top
            └── hitTest: only active child receives touches
```

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.