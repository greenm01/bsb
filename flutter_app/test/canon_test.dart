import 'package:bsb/infrastructure/canon.dart';
import 'package:bsb/infrastructure/verse_counts.dart';
import 'package:database_builder/database_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final canon = Canon.bsb();

  test('the BSB canon has the 66 books in order', () {
    expect(canon.books.map((b) => b.id), List.generate(66, (i) => i + 1));
    expect(canon[19]!.name, 'Psalms');
    expect(canon[19]!.referenceName, 'Psalm');
    expect(canon[19]!.code, 'PSA');
    expect(canon[40]!.isNewTestament, isTrue);
    expect(canon[39]!.isNewTestament, isFalse);
  });

  test('chapter and verse counts match the BSB constants', () {
    for (final book in canon.books) {
      expect(book.chapterCount, bookIdToChapterCountMap[book.id]);
      for (var c = 1; c <= book.chapterCount; c++) {
        expect(
          canon.verseCount(book.id, c),
          chapterVerseCounts[book.id]![c - 1],
        );
      }
    }
    expect(canon.verseCount(1, 51), 0);
    expect(canon.verseCount(67, 1), 0);
  });

  test('pages run through every chapter and back', () {
    expect(canon.pageCount, 1189);
    for (final book in canon.books) {
      for (var c = 1; c <= book.chapterCount; c++) {
        final page = canon.pageIndex(book.id, c)!;
        expect(page, bookIdToChapterIndexMap[book.id]! + c - 1);
        expect(canon.chapterAtPage(page), (book.id, c));
      }
    }
  });

  test('names resolve to books as the reference parser expects', () {
    fullNameToBookIdMap.forEach((name, id) {
      expect(canon.bookIdForName(name), id);
    });
    expect(canon.bookIdForName(null), isNull);
  });

  test('the book grid places every book once', () {
    final ids = [
      for (final section in canon.gridSections)
        for (final row in section) ...row,
    ];
    expect(ids, List.generate(66, (i) => i + 1));
  });
}
