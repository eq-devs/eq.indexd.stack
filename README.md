# Indexed Stack

A high-performance lazy-loading `IndexedStack` implementation for Flutter that initializes pages only when they are needed. Perfect for bottom navigation, tab views, and any UI that requires switching between multiple views.

## Features

- 🚀 **Lazy Loading**: Pages are only initialized when they're accessed, reducing memory usage and startup time
- ⚡ **Preloading**: Optional preloading of specific pages during initialization
- 💾 **State Preservation**: Configure which pages should maintain their state when not visible
- 🧹 **Memory Efficiency**: Configurable memory management that automatically disposes unused pages
- 🔄 **TickerMode Support**: Automatically disables animations in inactive pages
- 🎮 **Full Control**: Explicit methods to preload or dispose specific pages

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  eq_indexed_stack: ^0.0.81
```

Then run:

```bash
flutter pub get
```

## Usage

### Basic Example

```dart
import 'package:flutter/material.dart';
import 'package:eq_indexed_stack/eq_indexed_stack.dart';

class IndexedStackDemo extends StatefulWidget {
  @override
  _IndexedStackDemoState createState() => _IndexedStackDemoState();
}

class _IndexedStackDemoState extends State<IndexedStackDemo> {
  late LazyStackController controller;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize controller with options
    controller = LazyStackController(
      initialIndex: 0,
      preloadIndexes: [1], // Preload second page
      disposeUnused: true,
      maxCachedPages: 3,
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
      appBar: AppBar(title: Text('Indexed Stack Demo')),
      body: LazyLoadIndexedStack(
        controller: controller,
        children: [
          HomePage(),
          ProfilePage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: controller.currentIndex,
        onTap: (index) => controller.switchTo(index, 3),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
```

### Advanced Usage

#### Multiple Stack Instances

You can use multiple LazyLoadIndexedStack instances with different controllers:

```dart
// Main navigation controller
final mainController = LazyStackController(
  initialIndex: 0,
  disposeUnused: true,
);

// Nested controller inside one of the main pages
final nestedController = LazyStackController(
  initialIndex: 0,
  maxCachedPages: 2,
);

// Use in widget tree
LazyLoadIndexedStack(
  controller: mainController,
  children: [
    HomePage(),
    LazyLoadIndexedStack(
      controller: nestedController,
      children: [
        SubPage1(),
        SubPage2(),
      ],
    ),
    SettingsPage(),
  ],
);
```

#### Force Cleanup

You can manually manage page disposal:

```dart
// Reset controller to clean up all pages except the current one and preloaded pages
controller.reset();

// Dispose a specific page
controller.disposePage(2);

// Dispose multiple pages at once
controller.disposePages([1, 3, 4]);

// Switch pages with possible automatic cleanup (if disposeUnused is true)
controller.switchTo(newIndex, totalPages);
```

#### Debugging Memory Usage

Track which pages are kept in memory:

```dart
// Check if a specific page is loaded
bool isPageLoaded = controller.isLoaded(2);

// Get all currently loaded page indexes
Set<int> loadedPages = controller.loadedIndexes;
```

## How It Works

Under the hood, `eq_indexed_stack` uses a combination of optimized techniques:

1. **Efficient State Management**: Only loaded pages are included in the render tree
2. **Offstage + TickerMode**: Hidden pages use Offstage and TickerMode to minimize resource usage
3. **Smart Page Management**: Automatically tracks and manages page history for optimal memory cleanup
4. **Direct Listenable Implementation**: Uses minimal overhead for reactivity

This creates a high-performance stack that:
- Reduces initial load time
- Minimizes memory consumption
- Improves overall app responsiveness
- Maintains state only where needed

## Performance Tips

To get the best performance:

1. Set appropriate `maxCachedPages` based on your app's memory constraints
2. Enable `disposeUnused` for apps with many heavy pages
3. Use `preloadIndexes` for pages that users are likely to visit immediately
4. Call `reset()` when navigation patterns change significantly
5. Use `disposePage()` or `disposePages()` for explicit memory management

## Complete API

### LazyStackController

```dart
LazyStackController({
  int initialIndex = 0,           // Starting page index
  List<int> preloadIndexes = [],  // Pages to preload on initialization
  bool disposeUnused = false,     // Whether to dispose pages exceeding maxCachedPages
  int maxCachedPages = 3,         // Maximum number of pages to keep in memory
})
```

**Properties:**
- `currentIndex`: Current visible page index
- `loadedIndexes`: Set of indexes that are currently loaded
- `isLoaded(int index)`: Check if a page is loaded

**Methods:**
- `switchTo(int index, int totalPages)`: Switch to a specific page
- `disposePage(int index)`: Dispose a specific page
- `disposePages(List<int> indexes)`: Dispose multiple specific pages
- `reset()`: Reset controller state, clearing all pages except current and preloaded
- `dispose()`: Dispose controller resources

### LazyLoadIndexedStack

```dart
LazyLoadIndexedStack({
  required LazyStackController controller, // Controller for the stack
  required List<Widget> children,          // Pages to display
  AlignmentGeometry alignment = AlignmentDirectional.topStart, // Alignment
  StackFit sizing = StackFit.loose,        // How to size children
  TextDirection? textDirection,            // Text direction for alignment
})
```

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.