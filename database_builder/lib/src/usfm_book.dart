import 'package:scripture/scripture_core.dart';

import 'book_id.dart';

/// One row of the `bible` table: a verse's text, or part of it, in one
/// paragraph format.
class UsfmRow {
  const UsfmRow(this.chapter, this.verse, this.text, this.format);

  final int chapter;
  final int verse;
  final String text;
  final ParagraphFormat format;

  @override
  String toString() => '$chapter:$verse ${format.id} $text';
}

/// A book of USFM as the app stores it.
class UsfmBook {
  UsfmBook(this.code, this.bookId, this.names, this.rows, this.adjusted);

  /// The USFM book code, such as `GEN`.
  final String code;

  /// The BB of a BBCCCVVV reference.
  final int bookId;

  /// The book's names by marker: `h`, `toc1`, `toc2` and `toc3`.
  final Map<String, String> names;

  final List<UsfmRow> rows;

  /// What a lenient read changed to fit the app, by marker, with how often:
  /// markers mapped to another format, stripped, or dropped with their text.
  final Map<String, int> adjusted;

  /// The number of verses in each chapter, from chapter 1.
  List<int> get verseCounts {
    final counts = <int>[];
    for (final row in rows) {
      while (counts.length < row.chapter) {
        counts.add(0);
      }
      if (row.chapter > 0 && row.verse > counts[row.chapter - 1]) {
        counts[row.chapter - 1] = row.verse;
      }
    }
    return counts;
  }
}

/// The book ids of books outside the BSB's 66: their Paratext book numbers,
/// except that the Greek Esther and Daniel are Esther and Daniel.
const _otherBookIds = {
  'ESG': 17,
  'DAG': 27,
  'TOB': 67,
  'JDT': 68,
  'WIS': 70,
  'SIR': 71,
  'BAR': 72,
  'LJE': 73,
  'S3Y': 74,
  'SUS': 75,
  'BEL': 76,
  '1MA': 77,
  '2MA': 78,
  '3MA': 79,
  '4MA': 80,
  '1ES': 81,
  '2ES': 82,
  'MAN': 83,
  'PS2': 84,
};

/// The book id of a USFM book code, or null for a book the app can't place.
int? bookIdForCode(String code) =>
    bookAbbreviationToIdMap[code] ?? _otherBookIds[code];

/// The SBL Handbook's abbreviation of a book, by its USFM code and the name
/// the translation gives it, or null for a book the handbook doesn't list.
/// The Septuagint's Kingdoms and its Esdras B take the handbook's forms for
/// them.
String? standardAbbreviation(String code, String name) {
  final kingdoms = RegExp(r'^([1-4]) Kingdoms$').firstMatch(name);
  if (kingdoms != null) return '${kingdoms[1]} Kgdms';
  if (code == 'EZR' && name == '2 Esdras') return '2 Esd';
  return _sblAbbreviations[code];
}

const _sblAbbreviations = {
  'GEN': 'Gen',
  'EXO': 'Exod',
  'LEV': 'Lev',
  'NUM': 'Num',
  'DEU': 'Deut',
  'JOS': 'Josh',
  'JDG': 'Judg',
  'RUT': 'Ruth',
  '1SA': '1 Sam',
  '2SA': '2 Sam',
  '1KI': '1 Kgs',
  '2KI': '2 Kgs',
  '1CH': '1 Chr',
  '2CH': '2 Chr',
  'EZR': 'Ezra',
  'NEH': 'Neh',
  'EST': 'Esth',
  'ESG': 'Esth',
  'JOB': 'Job',
  'PSA': 'Ps',
  'PRO': 'Prov',
  'ECC': 'Eccl',
  'SNG': 'Song',
  'ISA': 'Isa',
  'JER': 'Jer',
  'LAM': 'Lam',
  'EZK': 'Ezek',
  'DAN': 'Dan',
  'DAG': 'Dan',
  'HOS': 'Hos',
  'JOL': 'Joel',
  'AMO': 'Amos',
  'OBA': 'Obad',
  'JON': 'Jonah',
  'MIC': 'Mic',
  'NAM': 'Nah',
  'HAB': 'Hab',
  'ZEP': 'Zeph',
  'HAG': 'Hag',
  'ZEC': 'Zech',
  'MAL': 'Mal',
  'TOB': 'Tob',
  'JDT': 'Jdt',
  'WIS': 'Wis',
  'SIR': 'Sir',
  'BAR': 'Bar',
  'LJE': 'Ep Jer',
  'S3Y': 'Pr Azar',
  'SUS': 'Sus',
  'BEL': 'Bel',
  '1MA': '1 Macc',
  '2MA': '2 Macc',
  '3MA': '3 Macc',
  '4MA': '4 Macc',
  '1ES': '1 Esd',
  '2ES': '2 Esd',
  'MAN': 'Pr Man',
  'PS2': 'Ps 151',
  'MAT': 'Matt',
  'MRK': 'Mark',
  'LUK': 'Luke',
  'JHN': 'John',
  'ACT': 'Acts',
  'ROM': 'Rom',
  '1CO': '1 Cor',
  '2CO': '2 Cor',
  'GAL': 'Gal',
  'EPH': 'Eph',
  'PHP': 'Phil',
  'COL': 'Col',
  '1TH': '1 Thess',
  '2TH': '2 Thess',
  '1TI': '1 Tim',
  '2TI': '2 Tim',
  'TIT': 'Titus',
  'PHM': 'Phlm',
  'HEB': 'Heb',
  'JAS': 'Jas',
  '1PE': '1 Pet',
  '2PE': '2 Pet',
  '1JN': '1 John',
  '2JN': '2 John',
  '3JN': '3 John',
  'JUD': 'Jude',
  'REV': 'Rev',
};

