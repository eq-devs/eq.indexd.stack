import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:indexd_stack_dev/indexd_stack_dev.dart';

void main() {
  runApp(const ComplexLazyStackDemo());
}

class ComplexLazyStackDemo extends StatelessWidget {
  const ComplexLazyStackDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      showPerformanceOverlay: true,
      title: 'Premium LazyStack Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.deepPurpleAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
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
  late LazyStackController mainController;
  final List<String> memoryLogs = [];
  IndexdAnimationType _currentAnimation = IndexdAnimationType.fadeThrough;

  @override
  void initState() {
    super.initState();
    mainController = LazyStackController(
      initialIndex: 0,
      disposeUnused: false,
      maxCachedPages: 4,
      isListenMemoryPressure: false,
    );
    mainController.addListener(_onControllerChanged);
    _logMemory("App started. Cache size max: 2");
  }

  void _onControllerChanged() {
    setState(() {});
  }

  void _logMemory(String event) {
    final timestamp = DateTime.now().toString().split('.').first.substring(11);
    final loaded = mainController.loadedIndexes.join(', ');
    setState(() {
      memoryLogs.insert(0, '[$timestamp] $event | Active Set: {$loaded}');
      if (memoryLogs.length > 20) memoryLogs.removeLast();
    });
  }

  @override
  void dispose() {
    mainController.removeListener(_onControllerChanged);
    mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Premium Architecture'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.memory),
            onPressed: () => _showMemoryLogs(context),
          ),
        ],
      ),
      body: LazyLoadIndexedStack(
        controller: mainController,
        animation: _currentAnimation,
        children: [
          HeavyFeedPage(onAction: () => _logMemory("Feed list scrolled/acted")),
          ExploreGridPage(onLoad: () => _logMemory("Explore grid loaded")),
          PremiumProfilePage(
            onInteract: () => _logMemory("Profile interaction"),
          ),
          SettingsSimulatorPage(
            controller: mainController,
            currentAnimation: _currentAnimation,
            onAnimationChanged: (anim) {
              setState(() => _currentAnimation = anim);
              _logMemory("Animation changed to ${anim.name}");
            },
            onSettingsChanged: (msg) => _logMemory(msg),
          ),
        ],
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.black.withValues(alpha: 0.6),
            child: BottomNavigationBar(
              currentIndex: mainController.currentIndex,
              onTap: (index) {
                _logMemory("Switched to Tab $index");
                mainController.switchTo(index, 4);
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: Colors.deepPurpleAccent,
              unselectedItemColor: Colors.white54,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dynamic_feed),
                  label: 'Feed',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.explore),
                  label: 'Explore',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMemoryLogs(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Memory & Cache Logs',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: memoryLogs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      memoryLogs[index],
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HeavyFeedPage extends StatefulWidget {
  final VoidCallback onAction;
  const HeavyFeedPage({super.key, required this.onAction});

  @override
  State<HeavyFeedPage> createState() => _HeavyFeedPageState();
}

class _HeavyFeedPageState extends State<HeavyFeedPage>
    with AutomaticKeepAliveClientMixin {
  final List<int> items = List.generate(50, (i) => i);

  @override
  bool get wantKeepAlive => true; // Simulating typical heavy stateful page

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo is ScrollEndNotification) {
          widget.onAction();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100, top: 16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return Card(
            color: const Color(0xFF2A2A2A),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            Colors.primaries[index % Colors.primaries.length],
                        child: Text('${index + 1}'),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User ${index + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '2 hours ago',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.image,
                        size: 50,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildAction(Icons.favorite_border, 'Like'),
                      _buildAction(Icons.comment_outlined, 'Comment'),
                      _buildAction(Icons.share, 'Share'),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ).animate().shake(),
    );
  }

  Widget _buildAction(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class ExploreGridPage extends StatefulWidget {
  final VoidCallback onLoad;
  const ExploreGridPage({super.key, required this.onLoad});

  @override
  State<ExploreGridPage> createState() => _ExploreGridPageState();
}

class _ExploreGridPageState extends State<ExploreGridPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onLoad();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: 30,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.primaries[index % Colors.primaries.length].withValues(
                  alpha: 0.8,
                ),
                Colors.primaries[(index + 1) % Colors.primaries.length]
                    .withValues(alpha: 0.5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.play_circle_fill,
              color: Colors.white54,
              size: 40,
            ),
          ),
        );
      },
    ).animate().shake();
  }
}

