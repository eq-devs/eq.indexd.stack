part of 'widget.dart';

/// Controller for managing which pages are loaded and visible
class EQLazyStackController implements Listenable {
  int _currentIndex;
  final Set<int> _loadedIndexes = {};
  final List<int> preloadIndexes;
  final bool disposeUnused;
  final int maxCachedPages;

  final List<VoidCallback> _listeners = [];

  EQLazyStackController({
    int initialIndex = 0,
    this.preloadIndexes = const [],
    this.disposeUnused = false,
    this.maxCachedPages = 3,
  }) : _currentIndex = initialIndex {
    _loadedIndexes.add(initialIndex);
    for (final index in preloadIndexes) {
      _loadedIndexes.add(index);
    }
  }

  Set<int> get loadedIndexes => _loadedIndexes;

  int get currentIndex => _currentIndex;

  bool isLoaded(int index) => _loadedIndexes.contains(index);

  void switchTo(int index, int totalPages) {
    if (index < 0 || index >= totalPages) return;
    if (index == _currentIndex) return;

    _loadedIndexes.add(index);
    _currentIndex = index;

    if (disposeUnused && _loadedIndexes.length > maxCachedPages) {
      _cleanupUnusedPages();
    }

    _notifyListeners();
  }

  void _cleanupUnusedPages() {
    final protectedIndexes = {_currentIndex, ...preloadIndexes};
    final candidatesForRemoval =
        _loadedIndexes.difference(protectedIndexes).toList();

    while (_loadedIndexes.length > maxCachedPages &&
        candidatesForRemoval.isNotEmpty) {
      _loadedIndexes.remove(candidatesForRemoval.removeAt(0));
    }
  }

  /// Reset controller state
  void reset() {
    _loadedIndexes.clear();
    _loadedIndexes.add(_currentIndex);
    for (final index in preloadIndexes) {
      _loadedIndexes.add(index);
    }
    _notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }

  /// Dispose controller resources
  void dispose() {
    _loadedIndexes.clear();
    _listeners.clear();
  }
}
