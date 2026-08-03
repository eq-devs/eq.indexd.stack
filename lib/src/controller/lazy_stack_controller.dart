import 'dart:collection';

import 'package:flutter/widgets.dart';

/// Controls which pages are loaded, cached, and currently visible in a
/// `LazyLoadIndexedStack`.
class LazyStackController extends ChangeNotifier with WidgetsBindingObserver {
  int _currentIndex;
  final int maxCachedPages;
  final List<int> preloadIndexes;
  final bool disposeUnused;
  final bool isListenMemoryPressure;

  final LinkedHashMap<int, bool> _loadedPages = LinkedHashMap<int, bool>();
  Set<int>? _loadedIndexesView;
  late final Set<int> _preloadSet = Set<int>.of(preloadIndexes);

  LazyStackController({
    int initialIndex = 0,
    this.preloadIndexes = const [],
    this.disposeUnused = false,
    this.maxCachedPages = 3,
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

  Set<int> get loadedIndexes =>
      _loadedIndexesView ??= Set<int>.unmodifiable(_loadedPages.keys);
  int get currentIndex => _currentIndex;
  bool get canGoBack => _currentIndex > 0;
  bool isLoaded(int index) => _loadedPages.containsKey(index);

  bool _isProtected(int index) =>
      index == _currentIndex || _preloadSet.contains(index);

  @override
  void didHaveMemoryPressure() {
    _flushMemoryCache();
  }

  void _flushMemoryCache({bool notify = true}) {
    bool changed = false;

    final iterator = _loadedPages.keys.toList();
    for (final index in iterator) {
      if (!_isProtected(index)) {
        _loadedPages.remove(index);
        changed = true;
      }
    }

    if (changed) {
      _loadedIndexesView = null;
      if (notify) {
        notifyListeners();
      }
    }
  }

  void _markAsUsed(int index) {
    _loadedIndexesView = null;
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
    if (index < 0 || index >= totalPages || index == _currentIndex) return;

    _currentIndex = index;
    _markAsUsed(index);

    // _markAsUsed already calls _enforceMaxSize internally.
    // Only flush aggressively if disposeUnused is enabled. Suppress its
    // notify so the switch results in a single rebuild.
    if (disposeUnused) {
      _flushMemoryCache(notify: false);
    }

    notifyListeners();
  }

  void _enforceMaxSize() {
    if (_loadedPages.length <= maxCachedPages) return;

    final iterator = _loadedPages.keys.iterator;
    final toRemove = <int>[];

    while (iterator.moveNext() &&
        (_loadedPages.length - toRemove.length) > maxCachedPages) {
      final key = iterator.current;
      if (!_isProtected(key)) {
        toRemove.add(key);
      }
    }

    for (final key in toRemove) {
      _loadedPages.remove(key);
    }
    if (toRemove.isNotEmpty) {
      _loadedIndexesView = null;
    }
  }

  void reset() {
    _loadedIndexesView = null;
    _loadedPages.clear();
    _markAsUsed(_currentIndex);
    for (final index in preloadIndexes) {
      _markAsUsed(index);
    }
    notifyListeners();
  }

  void disposePage(int index) {
    if (_isProtected(index)) {
      return;
    }

    if (_loadedPages.remove(index) != null) {
      _loadedIndexesView = null;
      notifyListeners();
    }
  }

  void disposePages(List<int> indexes) {
    bool changed = false;

    for (final index in indexes) {
      if (!_isProtected(index) && _loadedPages.remove(index) != null) {
        changed = true;
      }
    }

    if (changed) {
      _loadedIndexesView = null;
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
    _loadedIndexesView = null;
    _loadedPages.clear();
    if (isListenMemoryPressure) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }
}
