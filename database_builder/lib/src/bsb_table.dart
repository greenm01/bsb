import 'dart:io';

import 'database_helper.dart';
import 'usfm_book.dart';
import 'utils/bsb_utils.dart';

Future<void> createBsbTable(DatabaseHelper dbHelper) async {
  final directory = Directory('bsb_usfm');

  if (!await directory.exists()) {
    print('Directory does not exist');
    return;
  }

  dbHelper.beginTransaction();

  for (String bookFilename in bibleBookFilenames) {
    print('Processing: $bookFilename');
    final file = File('${directory.path}/$bookFilename');

    if (!file.existsSync()) {
      throw Exception('${file.path} does not exist');
    }

    final book = parseUsfmBook(await file.readAsString());
    for (final row in book.rows) {
      dbHelper.insertBsbLine(
        bookId: book.bookId,
        chapter: row.chapter,
        verse: row.verse,
        text: row.text,
        format: row.format.id,
      );
    }
  }

  dbHelper.commitTransaction();
}
