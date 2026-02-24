import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:indexd_stack_dev/indexd_stack_dev.dart';

// Import the LazyLoadIndexedStack implementation
// (Assuming it's in a file called lazy_stack.dart)

void main() {
  runApp(const ComplexLazyStackDemo());
}

class ComplexLazyStackDemo extends StatelessWidget {
  const ComplexLazyStackDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LazyLoadIndexedStack Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const LazyStackHomePage(),
    );
  }
}

class LazyStackHomePage extends StatefulWidget {
  const LazyStackHomePage({super.key});

  @override
  State<LazyStackHomePage> createState() => _LazyStackHomePageState();
}

class _LazyStackHomePageState extends State<LazyStackHomePage> {
  // Create multiple controllers for different use cases
  late EQLazyStackController mainPageController;
  late EQLazyStackController nestedController;
  late EQLazyStackController modalController;

  // Page tracking
  final Map<int, int> pageVisitCounts = {};
  int totalPageSwitches = 0;

  // Memory usage tracking
  final List<String> memoryLog = [];

  @override
  void initState() {
    super.initState();

    // Initialize main controller with preloaded pages
    mainPageController = EQLazyStackController(
      initialIndex: 0,
      preloadIndexes: [1], // Preload the second tab
      disposeUnused: true,
      maxCachedPages: 3,
    );

    // Nested controller inside one of the main pages
    nestedController = EQLazyStackController(
      initialIndex: 0,
      disposeUnused: true,
      maxCachedPages: 2,
    );

    // Controller for modal content
    modalController = EQLazyStackController(
      initialIndex: 0,
      disposeUnused: false, // Keep all modal pages loaded
    );

    // Log initial page visit
    _logPageVisit(0);
    _logMemoryUsage("App started");
  }

  void _logPageVisit(int pageIndex) {
    pageVisitCounts[pageIndex] = (pageVisitCounts[pageIndex] ?? 0) + 1;
    totalPageSwitches++;
    setState(() {});
  }

  void _logMemoryUsage(String event) {
    final timestamp = DateTime.now().toString().split('.').first;
    final loadedPages = [
      ...mainPageController.loadedIndexes.map((i) => 'Main-$i'),
      ...nestedController.loadedIndexes.map((i) => 'Nested-$i'),
      ...modalController.loadedIndexes.map((i) => 'Modal-$i'),
    ].join(', ');

    memoryLog.add('[$timestamp] $event - Loaded: $loadedPages');

    // Limit log size
    if (memoryLog.length > 10) {
      memoryLog.removeAt(0);
    }
  }

