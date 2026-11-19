import 'package:bsb/infrastructure/canon.dart';
import 'package:bsb/infrastructure/reference.dart';
import 'package:database_builder/database_builder.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';

/// This class manages the whole screen while TextPageManager only
/// handles one PageView page.
class TextScreenManager {
  final titleNotifier = ValueNotifier<String>('');

  void updateTitle({required int? index}) {
    if (index == null) return;
    final (bookId, chapter) = bookAndChapterForPageIndex(index);

    SchedulerBinding.instance.addPostFrameCallback((_) {
      titleNotifier.value = _formatTitle(bookId, chapter);
    });
  }

  (int bookId, int chapter) currentBookAndChapterCount(int index) {
    final (bookId, _) = bookAndChapterForPageIndex(index);
    return (bookId, Canon.current[bookId]!.chapterCount);
  }

  (int bookId, int chapter) bookAndChapterForPageIndex(int index) {
    final canon = Canon.current;
    return canon.chapterAtPage(index % canon.pageCount);
  }

  String _formatTitle(int bookId, int chapter, [int? verse]) {
    final book = Canon.current[bookId]!.referenceName;
    return verse != null ? '$book $chapter:$verse' : '$book $chapter';
  }

  int pageIndexForBookAndChapter({required int bookId, required int chapter}) {
    return Canon.current.pageIndex(bookId, chapter)!;
  }

  Language verseLanguageLabel(int pageIndex, Reference reference) {
    final language = languageForVerse(
      bookId: reference.bookId,
      chapter: reference.chapter,
      verse: reference.verse ?? 1,
    );
    return language;
  }

  String bibleHubUrl({
    required int bookId,
    required int chapter,
    required int verse,
  }) {
    final book = bookIdToFullNameMap[bookId]!;
    var formatted = book.replaceAll(' ', '_').toLowerCase();
    formatted = formatted.replaceAll('psalm', 'psalms');
    formatted = formatted.replaceAll('song_of_solomon', 'songs');

    return 'https://biblehub.com/$formatted/$chapter-$verse.htm';
  }

  String bibleHubCrossReferenceUrl({
    required int bookId,
    required int chapter,
    required int verse,
  }) {
    return '${bibleHubUrl(bookId: bookId, chapter: chapter, verse: verse)}#crossref';
  }

  void dispose() {
    titleNotifier.dispose();
  }
}
