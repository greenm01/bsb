import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:database_builder/database_builder.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// A translation the app can open: the bundled BSB, or one a reader
/// imported from a zip of USFM files.
class Translation {
  const Translation({required this.id, required this.name, this.path});

  /// What highlights and notes record, such as `bsb` or `oleb`.
  final String id;
  final String name;

  /// The imported database, or null for the bundled BSB.
  final String? path;

  bool get isBsb => path == null;

  static const bsb = Translation(id: 'bsb', name: 'Berean Standard Bible');
}

/// The result of an import: the translation, and what it left out.
class TranslationImport {
  TranslationImport(this.translation, this.skippedBooks, this.adjusted);

  final Translation translation;

  /// Files the app couldn't place, such as front matter or a glossary.
  final List<String> skippedBooks;

  /// What reading the books changed to fit the app, by marker.
  final Map<String, int> adjusted;
}

const booksTable = 'books';
const metaTable = 'meta';

/// The translations readers import, each a database in the app's support
/// directory.
class TranslationStore {
  TranslationStore({Future<Directory> Function()? directory})
    : _directory = directory ?? _defaultDirectory;

  final Future<Directory> Function() _directory;

  static Future<Directory> _defaultDirectory() async => Directory(
    join((await getApplicationSupportDirectory()).path, 'translations'),
  );

  /// The BSB, then every imported translation by name.
  Future<List<Translation>> list() async {
    final dir = await _directory();
    final imported = <Translation>[];
    if (dir.existsSync()) {
      for (final file in dir.listSync().whereType<File>()) {
        if (extension(file.path) != '.db') continue;
        // A connection of its own: the shared one may be the translation the
        // reader has open, which closing it here would close too.
        final db = await openReadOnlyDatabase(file.path, singleInstance: false);
        try {
          final rows = await db.query(metaTable);
          final meta = {for (final r in rows) r['key']: r['value'] as String};
          imported.add(
            Translation(
              id: basenameWithoutExtension(file.path),
              name: meta['name'] ?? basenameWithoutExtension(file.path),
              path: file.path,
            ),
          );
        } finally {
          await db.close();
        }
      }
    }
    imported.sort((a, b) => a.name.compareTo(b.name));
    return [Translation.bsb, ...imported];
  }

  Future<Translation?> byId(String id) async {
    for (final t in await list()) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Builds a translation's database from a zip of USFM files, one book to
  /// a file, replacing any earlier import under the same id.
  Future<TranslationImport> importZip(List<int> zip, String name) async {
    final id = idForName(name);
    if (id == 'bsb' || id.isEmpty) {
      throw FormatException('Choose another name than "$name".');
    }
    final read = await Isolate.run(() => _readZip(zip));
    if (read.books.isEmpty) {
      throw const FormatException('The zip has no books the app can read.');
    }

    final dir = await _directory();
    await dir.create(recursive: true);
    final path = join(dir.path, '$id.db');
    final staged = '$path.tmp';
    await deleteDatabase(staged);
    final db = await openDatabase(staged);
    try {
      await db.execute(Schema.createBsbTable);
      await db.execute(Schema.createBibleIndexes);
      await db.execute('''
        CREATE TABLE $booksTable (
          id INTEGER PRIMARY KEY,
          code TEXT NOT NULL,
          name TEXT NOT NULL,
          reference_name TEXT NOT NULL,
          short_name TEXT NOT NULL,
          position INTEGER NOT NULL,
          verse_counts TEXT NOT NULL
        )''');
      await db.execute(
        'CREATE TABLE $metaTable (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
      final batch = db.batch();
      batch.insert(metaTable, {'key': 'name', 'value': name});
      for (final (position, book) in read.books.indexed) {
        final shortName = book.names['toc3']?.replaceAll(RegExp(r'\.$'), '');
        final name = book.names['toc2'] ?? book.names['h'] ?? book.code;
        batch.insert(booksTable, {
          'id': book.bookId,
          'code': book.code,
          'name': book.names['h'] ?? name,
          'reference_name': name,
          'short_name': shortName == null || shortName.isEmpty
              ? book.code
              : shortName,
          'position': position,
          'verse_counts': book.verseCounts.join(','),
        });
        for (final row in book.rows) {
          batch.insert(Schema.bibleTextTable, {
            Schema.colReference:
                book.bookId * 1000000 + row.chapter * 1000 + row.verse,
            Schema.colText: row.text,
            Schema.colFormat: row.format.id,
          });
        }
      }
      await batch.commit(noResult: true);
    } finally {
      await db.close();
    }
    await deleteDatabase(path);
    await File(staged).rename(path);
    return TranslationImport(
      Translation(id: id, name: name, path: path),
      read.skipped,
      read.adjusted,
    );
  }

  Future<void> delete(Translation translation) async {
    if (translation.path != null) await deleteDatabase(translation.path!);
  }

  /// A translation's id from its name: "OLEB" is `oleb`.
  static String idForName(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

class _Read {
  _Read(this.books, this.skipped, this.adjusted);
  final List<UsfmBook> books;
  final List<String> skipped;
  final Map<String, int> adjusted;
}

/// The zip's books in the order of their file names, which eBible.org's
/// numbering makes canon order. A book whose id another file already took
/// is skipped.
_Read _readZip(List<int> zip) {
  final archive = ZipDecoder().decodeBytes(zip);
  final entries =
      archive.files
          .where(
            (f) =>
                f.isFile &&
                RegExp(r'\.u?sfm$', caseSensitive: false).hasMatch(f.name),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
  final books = <UsfmBook>[];
  final skipped = <String>[];
  final adjusted = <String, int>{};
  final ids = <int>{};
  for (final entry in entries) {
    try {
      final usfm = utf8
          .decode(entry.content, allowMalformed: true)
          .replaceFirst('\uFEFF', '');
      final book = parseUsfmBook(usfm, lenient: true);
      if (book.rows.isEmpty || !ids.add(book.bookId)) {
        skipped.add(basename(entry.name));
        continue;
      }
      books.add(book);
      book.adjusted.forEach((k, v) => adjusted[k] = (adjusted[k] ?? 0) + v);
    } on FormatException {
      skipped.add(basename(entry.name));
    }
  }
  // Numbered files ("01-GEN.usfm") give the translation's own order; files
  // named by code alone ("GEN.usfm") would sort alphabetically, so they take
  // the books' standard order.
  if (!entries.every((e) => RegExp(r'^\d').hasMatch(basename(e.name)))) {
    books.sort((a, b) => a.bookId.compareTo(b.bookId));
  }
  return _Read(books, skipped, adjusted);
}
