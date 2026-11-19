import 'dart:math' as math;

import 'package:bsb/app_state.dart';
import 'package:bsb/infrastructure/canon.dart';
import 'package:bsb/infrastructure/service_locator.dart';
import 'package:bsb/ui/home/chapter_chooser.dart';
import 'package:bsb/ui/settings/user_settings.dart';
import 'package:material_ui/material_ui.dart';

enum ChapterSelectionState { start, selecting, end }

class _BookChooserScope extends InheritedWidget {
  const _BookChooserScope({required this.useFullName, required super.child});

  final bool useFullName;

  static _BookChooserScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_BookChooserScope>();
  }

  @override
  bool updateShouldNotify(_BookChooserScope oldWidget) {
    return useFullName != oldWidget.useFullName;
  }
}

/// The rows of the book grid, each with the index of its section.
List<(int, List<Book>)> _gridRows(Canon canon) => [
  for (final (section, rows) in canon.gridSections.indexed)
    for (final row in rows) (section, [for (final id in row) canon[id]!]),
];

class BookChooser extends StatefulWidget {
  const BookChooser({
    super.key,
    required this.onSelected,
    this.onBookSelected,
    this.onVerseSelected,
    this.showVerseGrid,
    this.verseStyle,
    this.wideScreenBreakpoint = defaultWideScreenBreakpoint,
  });

  /// The width threshold above which full book names are displayed instead of abbreviations.
  static const double defaultWideScreenBreakpoint = 800.0;

  final void Function(int bookId, int chapter, [String? sectionHeading])
  onSelected;
  final void Function(int bookId)? onBookSelected;
  final void Function(int bookId, int chapter, int verse)? onVerseSelected;
  final bool? showVerseGrid;
  final VerseChooserStyle? verseStyle;
  final double wideScreenBreakpoint;

  @override
  State<BookChooser> createState() => _BookChooserState();
}

class _BookChooserState extends State<BookChooser> {
  final _chapterNotifier = ValueNotifier<(int, int)?>(null);
  final _overlayController = OverlayPortalController();
  final _gridKey = GlobalKey();

  Book? _activeBook;
  Rect? _activeBookRect;
  Offset? _pointerDownPosition;
  Duration? _pointerDownTime;
  Book? _startBook;

  int? get _highlightedBookId => _activeBook?.id;

  List<(int, List<Book>)> get _rows => _gridRows(Canon.current);

  Color _getRowColor(int rowIndex) {
    final colors = Theme.of(context).colorScheme;
    return _rows[rowIndex].$1.isEven
        ? colors.surfaceContainerLow
        : colors.surfaceContainerHigh;
  }

  void _onBookSelected(int bookId, int chapterCount) {
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
    if (widget.onBookSelected != null) {
      widget.onBookSelected!(bookId);
      return;
    }
    final appState = getIt.isRegistered<AppState>() ? getIt<AppState>() : null;
    final userSettings = getIt.isRegistered<UserSettings>()
        ? getIt<UserSettings>()
        : null;
    final showVerseGrid =
        widget.showVerseGrid ??
        (widget.verseStyle != null ||
            (appState?.showVerseGridNotifier.value ??
                userSettings?.showVerseGrid ??
                false));

    if (chapterCount == 1 && !showVerseGrid) {
      widget.onSelected(bookId, 1);
      return;
    }
    _chapterNotifier.value = (bookId, chapterCount);
  }

  void _goToFirstChapter(int bookId) {
    if (widget.onBookSelected != null) {
      widget.onBookSelected!(bookId);
      return;
    }
    widget.onSelected(bookId, 1);
  }

  void _goToLastChapter(int bookId, int lastChapter) {
    if (widget.onBookSelected != null) {
      widget.onBookSelected!(bookId);
      return;
    }
    widget.onSelected(bookId, lastChapter);
  }