class PremiumProfilePage extends StatefulWidget {
  final VoidCallback onInteract;
  const PremiumProfilePage({super.key, required this.onInteract});

  @override
  State<PremiumProfilePage> createState() => _PremiumProfilePageState();
}

class _PremiumProfilePageState extends State<PremiumProfilePage> {
  int _followers = 12053;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          Container(
            height: 250,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.indigo],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Senior Flutter Dev',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Optimization Enthusiast',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStat('Posts', '142'),
              GestureDetector(
                onTap: () {
                  setState(() => _followers++);
                  widget.onInteract();
                },
                child: _buildStat('Followers', '$_followers\n(Tap me)'),
              ),
              _buildStat('Following', '431'),
            ],
          ),
        ],
      ),
    ).animate().shake();
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
      ],
    );
  }
}

class SettingsSimulatorPage extends StatelessWidget {
  final LazyStackController controller;
  final IndexdAnimationType currentAnimation;
  final Function(IndexdAnimationType) onAnimationChanged;
  final Function(String) onSettingsChanged;

  const SettingsSimulatorPage({
    super.key,
    required this.controller,
    required this.currentAnimation,
    required this.onAnimationChanged,
    required this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16).copyWith(bottom: 100),
      children: [
        const Text(
          'Cache Settings',
          style: TextStyle(
            color: Colors.deepPurpleAccent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          title: const Text(
            'Dispose Unused Pages',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: const Text(
            'Aggressively removes inactive pages',
            style: TextStyle(color: Colors.white54),
          ),
          trailing: Switch(
            value: controller.disposeUnused,
            activeColor: Colors.deepPurpleAccent,
            onChanged: (val) {
              // Simulated for UI
            },
          ),
        ),
        ListTile(
          title: const Text(
            'Simulate Memory Pressure',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: const Text(
            'Triggers OS low memory warning handler',
            style: TextStyle(color: Colors.white54),
          ),
          trailing: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              controller.didHaveMemoryPressure();
              onSettingsChanged("SIMULATED MEMORY PRESSURE - Cleared Cache");
            },
            child: const Text('Flush', style: TextStyle(color: Colors.white)),
          ),
        ),
        const Divider(color: Colors.white24, height: 32),
        const Text(
          'Transitions',
          style: TextStyle(
            color: Colors.deepPurpleAccent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          title: const Text(
            'Animation Style',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: const Text(
            'Native RenderBox transitions',
            style: TextStyle(color: Colors.white54),
          ),
          trailing: DropdownButton<IndexdAnimationType>(
            value: currentAnimation,
            dropdownColor: const Color(0xFF2A2A2A),
            style: const TextStyle(color: Colors.deepPurpleAccent),
            underline: const SizedBox(),
            items: IndexdAnimationType.values.map((anim) {
              return DropdownMenuItem(value: anim, child: Text(anim.name));
            }).toList(),
            onChanged: (val) {
              if (val != null) onAnimationChanged(val);
            },
          ),
        ),
        const Divider(color: Colors.white24, height: 32),
        const Text(
          'Information',
          style: TextStyle(
            color: Colors.deepPurpleAccent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const ListTile(
          leading: Icon(Icons.info_outline, color: Colors.white54),
          title: Text(
            'Optimized Architecture',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            'This package now usages native ChangeNotifier bindings, '
            'synchronous micro-task evictions, and zero-allocation KeyedSubtrees '
            'to ensure maximum 120fps performance.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      ],
    ).animate().shake();
  }
}
