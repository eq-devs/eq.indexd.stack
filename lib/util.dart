part of 'widget.dart';

class LazyStackController extends ChangeNotifier with WidgetsBindingObserver {
  int _currentIndex;
  final int maxCachedPages;
  final List<int> preloadIndexes;
  final bool disposeUnused;
  final List<int> removableIndexes;
  final bool isListenMemoryPressure;

  final LinkedHashMap<int, bool> _loadedPages = LinkedHashMap<int, bool>();

  LazyStackController({
    int initialIndex = 0,
    this.preloadIndexes = const [],
    this.disposeUnused = false,
    this.maxCachedPages = 3,
    this.removableIndexes = const [],
    this.isListenMemoryPressure = false,
  }) : _currentIndex = initialIndex {
    _markAsUsed(initialIndex);
    for (final index in preloadIndexes) {
      _markAsUsed(index);
    }

    if (isListenMemoryPressure) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  Set<int> get loadedIndexes => _loadedPages.keys.toSet();
  int get currentIndex => _currentIndex;
  bool get canGoBack => _currentIndex > 0;
  bool isLoaded(int index) => _loadedPages.containsKey(index);

  // Memory pressure handler
  @override
  void didHaveMemoryPressure() {
    _flushMemoryCache();
  }

  void _flushMemoryCache() {
    bool changed = false;
    final protectedIndexes = {_currentIndex, ...preloadIndexes};

    // Aggressively drop all inactive pages on memory pressure
    final iterator = _loadedPages.keys.toList();
    for (final index in iterator) {
      if (!protectedIndexes.contains(index)) {
        _loadedPages.remove(index);
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  void _markAsUsed(int index) {
    _loadedPages.remove(index);
    _loadedPages[index] = true;

    if (_loadedPages.length > maxCachedPages) {
      _enforceMaxSize();
    }
  }

  void switchTo(
    int index,
    int totalPages,
  ) {
    if (index == _currentIndex) return;

    _currentIndex = index;
    _markAsUsed(index);

    // Sync enforcement of memory size instead of double-rendering via post-frame
    if (disposeUnused) {
      _flushMemoryCache();
    } else {
      _enforceMaxSize();
    }

    notifyListeners();
  }

  void _enforceMaxSize() {
    if (_loadedPages.length <= maxCachedPages) return;

    final protectedIndexes = {_currentIndex, ...preloadIndexes};
    final iterator = _loadedPages.keys.iterator;
    final toRemove = <int>[];

    while (iterator.moveNext() &&
        (_loadedPages.length - toRemove.length) > maxCachedPages) {
      final key = iterator.current;
      if (!protectedIndexes.contains(key)) {
        toRemove.add(key);
      }
    }

    for (final key in toRemove) {
      _loadedPages.remove(key);
    }
  }

  void reset() {
    _loadedPages.clear();
    _markAsUsed(_currentIndex);
    for (final index in preloadIndexes) {
      _markAsUsed(index);
    }
    notifyListeners();
  }

  void disposePage(int index) {
    if (index == _currentIndex || preloadIndexes.contains(index)) {
      return;
    }

    if (_loadedPages.remove(index) != null) {
      notifyListeners();
    }
  }

  void disposePages(List<int> indexes) {
    bool changed = false;
    final protectedIndexes = {_currentIndex, ...preloadIndexes};

    for (final index in indexes) {
      if (!protectedIndexes.contains(index) &&
          _loadedPages.remove(index) != null) {
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  void preloadPage(int index, int totalPages) {
    if (index < 0 || index >= totalPages || _loadedPages.containsKey(index)) {
      return;
    }

    _markAsUsed(index);
    notifyListeners();
  }

  void preloadAdjacentPages(int totalPages, [int range = 1]) {
    bool changed = false;

    for (int i = 1; i <= range; i++) {
      final nextIndex = _currentIndex + i;
      final prevIndex = _currentIndex - i;

      if (nextIndex < totalPages && !_loadedPages.containsKey(nextIndex)) {
        _markAsUsed(nextIndex);
        changed = true;
      }

      if (prevIndex >= 0 && !_loadedPages.containsKey(prevIndex)) {
        _markAsUsed(prevIndex);
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _loadedPages.clear();
    if (isListenMemoryPressure) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }
}
