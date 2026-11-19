import 'package:database_builder/database_builder.dart';
import 'package:scripture/scripture_core.dart';
import 'package:test/test.dart';

/// A book laid out as USJ writers lay it out: each verse on a line of its
/// own, after the paragraph it belongs to.
const _greekStyle = r'''
\id TOB - Test
\h Tobit
\toc1 The Book of Tobit
\toc2 Tobit
\toc3 Tob.
\mt1 Tobit
\imt1 A Prologue
\ip Before the first chapter.
\c 0
\cl An Opening
\p
\v 1 Placed first.
\c 1
\ms1 A Major Section
\p
\v 1 \sc The\sc* book \add of the\add* words,\f - \cat edition\cat*\fr 1:1 \ft see \+it there\+it*\f* of Tobit.
\v 2 Who \qt-s |sid="Q1"\*was carried\qt-e |eid="Q1"\* away.\x - \cat edition\cat*\xo 1:2 \xt Gen. 1\x*
\p
\v 3 A new paragraph.
\sd2
\q1
\v 4 A line of poetry,
\q2 and its second line.
\v 4a \vp 30:1\vp* A lettered verse.
\v 5 \vp ​\vp* The last.
\esb \cat colophon\cat*
\p Written at the end.
\esbe
''';

List<String> _rows(UsfmBook book) => [for (final r in book.rows) '$r'];

void main() {
  group('a lenient read', () {
    final book = parseUsfmBook(_greekStyle, lenient: true);

    test('places the book and keeps its names', () {
      expect(book.code, 'TOB');
      expect(book.bookId, 67);
      expect(book.names, {
        'h': 'Tobit',
        'toc1': 'The Book of Tobit',
        'toc2': 'Tobit',
        'toc3': 'Tob.',
      });
    });

    test('reads verses into the paragraphs they continue', () {
      expect(_rows(book), [
        '1:0 s1 A Prologue',
        '1:0 p Before the first chapter.',
        '1:0 ms1 A Major Section',
        '1:1 p The book of the words,\\f - \\fr 1:1 \\ft see \\it there\\it*\\f* of Tobit.',
        '1:2 p Who was carried away.',
        '1:2 b ',
        '1:3 p A new paragraph.',
        '1:3 b ',
        '1:4 q1 A line of poetry,',
        '1:4 q2 and its second line.',
        '1:4 q2 30:1 A lettered verse.',
        '1:5 q2 The last.',
        '1:5 b ',
        '1:5 p Written at the end.',
        '2:0 s1 An Opening',
        '2:1 p Placed first.',
      ]);
      expect(book.verseCounts, [5, 1]);
    });

    test('reports what it changed', () {
      expect(book.adjusted, containsPair('x', 1));
      expect(book.adjusted, containsPair('add', 1));
      expect(book.adjusted, containsPair('milestone', 2));
      expect(book.adjusted, containsPair('vp', 1));
      expect(book.adjusted, containsPair('c 0', 1));
      expect(book.adjusted, containsPair('esb', 1));
    });

    test('takes the Greek Esther and Daniel as Esther and Daniel', () {
      expect(bookIdForCode('ESG'), 17);
      expect(bookIdForCode('DAG'), 27);
      expect(bookIdForCode('1MA'), 77);
      expect(bookIdForCode('GEN'), 1);
      expect(bookIdForCode('XXA'), isNull);
      expect(
        () => parseUsfmBook('\\id XXA\n', lenient: true),
        throwsFormatException,
      );
    });
  });

  test('notes follow the words they are about, one to a place', () {
    final book = parseUsfmBook(r'''
\id JHN - Test
\c 1
\p
\v 41 being interpreted, \f - \cat edition\cat*\fr 1:41 \fq Christ: \ft TR \fqa the Christ\f*\f - \fr 1:41 \fq Christ: \ft or, \fqa the anointed\f*Christ.
\v 42 he shall \f - \fr 1:42 \fq shall watch: \ft Gr. \fqa keep\f*watch against thy head, \f - \fr 1:42 \fq the heel: \ft lit. \fqa the step\f*the heel of him, and \f - \fr 1:42 \fq to … dust: \ft Gr. \fqa unto earth\f*to the dust.
''', lenient: true);
    expect(_rows(book), [
      r'1:41 p being interpreted, Christ.\f - \fr 1:41 \fq Christ: \ft TR \fqa the Christ\ft ; \ft or, \fqa the anointed\f*',
      r'1:42 p he shall watch\f - \fr 1:42 \fq shall watch: \ft Gr. \fqa keep\f* against thy head, the heel\f - \fr 1:42 \fq the heel: \ft lit. \fqa the step\f* of him, and to the dust.\f - \fr 1:42 \fq to … dust: \ft Gr. \fqa unto earth\f*',
    ]);
    expect(book.adjusted, containsPair('note joined', 1));
    expect(book.adjusted, containsPair('note moved', 4));
  });

  test('books take the SBL abbreviations, the Septuagint names theirs', () {
    expect(standardAbbreviation('MAN', 'Prayer of Manasses'), 'Pr Man');
    expect(standardAbbreviation('ISA', 'Esaias'), 'Isa');
    expect(standardAbbreviation('1SA', '1 Samuel'), '1 Sam');
    expect(standardAbbreviation('1SA', '1 Kingdoms'), '1 Kgdms');
    expect(standardAbbreviation('1KI', '3 Kingdoms'), '3 Kgdms');
    expect(standardAbbreviation('EZR', 'Ezra'), 'Ezra');
    expect(standardAbbreviation('EZR', '2 Esdras'), '2 Esd');
    expect(standardAbbreviation('XXA', 'Extra'), isNull);
  });

  test('a strict read takes the BSB layout and nothing else', () {
    final book = parseUsfmBook(r'''
\id GEN - Berean Standard Bible
\c 1
\s1 The Creation
\p \v 1 In the beginning God created the heavens and the earth. \v 2 Now the earth was formless.
\p \v 3 And God said.
''');
    expect(book.bookId, 1);
    expect(_rows(book), [
      '1:0 s1 The Creation',
      '1:1 p In the beginning God created the heavens and the earth.',
      '1:2 p Now the earth was formless.',
      '1:2 b ',
      '1:3 p And God said.',
    ]);
    expect(book.rows.first.format, ParagraphFormat.s1);
    expect(
      () => parseUsfmBook('\\id GEN x\n\\c 1\n\\ms1 Heading\n'),
      throwsFormatException,
    );
  });
}
