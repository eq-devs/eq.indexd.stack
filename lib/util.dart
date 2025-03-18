part of 'widget.dart';

final class EQIndexdStackController extends ChangeNotifier {
  EQIndexdStackController({
    required List<EQPage> pages,
    this.preloadIndexes = const [],
  }) : _pages = pages {
    _initialize();
  }

  final List<EQPage> _pages;
  late final Map<int, bool> _activatedChildren;

  final List<int> preloadIndexes;

  int _index = 0;
  int get currentIndex => _index;

  void _initialize() {
    _activatedChildren = {};

    if (_pages.isNotEmpty) {
      _activatedChildren[_pages[0].index] = true;
    }

    for (final page in _pages) {
      if (page.preload) {
        _activatedChildren[page.index] = true;
      }
    }

    for (final index in preloadIndexes) {
      if (index >= 0 && index < _pages.length) {
        _activatedChildren[index] = true;
      }
    }
  }

  void onIndex(int index) {
    if (_index != index && index >= 0 && index < _pages.length) {
      _index = index;
      _activateChild(index);
      notifyListeners();
    }
  }

  void _activateChild(int index) {
    if (!(_activatedChildren[index] ?? false)) {
      _activatedChildren[index] = true;
    }
  }

  void preloadPage(int index) {
    if (index >= 0 && index < _pages.length) {
      _activateChild(index);
      notifyListeners();
    }
  }

  void disposePage(int index) {
    if (index != _index && index >= 0 && index < _pages.length) {
      _activatedChildren[index] = false;
      notifyListeners();
    }
  }

  List<Widget> get page {
    return _pages.map((page) {
      final i = page.index;
      final isActive = _activatedChildren[i] ?? false;

      if (isActive) {
        return Visibility(
          visible: i == _index,
          maintainState: page.maintainState,
          child: page.page,
        );
      } else {
        return const SizedBox.shrink();
      }
    }).toList();
  }
}

final class EQPage {
  const EQPage({
    required this.page,
    required this.index,
    required this.maintainState,
    this.preload = false,
  });

  final Widget page;
  final int index;
  final bool maintainState;
  final bool preload;
}