  (double, double) _getGridSize(double fallbackWidth, double fallbackHeight) {
    final renderBox = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      return (renderBox.size.width, renderBox.size.height);
    }
    return (fallbackWidth, fallbackHeight);
  }

  Offset _getLocalPosition(Offset globalPosition, Offset fallbackLocal) {
    final renderBox = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      return renderBox.globalToLocal(globalPosition);
    }
    return fallbackLocal;
  }

  (Book?, Rect?) _getBookAndRectAt(
    Offset position,
    double totalWidth,
    double totalHeight,
  ) {
    if (position.dx < 0 ||
        position.dx > totalWidth ||
        position.dy < 0 ||
        position.dy > totalHeight) {
      return (null, null);
    }
    final rows = _rows;
    final rowCount = rows.length;
    final rowHeight = totalHeight / rowCount;
    final rowIndex = (position.dy / rowHeight).floor().clamp(0, rowCount - 1);
    final row = rows[rowIndex].$2;
    final colWidth = totalWidth / row.length;
    final colIndex = (position.dx / colWidth).floor().clamp(0, row.length - 1);
    final book = row[colIndex];
    final rect = Rect.fromLTWH(
      colIndex * colWidth,
      rowIndex * rowHeight,
      colWidth,
      rowHeight,
    );
    return (book, rect);
  }

  void _handlePointerDown(
    PointerDownEvent event,
    double fallbackWidth,
    double fallbackHeight,
  ) {
    if (_chapterNotifier.value != null) return;
    final (totalWidth, totalHeight) = _getGridSize(
      fallbackWidth,
      fallbackHeight,
    );
    final localPos = _getLocalPosition(event.position, event.localPosition);

    _pointerDownPosition = localPos;
    _pointerDownTime = event.timeStamp;

    final (book, rect) = _getBookAndRectAt(localPos, totalWidth, totalHeight);
    _startBook = book;
    if (book != null && !_overlayController.isShowing) {
      _overlayController.show();
    }
    setState(() {
      _activeBook = book;
      _activeBookRect = rect;
    });
  }

  void _handlePointerMove(
    PointerMoveEvent event,
    double fallbackWidth,
    double fallbackHeight,
  ) {
    if (_chapterNotifier.value != null || _startBook == null) return;
    final (totalWidth, totalHeight) = _getGridSize(
      fallbackWidth,
      fallbackHeight,
    );
    final localPos = _getLocalPosition(event.position, event.localPosition);

    if (localPos.dx < -50 ||
        localPos.dx > totalWidth + 50 ||
        localPos.dy < -50 ||
        localPos.dy > totalHeight + 50) {
      if (_activeBook != null) {
        if (_overlayController.isShowing) {
          _overlayController.hide();
        }
        setState(() {
          _activeBook = null;
          _activeBookRect = null;
        });
      }
      return;
    }

    final (book, rect) = _getBookAndRectAt(localPos, totalWidth, totalHeight);
    if (book != _activeBook || rect != _activeBookRect) {
      if (book != null) {
        if (!_overlayController.isShowing) {
          _overlayController.show();
        }
      } else {
        if (_overlayController.isShowing) {
          _overlayController.hide();
        }
      }
      setState(() {
        _activeBook = book;
        _activeBookRect = rect;
      });
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
    if (_chapterNotifier.value != null) return;
    final localPos = _getLocalPosition(event.position, event.localPosition);

    final startBook = _startBook;
    final activeBook = _activeBook;
    final downPos = _pointerDownPosition;
    final downTime = _pointerDownTime;

    _pointerDownPosition = null;
    _pointerDownTime = null;
    _startBook = null;
    setState(() {
      _activeBook = null;
      _activeBookRect = null;
    });

    if (startBook == null || downPos == null || downTime == null) return;

    final delta = localPos - downPos;
    final duration = event.timeStamp - downTime;
    final velocityY = duration.inMilliseconds > 0
        ? delta.dy / (duration.inMilliseconds / 1000.0)
        : 0.0;

    final isVerticalSwipe =
        delta.dy.abs() >= 25.0 &&
        delta.dy.abs() > delta.dx.abs() * 1.5 &&
        duration.inMilliseconds <= 500 &&
        velocityY.abs() >= 250.0;

    if (isVerticalSwipe) {
      if (delta.dy < 0) {
        _goToFirstChapter(startBook.id);
      } else {
        _goToLastChapter(startBook.id, startBook.chapterCount);
      }
    } else if (activeBook != null) {
      _onBookSelected(activeBook.id, activeBook.chapterCount);
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
    _pointerDownPosition = null;
    _pointerDownTime = null;
    _startBook = null;
    if (_activeBook != null) {
      setState(() {
        _activeBook = null;
        _activeBookRect = null;
      });
    }
  }

  Widget _buildPopup(BuildContext context) {
    if (_activeBook == null || _activeBookRect == null) {
      return const SizedBox.shrink();
    }
    final renderBox = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize || !renderBox.attached) {
      return const SizedBox.shrink();
    }

    final overlayState = Overlay.maybeOf(context);
    final overlayRenderBox =
        overlayState?.context.findRenderObject() as RenderBox?;

    final Offset tileTopLeft;
    final Offset tileCenter;
    final double overlayWidth;

    if (overlayRenderBox != null &&
        overlayRenderBox.hasSize &&
        overlayRenderBox.attached) {
      tileTopLeft = renderBox.localToGlobal(
        _activeBookRect!.topLeft,
        ancestor: overlayRenderBox,
      );
      tileCenter = renderBox.localToGlobal(
        _activeBookRect!.center,
        ancestor: overlayRenderBox,
      );
      overlayWidth = overlayRenderBox.size.width;
    } else {
      tileTopLeft = renderBox.localToGlobal(_activeBookRect!.topLeft);
      tileCenter = renderBox.localToGlobal(_activeBookRect!.center);
      overlayWidth = MediaQuery.sizeOf(context).width;
    }

    final theme = Theme.of(context);
    final book = _activeBook!;
    final fullName = Canon.current[book.id]?.name ?? book.shortName;

    final textStyle =
        theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
        ) ??
        TextStyle(
          color: theme.colorScheme.onPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        );

    final textPainter = TextPainter(
      text: TextSpan(text: fullName, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    const paddingH = 16.0;
    const paddingV = 10.0;
    final popupWidth = textPainter.width + paddingH * 2;
    final popupHeight = textPainter.height + paddingV * 2;

    var left = tileCenter.dx - popupWidth / 2;
    left = left.clamp(8.0, math.max(8.0, overlayWidth - popupWidth - 8.0));

    const verticalGap = 12.0;
    var top = tileTopLeft.dy - popupHeight - verticalGap;
    final topPadding = MediaQuery.paddingOf(context).top;
    if (top < topPadding + 4.0) {
      top = topPadding + 4.0;
    }

    return Positioned(
      key: const ValueKey('book_chooser_popup'),
      left: left,
      top: top,
      child: IgnorePointer(
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.primary,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: paddingH,
              vertical: paddingV,
            ),
            child: Text(fullName, style: textStyle),
          ),
        ),
      ),
    );
  }

  Expanded _buildRow(int rowIndex) {
    final row = _rows[rowIndex].$2;
    final color = _getRowColor(rowIndex);
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final book in row)
            BookItem(
              title: book.shortName,
              fullName: Canon.current[book.id]?.name,
              color: color,
              onTap: _onBookSelected,
              onSwipeUp: _goToFirstChapter,
              onSwipeDown: _goToLastChapter,
              bookId: book.id,
              chapterCount: book.chapterCount,
              isHighlighted: _highlightedBookId == book.id,
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
    _chapterNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final useFullName = width >= widget.wideScreenBreakpoint;

        return _BookChooserScope(
          useFullName: useFullName,
          child: OverlayPortal(
            controller: _overlayController,
            overlayChildBuilder: _buildPopup,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Listener(
                  key: _gridKey,
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => _handlePointerDown(e, width, height),
                  onPointerMove: (e) => _handlePointerMove(e, width, height),
                  onPointerUp: _handlePointerUp,
                  onPointerCancel: _handlePointerCancel,
                  child: Column(
                    children: [
                      for (var i = 0; i < _rows.length; i++) _buildRow(i),
                    ],
                  ),
                ),
                ValueListenableBuilder<(int, int)?>(
                  valueListenable: _chapterNotifier,
                  builder: (context, bookChapter, child) {
                    if (bookChapter == null) {
                      return const SizedBox();
                    }
                    final (bookId, chapterCount) = bookChapter;
                    return ChapterChooser(
                      bookId: bookId,
                      chapterCount: chapterCount,
                      showVerseGrid: widget.showVerseGrid,
                      verseStyle: widget.verseStyle,
                      onChapterSelected: (chapter) {
                        _chapterNotifier.value = null;
                        if (chapter == null) return;
                        widget.onSelected(bookId, chapter);
                      },
                      onSectionSelected: (chapter, sectionHeading) {
                        _chapterNotifier.value = null;
                        widget.onSelected(bookId, chapter, sectionHeading);
                      },
                      onVerseSelected: (chapter, verse) {
                        _chapterNotifier.value = null;
                        if (widget.onVerseSelected != null) {
                          widget.onVerseSelected!(bookId, chapter, verse);
                        } else {
                          widget.onSelected(bookId, chapter);
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class BookItem extends StatefulWidget {
  const BookItem({
    super.key,
    required this.title,
    this.fullName,
    required this.color,
    this.onTap,
    this.onSwipeUp,
    this.onSwipeDown,
    required this.bookId,
    required this.chapterCount,
    this.useFullName,
    this.wideScreenBreakpoint,
    this.isHighlighted = false,
  });

  final String title;
  final String? fullName;
  final Color color;
  final void Function(int bookId, int chapterCount)? onTap;
  final void Function(int bookId)? onSwipeUp;
  final void Function(int bookId, int chapter)? onSwipeDown;
  final int bookId;
  final int chapterCount;
  final bool? useFullName;
  final double? wideScreenBreakpoint;
  final bool isHighlighted;

  @override
  State<BookItem> createState() => _BookItemState();
}

class _BookItemState extends State<BookItem> {
  bool _shouldUseFullName(BuildContext context) {
    if (widget.useFullName != null) {
      return widget.useFullName!;
    }
    final scope = _BookChooserScope.of(context);
    if (scope != null) {
      return scope.useFullName;
    }
    final breakpoint =
        widget.wideScreenBreakpoint ?? BookChooser.defaultWideScreenBreakpoint;
    return MediaQuery.sizeOf(context).width >= breakpoint;
  }

  String _getDisplayTitle(BuildContext context) {
    if (_shouldUseFullName(context)) {
      return widget.fullName ??
          Canon.current[widget.bookId]?.name ??
          widget.title;
    }
    return widget.title;
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = _getDisplayTitle(context);
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outlineVariant;

    final backgroundColor = widget.isHighlighted
        ? theme.colorScheme.primary
        : widget.color;
    final textColor = widget.isHighlighted
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return Expanded(
      child: Material(
        color: backgroundColor,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                displayTitle,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 17,
                  color: textColor,
                  fontWeight: widget.isHighlighted
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