  @override
  void dispose() {
    mainPageController.dispose();
    nestedController.dispose();
    modalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LazyLoadIndexedStack Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.memory),
            onPressed: () => _showMemoryLog(),
          ),
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            onPressed: () => _forceCleanup(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Navigation buttons
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int i = 0; i < 5; i++)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainPageController.currentIndex == i
                          ? Colors.blue
                          : null,
                      foregroundColor: mainPageController.currentIndex == i
                          ? Colors.white
                          : null,
                    ),
                    onPressed: () {
                      mainPageController.switchTo(i, 5);
                      _logPageVisit(i);
                      setState(() {});
                    },
                    child: Text('Page ${i + 1}'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: EQLazyLoadIndexedStack(
              controller: mainPageController,
              children: [
                _buildHomePage(),
                _buildFeedPage(),
                _buildExplorePage(),
                _buildProfilePage(),
                _buildSettingsPage(),
              ],
            ),
          ),
          // Debug info bar
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active: ${mainPageController.currentIndex}',
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  'Loaded: ${mainPageController.loadedIndexes.join(', ')}',
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  'Switches: $totalPageSwitches',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showModalMenu(context),
      ),
    );
  }

  // Home page with a counter and nested tabs
  Widget _buildHomePage() {
    return Column(
      children: [
        // Visit counter for this page
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Home visited ${pageVisitCounts[0] ?? 1} times',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        // Nested navigation
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: nestedController.currentIndex == i
                          ? Colors.amber
                          : null,
                      foregroundColor: nestedController.currentIndex == i
                          ? Colors.black
                          : null,
                    ),
                    onPressed: () {
                      nestedController.switchTo(i, 3);
                      _logMemoryUsage("Nested navigation changed to $i");
                      setState(() {});
                    },
                    child: Text(['Recent', 'Favorites', 'Trending'][i]),
                  ),
                ),
            ],
          ),
        ),

        // Nested content using another LazyLoadIndexedStack
        Expanded(
          child: EQLazyLoadIndexedStack(
            controller: nestedController,
            children: [
              _buildNestedContent('Recent Items', Colors.blue.shade100),
              _buildNestedContent('Favorite Items', Colors.amber.shade100),
              _buildNestedContent('Trending Items', Colors.pink.shade100),
            ],
          ),
        ),
      ],
    );
  }

  // Feed page with a complex list and animations
  Widget _buildFeedPage() {
    return ComplexFeedPage(
      visitCount: pageVisitCounts[1] ?? 0,
      onAction: () => _logMemoryUsage("Feed action triggered"),
    );
  }

  // Explore page with a grid layout
  Widget _buildExplorePage() {
    return GridViewPage(
      visitCount: pageVisitCounts[2] ?? 0,
      onLoadMore: () => _logMemoryUsage("Explore loaded more content"),
    );
  }

  // Profile page with heavy content
  Widget _buildProfilePage() {
    return HeavyProfilePage(
      visitCount: pageVisitCounts[3] ?? 0,
      onImageLoad: () => _logMemoryUsage("Profile loaded images"),
    );
  }

  // Settings page
  Widget _buildSettingsPage() {
    return ListView(
      children: [
        ListTile(
          title: Text('Settings visited ${pageVisitCounts[4] ?? 0} times'),
          subtitle: const Text('This page demonstrates memory efficiency'),
        ),
        const Divider(),
        SwitchListTile(
          title: const Text('Preload Next Page'),
          value: mainPageController.preloadIndexes.isNotEmpty,
          onChanged: (value) {
            // This would normally update the controller's preloadIndexes
            _logMemoryUsage("Preload setting changed");
          },
        ),
        SwitchListTile(
          title: const Text('Dispose Unused Pages'),
          value: mainPageController.disposeUnused,
          onChanged: (value) {
            // This would normally update the controller's disposeUnused
            _logMemoryUsage("Dispose setting changed");
          },
        ),
        ListTile(
          title: const Text('Max Cached Pages'),
          trailing: DropdownButton<int>(
            value: mainPageController.maxCachedPages,
            items: [1, 2, 3, 4, 5].map((int value) {
              return DropdownMenuItem<int>(
                value: value,
                child: Text(value.toString()),
              );
            }).toList(),
            onChanged: (newValue) {
              // This would normally update the controller's maxCachedPages
              _logMemoryUsage("Changed max cache to $newValue");
            },
          ),
        ),
        const Divider(),
        ListTile(
          title: const Text('Reset All Page Counters'),
          trailing: const Icon(Icons.refresh),
          onTap: () {
            setState(() {
              pageVisitCounts.clear();
              totalPageSwitches = 0;
            });
            _logMemoryUsage("Reset counters");
          },
        ),
        ListTile(
          title: const Text('Force Cleanup'),
          trailing: const Icon(Icons.cleaning_services),
          onTap: _forceCleanup,
        ),
      ],
    );
  }

  // Nested content
  Widget _buildNestedContent(String title, Color backgroundColor) {
    return Container(
      color: backgroundColor,
      child: ListView.builder(
        itemCount: 15,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text('$title Item $index'),
            leading: CircleAvatar(child: Text('${index + 1}')),
            onTap: () => _logMemoryUsage("Tapped on $title item $index"),
          );
        },
      ),
    );
  }

  // Modal menu with another LazyLoadIndexedStack
  void _showModalMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Modal Menu',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton(
                        child: const Text('Page 1'),
                        onPressed: () {
                          modalController.switchTo(0, 3);
                          setModalState(() {});
                          _logMemoryUsage("Modal switched to page 0");
                        },
                      ),
                      ElevatedButton(
                        child: const Text('Page 2'),
                        onPressed: () {
                          modalController.switchTo(1, 3);
                          setModalState(() {});
                          _logMemoryUsage("Modal switched to page 1");
                        },
                      ),
                      ElevatedButton(
                        child: const Text('Page 3'),
                        onPressed: () {
                          modalController.switchTo(2, 3);
                          setModalState(() {});
                          _logMemoryUsage("Modal switched to page 2");
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: EQLazyLoadIndexedStack(
                      controller: modalController,
                      children: [
                        _buildModalPage('Modal Page 1', Colors.red.shade100),
                        _buildModalPage('Modal Page 2', Colors.green.shade100),
                        _buildModalPage('Modal Page 3', Colors.purple.shade100),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      _logMemoryUsage("Modal closed");
    });
  }

  // Modal page content
  Widget _buildModalPage(String title, Color backgroundColor) {
    return Container(
      color: backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text('This page maintains its state even when not visible'),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('Simulate Heavy Action'),
              onPressed: () {
                _logMemoryUsage("Heavy action on $title");
              },
            ),
          ],
        ),
      ),
    );
  }

  // Show memory log dialog
  void _showMemoryLog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Memory Usage Log'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: memoryLog.length,
            itemBuilder: (context, index) {
              return Text(memoryLog[index]);
            },
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Clear Log'),
            onPressed: () {
              setState(() {
                memoryLog.clear();
              });
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Close'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  // Force cleanup of unused pages
  void _forceCleanup() {
    // Reset controllers to cleanup memory
    mainPageController.reset();
    nestedController.reset();

    setState(() {});
    _logMemoryUsage("Forced cleanup");

    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unused pages have been cleaned up'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// A page with complex animated content
class ComplexFeedPage extends StatefulWidget {
  final int visitCount;
  final VoidCallback onAction;

  const ComplexFeedPage({
    super.key,
    required this.visitCount,
    required this.onAction,
  });

  @override
  State<ComplexFeedPage> createState() => _ComplexFeedPageState();
}

class _ComplexFeedPageState extends State<ComplexFeedPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<String> _items = List.generate(30, (i) => 'Feed Item ${i + 1}');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Feed visited ${widget.visitCount} times',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        // Animated header
        SizedBox(
          height: 100,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: WavePainter(
                  animation: _controller,
                  color: Colors.blue,
                ),
                child: Center(
                  child: Text(
                    'Feed Content',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          offset: const Offset(1, 1),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Feed content
        Expanded(
          child: ListView.builder(
            itemCount: _items.length,
            itemBuilder: (context, index) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(child: Text('${index % 10}')),
                          const SizedBox(width: 8),
                          Text(
                            'User ${index % 10}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_items[index]),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.thumb_up_outlined),
                            onPressed: widget.onAction,
                          ),
                          IconButton(
                            icon: const Icon(Icons.comment_outlined),
                            onPressed: widget.onAction,
                          ),
                          IconButton(
                            icon: const Icon(Icons.share_outlined),
                            onPressed: widget.onAction,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Grid view page
class GridViewPage extends StatefulWidget {
  final int visitCount;
  final VoidCallback onLoadMore;

  const GridViewPage({
    super.key,
    required this.visitCount,
    required this.onLoadMore,
  });

  @override
  State<GridViewPage> createState() => _GridViewPageState();
}

class _GridViewPageState extends State<GridViewPage> {
  final List<Color> _colors = List.generate(100, (i) {
    return Color.fromRGBO(
      (math.Random().nextDouble() * 255).round(),
      (math.Random().nextDouble() * 255).round(),
      (math.Random().nextDouble() * 255).round(),
      1,
    );
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Explore visited ${widget.visitCount} times',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: _colors.length,
            itemBuilder: (context, index) {
              if (index == _colors.length - 1) {
                widget.onLoadMore();
              }

              return InkWell(
                onTap: () {},
                child: Container(
                  decoration: BoxDecoration(
                    color: _colors[index],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Heavy profile page
class HeavyProfilePage extends StatefulWidget {
  final int visitCount;
  final VoidCallback onImageLoad;

  const HeavyProfilePage({
    super.key,
    required this.visitCount,
    required this.onImageLoad,
  });

  @override
  State<HeavyProfilePage> createState() => _HeavyProfilePageState();
}

class _HeavyProfilePageState extends State<HeavyProfilePage> {
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    // Simulate heavy load
    widget.onImageLoad();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Profile visited ${widget.visitCount} times',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        // Profile header
        Container(
          height: 200,
          color: Colors.blueGrey,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 50),
                ),
                SizedBox(height: 16),
                Text(
                  'User Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Counter with state that should be preserved
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Counter: $_counter', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _counter++;
                  });
                },
                child: const Text('Increment'),
              ),
            ],
          ),
        ),

        // Content
        for (int i = 0; i < 10; i++)
          ListTile(
            leading: const Icon(Icons.photo),
            title: Text('Profile Item $i'),
            subtitle: const Text(
              'This state is preserved when you switch tabs',
            ),
            onTap: widget.onImageLoad,
          ),
      ],
    );
  }
}

// Wave painter for animated header
class WavePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  WavePainter({required this.animation, required this.color})
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final width = size.width;
    final height = size.height;

    path.moveTo(0, height * 0.5);

    // Create wave pattern
    for (double i = 0; i < width; i++) {
      path.lineTo(
        i,
        height * 0.5 +
            math.sin(
                  (i / width * 4 * math.pi) + (animation.value * 2 * math.pi),
                ) *
                10,
      );
    }

    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) => true;
}
