# EQ Indexed Stack

A high-performance lazy-loading `IndexedStack` implementation for Flutter that initializes pages only when they are needed.

## Features

- **Lazy Loading**: Pages are only initialized when they're accessed, reducing memory usage
- **Preloading**: Support for preloading specific pages during initialization
- **Maintainable State**: Configure which pages should maintain their state when not visible
- **Memory Efficiency**: Only the necessary pages are kept in memory
- **Manual Control**: Explicit methods to preload or dispose specific pages

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  eq_indexd_stack: ^0.0.1
```

## Usage

### Basic Example

```dart
import 'package:eq_indexd_stack/eq_indexd_stack.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: EQIndexedStackDemo(),
    );
  }
}

class EQIndexedStackDemo extends StatefulWidget {
  @override
  _EQIndexedStackDemoState createState() => _EQIndexedStackDemoState();
}

class _EQIndexedStackDemoState extends State<EQIndexedStackDemo> {
  late EQIndexdStackController controller;

  @override
  void initState() {
    super.initState();
    
    // Create pages
    final pages = [
      EQPage(
        page: Container(color: Colors.red, child: Center(child: Text('Page 1'))),
        index: 0,
        maintainState: true,
      ),
      EQPage(
        page: Container(color: Colors.blue, child: Center(child: Text('Page 2'))),
        index: 1,
        maintainState: true,
      ),
      EQPage(
        page: Container(color: Colors.green, child: Center(child: Text('Page 3'))),
        index: 2,
        maintainState: false,
        preload: false,
      ),
    ];
    
    // Initialize controller with pages and optional preload indexes
    controller = EQIndexdStackController(
      pages: pages,
      preloadIndexes: [0], // Preload first page
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
      appBar: AppBar(title: Text('EQ Indexed Stack Demo')),
      body: EQIndexdStack(controller: controller),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: controller.currentIndex,
        onTap: (index) => controller.onIndex(index),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Page 1'),
          BottomNavigationBarItem(icon: Icon(Icons.business), label: 'Page 2'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Page 3'),
        ],
      ),
    );
  }
}
```

### Advanced Configuration

```dart
// Preload specific pages
controller.preloadPage(2);

// Manually dispose a page
controller.disposePage(1);
```

## How It Works

The `EQIndexdStack` uses a controller-based approach for managing the indexed stack:

1. Pages are created with specific configurations (maintainState, preload)
2. The controller tracks which pages have been activated
3. When navigating to a page, it's activated if it hasn't been before
4. Pages can be preloaded either during initialization or manually

This approach ensures optimal performance by only initializing pages when needed, while still providing a smooth user experience.

## Additional Information
 

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.