/// Paragraph markers a lenient read gives a format the app has.
const _paragraphAliases = {
  'ms1': 'ms1',
  'ms2': 'ms2',
  'ms3': 'ms2',
  'cl': 's1',
  'imt': 's1',
  'imt1': 's1',
  'imt2': 's2',
  's': 's1',
  's3': 's2',
  'sd': 'b',
  'sd1': 'b',
  'sd2': 'b',
  'q': 'q1',
  'q3': 'q2',
  'q4': 'q2',
  'qm1': 'q1',
  'qm2': 'q2',
  'qc': 'pc',
  'li': 'li1',
  'li3': 'li2',
  'pi': 'pi1',
  'pi2': 'pi1',
  'ip': 'p',
  'nb': 'm',
  'lit': 'qr',
};

/// Markers a lenient read passes over, with what they hold.
const _ignored = {'cp', 'esb', 'esbe', 'mt', 'mt3', 'ide', 'rem', 'sts'};

/// Formats whose line a verse on a line of its own continues.
const _continued = {
  'p',
  'm',
  'pmo',
  'li1',
  'li2',
  'q1',
  'q2',
  'qr',
  'pc',
  'd',
  'qa',
  'pi1',
  'mi',
};

/// Reads a book of USFM into the rows the app stores.
///
/// A strict read takes the BSB's own files and throws on anything else. A
/// lenient read takes any translation's: it maps paragraph markers to the
/// nearest format the app has, strips character markers it can't show,
/// keeping their words, drops cross references, and reports each in
/// [UsfmBook.adjusted].
UsfmBook parseUsfmBook(String usfm, {bool lenient = false}) {
  final adjusted = <String, int>{};
  void adjust(String marker) => adjusted[marker] = (adjusted[marker] ?? 0) + 1;

  var lines = usfm.split(RegExp(r'\r?\n'));
  if (lenient) lines = _joinVerseLines(lines, adjust);

  final rows = <UsfmRow>[];
  final names = <String, String>{};
  String code = '';
  int bookId = 0;
  int chapter = 0;
  int verse = 0;
  bool chapterZero = false;
  String? text;
  ParagraphFormat? format;

  void insert(int verse, String text, ParagraphFormat format) {
    if (lenient && text.isEmpty && format != ParagraphFormat.b) return;
    // Text before the first chapter, such as a prologue, opens chapter 1.
    if (lenient && chapter == 0 && !chapterZero) {
      rows.add(UsfmRow(1, 0, text, format));
      return;
    }
    rows.add(UsfmRow(chapter, verse, text, format));
  }

  final parentheses = RegExp(r'[()]');

  String oldMarker = '';
  for (String newLine in lines) {
    if (newLine.trim().isEmpty) continue;

    // Normalize Words of Jesus tags (\wj and \wj*):
    // - Shift punctuation inside closing tags
    // - Normalize \wj before \v
    // - Split spans crossing verse boundaries so all verse rows are self-contained
    newLine = _normalizeUsfmLine(newLine);

    // split at a space or a newline and take the text before it
    String marker = newLine.split(RegExp(r'[ \n]'))[0];
    var remainder = newLine.substring(marker.length).trim();
    marker = marker.replaceAll(r'\', '');

    if (lenient) {
      remainder = _cleanInline(remainder, adjust);
      if (_ignored.contains(marker)) {
        adjust(marker);
        continue;
      }
      final alias = _paragraphAliases[marker];
      if (alias != null) {
        adjust(marker);
        marker = alias;
      }
    }

    // We will flag if the insert happens normally at the bottom,
    // or if we handle multiple inserts inside the switch case.
    bool insertAtBottom = true;

    switch (marker) {
      case 'id': // book
        code = remainder.split(' ').first;
        final id = lenient
            ? bookIdForCode(code)
            : bookAbbreviationToIdMap[_getBookCode(remainder)];
        if (id == null) throw FormatException('Unknown book: $code');
        bookId = id;
        format = null;
        continue;
      case 'h': // book title
      case 'toc1': // book title
      case 'toc2': // book title
      case 'toc3': // book abbreviation
        names[marker] = remainder;
        continue;
      case 'usfm': // format identifier
      case 'mt1': // book title
      case 'mt2': // book title
        // ignore
        continue;
      case 'c': // chapter
        chapter = _getChapter(remainder);
        chapterZero = chapterZero || chapter == 0;
        verse = 0;
        continue;
      case 'r': // cross reference
        format = ParagraphFormat.r;
        if (remainder.isEmpty) continue;

        text = remainder
            .replaceAll(parentheses, '')
            .replaceAll(RegExp(r'\\ref\s+'), '') // removes "\ref "
            .replaceAll(
              RegExp(r'\|.*?\\ref\*'),
              '',
            ) // removes "|JHN 1:1-5\ref*"
            .replaceAll(r'\ref*', '') // removes remaining "\ref*"
            .trim();
        break; // Let it insert at the bottom
      case 'p': // standard paragraph marker
      case 's1': // section heading level 1
      case 's2': // section heading level 2
      case 'ms': // major section (Psalms)
      case 'ms1' when lenient: // major section
      case 'ms2' when lenient: // major section
      case 'mr': // major section range (Psalms)
      case 'qa': // Acrostic heading (Psalm 119)
      case 'm': // margin
      case 'pmo': // indented paragraph margin opening
      case 'li1': // list item level 1
      case 'li2': // list item level 2
      case 'q1': // poetry indentation level 1
      case 'q2': // poetry indentation level 2
      case 'qr': // right aligned
      case 'pi1' when lenient: // indented paragraph
      case 'mi' when lenient: // indented flush left paragraph
        format = ParagraphFormat.fromJson(marker);
        if (remainder.isEmpty) continue;

        insertAtBottom = false; // We will handle multiple inserts here

        // Auto-insert paragraph break for standard text blocks
        if (_shouldInsertBreak(oldMarker, marker)) {
          insert(verse, '', ParagraphFormat.b);
        }

        // Split the text by "\v " to separate multiple verses on the same line
        List<String> chunks = remainder.split(r'\v ');
        for (int i = 0; i < chunks.length; i++) {
          String chunk = chunks[i].trim();
          if (chunk.isEmpty) continue;

          if (i > 0 || remainder.startsWith(r'\v ')) {
            // This chunk starts with a verse number
            final verseData = _getVerse(chunk);
            verse = verseData.$1;
            text = verseData.$2;
          } else {
            // This chunk is text before any \v marker (belongs to the current verse)
            text = chunk;
          }

          insert(verse, text, format);
        }
        break;
      case 'v': // verse (if it still appears on its own line)
        insertAtBottom = false; // We will handle multiple inserts here

        if (format == null) {
          if (!lenient) {
            throw FormatException(
              'Format null at: $marker (chapter: $chapter, verse: $verse)',
            );
          }
          adjust('v');
          format = ParagraphFormat.p;
        }

        // A line starting with \v might also contain subsequent \v markers
        List<String> chunks = remainder.split(r'\v ');
        for (int i = 0; i < chunks.length; i++) {
          String chunk = chunks[i].trim();
          if (chunk.isEmpty) continue;

          final verseData = _getVerse(chunk);
          verse = verseData.$1;
          text = verseData.$2;

          insert(verse, text, format);
        }
        break;
      case 'd': // descriptive title
        format = ParagraphFormat.d;
        if (remainder.isEmpty) continue;

        insertAtBottom = false;

        List<String> chunks = remainder.split(r'\v ');
        for (int i = 0; i < chunks.length; i++) {
          String chunk = chunks[i].trim();
          if (chunk.isEmpty) continue;

          if (i > 0 || remainder.startsWith(r'\v ')) {
            // Extract the inline verse number
            final verseData = _getVerse(chunk);
            verse = verseData.$1;
            text = verseData.$2;
          } else {
            text = chunk;
            // If \d has no \v marker, it is historically verse 0.
            verse = 0;
          }

          insert(verse, text, format);
        }
        break;

      case 'b': // break
        // ignore unnecessary breaks after section headings
        if (oldMarker == 's1' || oldMarker == 's2') continue;
        format = ParagraphFormat.b;
        text = '';
        break; // Let it insert at the bottom

      case 'pc': // centered
        format = ParagraphFormat.pc;
        if (remainder.isEmpty) continue;

        insertAtBottom = false;

        // Auto-insert paragraph break for centered text blocks
        if (_shouldInsertBreak(oldMarker, marker)) {
          insert(verse, '', ParagraphFormat.b);
        }

        List<String> chunks = remainder.split(r'\v ');
        for (int i = 0; i < chunks.length; i++) {
          String chunk = chunks[i].trim();
          if (chunk.isEmpty) continue;

          if (i > 0 || remainder.startsWith(r'\v ')) {
            final verseData = _getVerse(chunk);
            verse = verseData.$1;
            text = verseData.$2;
          } else {
            text = chunk;
          }

          insert(verse, text, format);
        }
        break;
      default:
        if (!lenient) {
          throw FormatException(
            'Unknown marker: $marker (chapter: $chapter, verse: $verse)',
          );
        }
        // Any other paragraph is a plain one; anything else, passed over.
        adjust(marker);
        if (remainder.isEmpty) continue;
        format = ParagraphFormat.p;
        insertAtBottom = false;
        if (_shouldInsertBreak(oldMarker, 'p')) {
          insert(verse, '', ParagraphFormat.b);
        }
        // Its verses are verses still, as in a plain paragraph.
        final chunks = remainder.split(r'\v ');
        for (int i = 0; i < chunks.length; i++) {
          final chunk = chunks[i].trim();
          if (chunk.isEmpty) continue;
          if (i > 0 || remainder.startsWith(r'\v ')) {
            final verseData = _getVerse(chunk);
            verse = verseData.$1;
            text = verseData.$2;
          } else {
            text = chunk;
          }
          insert(verse, text!, format);
        }
    }

    // If it wasn't handled inside the switch case, insert it now
    if (insertAtBottom) {
      insert(verse, text!, format);
    }

    text = null;
    oldMarker = marker;
  }

  // A chapter numbered 0, such as Susanna's at the head of the Greek Daniel,
  // follows the book's last chapter, since the app's chapters count from 1.
  if (chapterZero) {
    final last = rows.fold(0, (m, r) => r.chapter > m ? r.chapter : m);
    final moved = [
      for (final r in rows)
        if (r.chapter == 0) UsfmRow(last + 1, r.verse, r.text, r.format),
    ];
    rows
      ..removeWhere((r) => r.chapter == 0)
      ..addAll(moved);
    adjust('c 0');
  }

  return UsfmBook(code, bookId, names, rows, adjusted);
}

/// Joins a verse on a line of its own to the paragraph line it continues,
/// as the BSB's files have it.
List<String> _joinVerseLines(List<String> lines, void Function(String) adjust) {
  final joined = <String>[];
  for (final line in lines) {
    if (line.startsWith(r'\v ') && joined.isNotEmpty) {
      final previous = joined.last.split(' ').first.replaceAll(r'\', '');
      final format = _paragraphAliases[previous] ?? previous;
      if (_continued.contains(format) || previous == 'v') {
        joined.last = '${joined.last} $line';
        continue;
      }
    }
    joined.add(line);
  }
  return joined;
}

final _footnote = RegExp(r'\\f\s.*?\\f\*');
final _crossReference = RegExp(r'\\x\s.*?\\x\*');
final _category = RegExp(r'\\cat\s.*?\\cat\*');
final _milestone = RegExp(r'\\[a-z0-9]+-[se]\s*(\|[^\\]*)?\\\*');
final _verseLabel = RegExp(r'\\v (\d+)([a-z]*)\s*(?:\\vp ([^\\]*)\\vp\*\s*)?');
final _characterMarker = RegExp(r'\\([a-z0-9]+)(\*?)\s?');

/// The text of a line as the app can show it: inline markers it reads (`\v`,
/// `\wj` and whole footnotes) kept, and the rest stripped or dropped.
String _cleanInline(String text, void Function(String) adjust) {
  text = text.replaceAll(r'\+', r'\');
  text = text.replaceAllMapped(_crossReference, (_) {
    adjust('x');
    return '';
  });
  text = text.replaceAllMapped(_category, (_) {
    adjust('cat');
    return '';
  });
  text = text.replaceAllMapped(_milestone, (_) {
    adjust('milestone');
    return '';
  });
  // A verse's printed label, where it differs from its number, stays in the
  // text; a lettered verse, such as 22f, joins its verse.
  text = text.replaceAllMapped(_verseLabel, (m) {
    final number = m[1]!;
    final label = (m[3] ?? '').replaceAll('\u200b', '').trim();
    final printed = label.isNotEmpty
        ? label
        : m[2]!.isNotEmpty
        ? '$number${m[2]}'
        : '';
    if (printed.isEmpty) return '\\v $number ';
    adjust('vp');
    return '\\v $number $printed ';
  });
  // Footnotes keep their markers, which the renderer reads.
  final out = StringBuffer();
  var at = 0;
  for (final note in _footnote.allMatches(text)) {
    out.write(_stripCharacters(text.substring(at, note.start), adjust));
    out.write(note[0]);
    at = note.end;
  }
  out.write(_stripCharacters(text.substring(at), adjust));
  final cleaned = out.toString().replaceAll(RegExp(r'  +'), ' ').trim();
  return _placeNotes(_joinNotes(cleaned, adjust), adjust);
}

/// A whole footnote, opened with `\f` and closed with `\f*`.
const _note = r'\\f\s(?:(?!\\f\*).)*\\f\*';
final _adjacentNotes = RegExp(
  r'(\\f\s(?:(?!\\f\*).)*)\\f\*\s*\\f\s+\S\s+(?:\\fr\s[^\\]*)?((?:(?!\\f\*).)*)\\f\*',
);
final _noteAndText = RegExp('($_note)([^\\\\]*)');
final _quoted = RegExp(r'\\fq\s([^\\]*)');
final _word = RegExp(r'\S+');

/// Notes on the same words join into one, as the BSB writes them: the
/// second's text follows the first's after a semicolon, without its quote
/// of the words where it repeats the first's.
String _joinNotes(String text, void Function(String) adjust) {
  while (true) {
    final m = _adjacentNotes.firstMatch(text);
    if (m == null) return text;
    final first = m[1]!;
    var second = m[2]!.trim();
    final quote = _quoted.firstMatch(first)?[1]?.trim();
    final repeated = _quoted.matchAsPrefix(second);
    if (repeated != null && repeated[1]!.trim() == quote) {
      second = second.substring(repeated.end).trim();
    }
    if (!second.startsWith(r'\')) second = '\\ft $second';
    adjust('note joined');
    text = text.replaceRange(m.start, m.end, '$first\\ft ; $second\\f*');
  }
}

/// A note follows the words it is about, as the BSB places its notes: one
/// written before them moves past the words its quote names, or failing
/// those, past the next word, with any punctuation that closes them.
String _placeNotes(String text, void Function(String) adjust) {
  return text.replaceAllMapped(_noteAndText, (m) {
    final note = m[1]!;
    final after = m[2]!;
    if (after.isEmpty || after.startsWith(RegExp(r'\s'))) return m[0]!;
    final words = _word.allMatches(after).toList();
    final end = words[_quotedWords(note, words) - 1].end;
    adjust('note moved');
    return '${after.substring(0, end)}$note${after.substring(end)}';
  });
}

/// How many of the words after a note its quote names: as many as end the
/// quote and begin the text, or, for a quote with an ellipsis, as many as
/// reach its last part. One where the quote can't be found.
int _quotedWords(String note, List<RegExpMatch> words) {
  String plain(String w) =>
      w.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
  final quote = _quoted.firstMatch(note)?[1]?.trim();
  if (quote == null) return 1;
  final text = [for (final w in words) plain(w[0]!)];
  final parts = quote.split(RegExp(r'…|\.\.\.'));
  final named = [
    for (final w in parts.last.split(RegExp(r'\s+')))
      if (plain(w).isNotEmpty) plain(w),
  ];
  if (named.isEmpty) return 1;
  bool at(int i, List<String> seq) =>
      i + seq.length <= text.length &&
      [for (var j = 0; j < seq.length; j++) text[i + j] == seq[j]]
          .every((x) => x);
  if (parts.length > 1) {
    for (var i = 0; i < text.length; i++) {
      if (at(i, named)) return i + named.length;
    }
    return 1;
  }
  for (var k = named.length; k > 0; k--) {
    if (at(0, named.sublist(named.length - k))) return k;
  }
  return 1;
}

String _stripCharacters(String text, void Function(String) adjust) {
  return text.replaceAllMapped(_characterMarker, (m) {
    final name = m[1]!;
    final closing = m[2]!.isNotEmpty;
    if (name == 'wj' || (name == 'v' && !closing)) return m[0]!;
    if (!closing) adjust(name);
    return closing && m[0]!.endsWith(' ') ? ' ' : '';
  });
}

String _getBookCode(String textAfterMarker) {
  final index = textAfterMarker.indexOf(' ');
  return textAfterMarker.substring(0, index);
}

int _getChapter(String textAfterMarker) {
  return int.parse(textAfterMarker.split(' ').first);
}

(int, String) _getVerse(String textAfterMarker) {
  final index = textAfterMarker.indexOf(' ');
  if (index < 0) return (int.parse(textAfterMarker), '');
  final verseNumber = int.parse(textAfterMarker.substring(0, index));
  final remainder = textAfterMarker.substring(index).trim();
  return (verseNumber, remainder);
}

bool _shouldInsertBreak(String oldMarker, String currentMarker) {
  // Markers that represent the end of a previous line of text
  final previousTextBlocks = {
    'p',
    'm',
    'pmo',
    'li1',
    'li2',
    'q1',
    'q2',
    'qr',
    'pc',
    'v',
  };

  // Markers that force a new structural block to begin
  final newStructuralBlocks = {
    'p',
    'm',
    'pmo',
    'li1',
    'li2',
    'q1',
    'q2',
    'qr',
    'pc',
  };

  // If the previous line wasn't text (e.g. it was a heading or an existing '\b'), no break needed.
  if (!previousTextBlocks.contains(oldMarker)) return false;

  // If the current line is just a loose '\v' (continuing a paragraph), no break needed.
  if (!newStructuralBlocks.contains(currentMarker)) return false;

  // If we are transitioning between poetry lines (e.g., q1 -> q2, q2 -> q1, q1 -> q1),
  // we want them grouped together tightly as a stanza without breaks.
  if ({'q1', 'q2'}.contains(oldMarker) &&
      {'q1', 'q2'}.contains(currentMarker)) {
    return false;
  }

  // Otherwise, this is a new block element and it gets a break!
  return true;
}

String _normalizeUsfmLine(String line) {
  // Strip [’’] quote validation artifacts from Paratext/USFM
  if (line.contains('[’’]')) {
    line = line.replaceAll('[’’]', '');
  }

  // Strip accidental 'vvv' interlinear tags that leaked into the text
  if (line.contains('vvv')) {
    line = line
        .replaceAll(RegExp(r'\(\s*vvv\s*'), '(')
        .replaceAll(RegExp(r'\bvvv\s+'), '')
        .replaceAll('vvv', '');
  }

  if (!line.contains(r'\wj')) return line;

  // 1. Shift trailing quotes/punctuation before \wj* so word boundaries remain intact
  // e.g. "receive.’\wj*”" -> "receive.’”\wj*"
  line = line.replaceAllMapped(
    RegExp(r'\\wj\*([”\)?]+)'),
    (m) => '${m[1]}\\wj*',
  );

  // 2. Normalize \wj before \v
  // e.g. "\p \wj \v 15 “Let" -> "\p \v 15 \wj “Let"
  line = line.replaceAllMapped(
    RegExp(r'\\wj\s*\\v\s*(\d+)'),
    (m) => '\\v ${m[1]} \\wj ',
  );

  // 3. Balance \wj spans across verse boundaries
  // While \v appears inside \wj ... \wj*, close \wj* before \v and reopen \wj after
  while (true) {
    final match = RegExp(r'\\wj(?![*a-zA-Z])((?:(?!\\wj\*).)*?)\\v\s*(\d+)')
        .firstMatch(line);
    if (match == null) break;
    final prefix = line.substring(0, match.start);
    final inside = match.group(1)!;
    final verseNum = match.group(2)!;
    final rest = line.substring(match.end);
    line = '$prefix\\wj$inside\\wj* \\v $verseNum \\wj$rest';
  }

  return line;
}
