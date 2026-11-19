import 'package:bsb/infrastructure/verse_counts.dart';
import 'package:database_builder/database_builder.dart';

/// A book of the open translation.
class Book {
  const Book({
    required this.id,
    required this.code,
    required this.name,
    required this.referenceName,
    required this.shortName,
    required this.verseCounts,
    required this.isNewTestament,
  });

  /// The book's number, the BB of a BBCCCVVV reference.
  final int id;

  /// The USFM book code, such as `GEN`.
  final String code;

  /// The name of the book itself, such as "Psalms".
  final String name;

  /// The name before a chapter number, such as "Psalm" in "Psalm 23".
  final String referenceName;

  /// The book chooser's label, such as "Psa".
  final String shortName;

  /// The number of verses in each chapter, from chapter 1.
  final List<int> verseCounts;

  final bool isNewTestament;

  int get chapterCount => verseCounts.length;
}

/// The books of the open translation, in reading order.
class Canon {
  Canon({
    required this.translationId,
    required List<Book> books,
    required List<List<List<int>>> gridSections,
    Map<String, int>? namesToIds,
  }) : books = List.unmodifiable(books),
       gridSections = List.unmodifiable(gridSections),
       _byId = {for (final book in books) book.id: book},
       _namesToIds =
           namesToIds ??
           {
             for (final book in books) ...{
               book.name: book.id,
               book.referenceName: book.id,
             },
           },
       _firstPages = _pageOffsets(books);

  /// The BSB's 66 books, laid out as the book chooser has always shown them.
  factory Canon.bsb() {
    return Canon(
      translationId: 'bsb',
      books: [
        for (final id in bookIdToFullNameMap.keys)
          Book(
            id: id,
            code: bookIdToAbbreviationMap[id]!,
            name: bookIdToBookNameMap[id]!,
            referenceName: bookIdToFullNameMap[id]!,
            shortName: _bsbShortNames[id]!,
            verseCounts: chapterVerseCounts[id]!,
            isNewTestament: id >= 40,
          ),
      ],
      gridSections: _bsbGridSections,
      namesToIds: fullNameToBookIdMap,
    );
  }

  /// The canon every screen reads: the BSB's until another translation opens.
  static Canon current = Canon.bsb();

  /// The translation these books belong to, as its highlights and notes
  /// record it.
  final String translationId;

  final List<Book> books;

  /// The book chooser's layout: sections, shaded alternately, of rows of
  /// book ids.
  final List<List<List<int>>> gridSections;

  final Map<int, Book> _byId;
  final Map<String, int> _namesToIds;

  /// The page index of each book's first chapter, when every chapter of the
  /// canon is one page.
  final Map<int, int> _firstPages;

  Book? operator [](int? bookId) => _byId[bookId];

  /// The id of the book a reference names, as "Psalm" or "1 Corinthians".
  int? bookIdForName(String? name) => _namesToIds[name];

  /// The number of verses in a chapter, or 0 if the canon has no such chapter.
  int verseCount(int bookId, int chapter) {
    final counts = _byId[bookId]?.verseCounts;
    if (counts == null || chapter < 1 || chapter > counts.length) return 0;
    return counts[chapter - 1];
  }

  int get pageCount =>
      books.isEmpty ? 0 : _firstPages[books.last.id]! + books.last.chapterCount;

  /// The page of a chapter, counting every chapter of the canon in order.
  int? pageIndex(int bookId, int chapter) {
    final first = _firstPages[bookId];
    return first == null ? null : first + chapter - 1;
  }

  /// The book and chapter shown on a page.
  (int bookId, int chapter) chapterAtPage(int pageIndex) {
    var remaining = pageIndex;
    for (final book in books) {
      if (remaining < book.chapterCount) return (book.id, remaining + 1);
      remaining -= book.chapterCount;
    }
    return (books.first.id, 1);
  }

  static Map<int, int> _pageOffsets(List<Book> books) {
    final offsets = <int, int>{};
    var page = 0;
    for (final book in books) {
      offsets[book.id] = page;
      page += book.chapterCount;
    }
    return offsets;
  }
}

const _bsbGridSections = [
  [
    [1, 2, 3, 4, 5],
  ],
  [
    [6, 7, 8, 9, 10],
    [11, 12, 13, 14, 15, 16, 17],
  ],
  [
    [18, 19, 20, 21, 22],
  ],
  [
    [23, 24, 25, 26, 27],
  ],
  [
    [28, 29, 30, 31, 32, 33],
    [34, 35, 36, 37, 38, 39],
  ],
  [
    [40, 41, 42, 43, 44],
  ],
  [
    [45, 46, 47, 48, 49, 50, 51],
    [52, 53, 54, 55, 56, 57],
  ],
  [
    [58, 59, 60, 61],
    [62, 63, 64, 65, 66],
  ],
];

const _bsbShortNames = {
  1: 'Gen',
  2: 'Exo',
  3: 'Lev',
  4: 'Num',
  5: 'Deut',
  6: 'Josh',
  7: 'Judg',
  8: 'Ruth',
  9: '1Sam',
  10: '2Sam',
  11: '1Ki',
  12: '2Ki',
  13: '1Ch',
  14: '2Ch',
  15: 'Ezra',
  16: 'Neh',
  17: 'Est',
  18: 'Job',
  19: 'Psa',
  20: 'Prov',
  21: 'Eccl',
  22: 'Song',
  23: 'Isa',
  24: 'Jer',
  25: 'Lam',
  26: 'Ezek',
  27: 'Dan',
  28: 'Hos',
  29: 'Joel',
  30: 'Amos',
  31: 'Oba',
  32: 'Jon',
  33: 'Mic',
  34: 'Nam',
  35: 'Hab',
  36: 'Zeph',
  37: 'Hag',
  38: 'Zec',
  39: 'Mal',
  40: 'Matt',
  41: 'Mark',
  42: 'Luke',
  43: 'John',
  44: 'Acts',
  45: 'Rom',
  46: '1Co',
  47: '2Co',
  48: 'Gal',
  49: 'Eph',
  50: 'Php',
  51: 'Col',
  52: '1Th',
  53: '2Th',
  54: '1Ti',
  55: '2Ti',
  56: 'Tit',
  57: 'Phm',
  58: 'Heb',
  59: 'James',
  60: '1Pet',
  61: '2Pet',
  62: '1Jn',
  63: '2Jn',
  64: '3Jn',
  65: 'Jude',
  66: 'Rev',
};
