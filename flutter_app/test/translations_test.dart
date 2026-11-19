import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:bsb/infrastructure/canon.dart';
import 'package:bsb/infrastructure/database.dart';
import 'package:bsb/infrastructure/translations.dart';
import 'package:database_builder/database_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _genesis = r'''
\id GEN - A Test Translation
\h Genesis
\toc2 Genesis
\toc3 Gen.
\c 1
\p
\v 1 In the beginning God made the heaven and the earth.
\v 2 But the earth was unsightly.
\c 2
\p
\v 1 And the heavens and the earth were finished.
''';

const _tobit = r'''
\id TOB - A Test Translation
\h Tobit
\toc2 Tobit
\toc3 Tob.
\c 1
\p
\v 1 The book of the words of Tobit.
''';

const _matthew = r'''
\id MAT - A Test Translation
\h Matthew
\toc2 Matthew
\toc3 Mat.
\c 1
\p
\v 1 The book of the generation of Jesus Christ.
''';

List<int> _zip(Map<String, String> files) {
  final archive = Archive();
  files.forEach((name, text) {
    final bytes = utf8.encode(text);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  return ZipEncoder().encode(archive);
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory dir;
  late TranslationStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('translations');
    store = TranslationStore(directory: () async => dir);
  });

  tearDown(() {
    Canon.current = Canon.bsb();
    dir.deleteSync(recursive: true);
  });

  test('a zip imports as a translation the app lists and can delete', () async {
    final result = await store.importZip(
      _zip({
        '02-GEN.usfm': _genesis,
        '41-MAT.usfm': _matthew,
        '68-TOB.usfm': _tobit,
        '00-FRT.usfm': '\\id FRT\n\\p Front matter.\n',
        '03-GEN.usfm': _genesis,
      }),
      'Test Bible',
    );
    expect(result.translation.id, 'test-bible');
    expect(result.skippedBooks, ['00-FRT.usfm', '03-GEN.usfm']);

    final listed = await store.list();
    expect(listed.map((t) => t.name), ['Berean Standard Bible', 'Test Bible']);
    expect(listed.first.isBsb, isTrue);

    await store.delete(listed.last);
    expect((await store.list()).map((t) => t.id), ['bsb']);
  });

  test('the BSB name is taken', () {
    expect(
      () => store.importZip(_zip({'02-GEN.usfm': _genesis}), 'BSB'),
      throwsFormatException,
    );
  });

  test(
    'opening a translation reads its text and canon, and the BSB returns',
    () async {
      final imported = await store.importZip(
        _zip({
          '02-GEN.usfm': _genesis,
          '68-TOB.usfm': _tobit,
          '41-MAT.usfm': _matthew,
        }),
        'Test Bible',
      );

      final bsb = await openDatabase(inMemoryDatabasePath);
      await bsb.execute(Schema.createBsbTable);
      await bsb.execute(Schema.createVerseSearchTable);
      final helper = DatabaseHelper()..setDatabaseForTesting(bsb);
      helper.setUseBritishSpelling(true);

      final canon = await helper.openTranslation(imported.translation);
      expect(canon.translationId, 'test-bible');
      expect(canon.isBsb, isFalse);
      // The zip's order, with the testaments apart in the book chooser.
      expect(canon.books.map((b) => b.code), ['GEN', 'TOB', 'MAT']);
      expect(canon.gridSections, [
        [
          [1, 67],
        ],
        [
          [40],
        ],
      ]);
      expect(canon[1]!.verseCounts, [2, 1]);
      expect(canon[67]!.shortName, 'Tob');
      expect(canon[40]!.shortName, 'Matt');
      expect(canon.pageCount, 4);
      expect(helper.useBritishSpelling, isFalse);

      final lines = await helper.getChapter(67, 1);
      expect(lines.single.text, 'The book of the words of Tobit.');
      final found = await helper.searchVerses(query: 'Tobit');
      expect(found.map((r) => r.reference.bookId), [67]);

      expect((await helper.openTranslation(Translation.bsb)).isBsb, isTrue);
      expect(helper.useBritishSpelling, isTrue);
      expect(await helper.getChapter(67, 1), isEmpty);
    },
  );
}
