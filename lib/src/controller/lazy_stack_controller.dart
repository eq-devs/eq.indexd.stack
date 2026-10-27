import 'dart:collection';

import 'package:flutter/widgets.dart';

/// Sets [LazyStackController.pageCount]. Called by `LazyLoadIndexedStack`
/// only; not exported from the package.
void syncLazyStackPageCount(LazyStackController controller, int count) {
  controller._pageCount = count;
}

/// Controls which pages are loaded, cached, and currently visible in a
/// `LazyLoadIndexedStack`.
class LazyStackController extends ChangeNotifier with WidgetsBindingObserver {
  int _currentIndex;
  final int maxCachedPages;
  final List<int> preloadIndexes;
  final bool disposeUnused;

  /// Whether the cache is flushed on OS memory-pressure warnings.
  final bool listenToMemoryPressure;

  @Deprecated('Use listenToMemoryPressure. Will be removed in 0.5.0.')
  bool get isListenMemoryPressure => listenToMemoryPressure;

  final LinkedHashSet<int> _loadedPages = LinkedHashSet<int>();
  Set<int>? _loadedIndexesView;
  late final Set<int> _preloadSet = Set<int>.of(preloadIndexes);

  /// Total number of pages this controller can navigate across.
  ///
  /// Kept in sync by `LazyLoadIndexedStack` from its page count. `null`
  /// before a widget attaches, which disables the upper-bound check in
  /// [switchTo] / [preloadPage] / [preloadAdjacentPages].
  int? get pageCount => _pageCount;
  int? _pageCount;

  LazyStackController({
    int initialIndex = 0,
    this.preloadIndexes = const [],
    this.disposeUnused = false,
    this.maxCachedPages = 3,
    bool listenToMemoryPressure = false,
    @Deprecated('Use listenToMemoryPressure. Will be removed in 0.5.0.')
    bool? isListenMemoryPressure,
  })  : listenToMemoryPressure =
            isListenMemoryPressure ?? listenToMemoryPressure,
        _currentIndex = initialIndex {
    _markAsUsed(initialIndex);
    for (final index in preloadIndexes) {
      _markAsUsed(index);
    }

    if (this.listenToMemoryPressure) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  Set<int> get loadedIndexes =>
      _loadedIndexesView ??= Set<int>.unmodifiable(_loadedPages);
  int get currentIndex => _currentIndex;
  bool isLoaded(int index) => _loadedPages.contains(index);

  bool _isProtected(int index) =>
      index == _currentIndex || _preloadSet.contains(index);

  @override
  void didHaveMemoryPressure() {
    _flushMemoryCache();
  }

  void _flushMemoryCache({bool notify = true}) {
    final int before = _loadedPages.length;
    _loadedPages.removeWhere((index) => !_isProtected(index));

    if (_loadedPages.length != before) {
      _loadedIndexesView = null;
      if (notify) {
        notifyListeners();
      }
    }
  }

  void _markAsUsed(int index) {
    _loadedIndexesView = null;
    _loadedPages.remove(index);
    _loadedPages.add(index);

    if (_loadedPages.length > maxCachedPages) {
      _enforceMaxSize();
    }
  }

  void switchTo(int index) {
    if (index < 0 ||
        (_pageCount != null && index >= _pageCount!) ||
        index == _currentIndex) {
      return;
    }

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

    final iterator = _loadedPages.iterator;
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

    if (_loadedPages.remove(index)) {
      _loadedIndexesView = null;
      notifyListeners();
    }
  }

  void disposePages(List<int> indexes) {
    bool changed = false;

    for (final index in indexes) {
      if (!_isProtected(index) && _loadedPages.remove(index)) {
        changed = true;
      }
    }

    if (changed) {
      _loadedIndexesView = null;
      notifyListeners();
    }
  }

  void preloadPage(int index) {
    if (index < 0 ||
        (_pageCount != null && index >= _pageCount!) ||
        _loadedPages.contains(index)) {
      return;
    }

    _markAsUsed(index);
    notifyListeners();
  }

  void preloadAdjacentPages([int range = 1]) {
    bool changed = false;
    final int? total = _pageCount;

    for (int i = 1; i <= range; i++) {
      final nextIndex = _currentIndex + i;
      final prevIndex = _currentIndex - i;

      if ((total == null || nextIndex < total) &&
          !_loadedPages.contains(nextIndex)) {
        _markAsUsed(nextIndex);
        changed = true;
      }

      if (prevIndex >= 0 && !_loadedPages.contains(prevIndex)) {
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
    if (listenToMemoryPressure) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }
}
