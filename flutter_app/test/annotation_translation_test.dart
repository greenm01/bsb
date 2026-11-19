import 'dart:io';

import 'package:bsb/infrastructure/annotation_backup.dart';
import 'package:bsb/infrastructure/annotation_database.dart';
import 'package:bsb/infrastructure/annotation_models.dart';
import 'package:bsb/infrastructure/annotation_service.dart';
import 'package:bsb/infrastructure/canon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late String path;
  final bsb = Canon.current;

  setUp(() async {
    path = join(await getDatabasesPath(), 'user_annotations.db');
    if (File(path).existsSync()) File(path).deleteSync();
  });

  tearDown(() {
    Canon.current = bsb;
    if (File(path).existsSync()) File(path).deleteSync();
  });

  test('upgrading from version 5 files everything under the BSB', () async {
    final old = await openDatabase(
      path,
      version: 5,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE highlights (id TEXT PRIMARY KEY, book_id INTEGER NOT NULL,
            chapter INTEGER NOT NULL, start_word_id INTEGER NOT NULL,
            end_word_id INTEGER NOT NULL, color INTEGER NOT NULL, text TEXT,
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)''');
        await db.execute('''
          CREATE TABLE notes (id TEXT PRIMARY KEY, book_id INTEGER NOT NULL,
            chapter INTEGER NOT NULL, start_word_id INTEGER NOT NULL,
            end_word_id INTEGER NOT NULL, content TEXT NOT NULL,
            passage_text TEXT, created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL)''');
      },
    );
    await old.insert('highlights', {
      'id': 'h1',
      'book_id': 19,
      'chapter': 23,
      'start_word_id': 19023001001,
      'end_word_id': 19023001003,
      'color': 'yellow',
      'created_at': 0,
      'updated_at': 0,
    });
    await old.insert('notes', {
      'id': 'n1',
      'book_id': 19,
      'chapter': 23,
      'start_word_id': 19023001001,
      'end_word_id': 19023001003,
      'content': 'A note',
      'created_at': 0,
      'updated_at': 0,
    });
    await old.close();

    final helper = AnnotationDatabaseHelper();
    final highlights = await helper.getHighlightsForChapter(19, 23);
    final notes = await helper.getNotesForChapter(19, 23);
    expect(highlights.single.translationId, 'bsb');
    expect(notes.single.translationId, 'bsb');
    await (await helper.database).close();
  });

  test(
    'highlights and notes show only in the translation they were made in',
    () async {
      final service = AnnotationService(dbHelper: AnnotationDatabaseHelper());
      await service.addHighlight(
        bookId: 19,
        chapter: 23,
        startWordId: 19023001001,
        endWordId: 19023001003,
        color: HighlightColor.yellow,
      );

      Canon.current = Canon(
        translationId: 'oleb',
        books: bsb.books,
        gridSections: bsb.gridSections,
      );
      expect(await service.getHighlights(19, 23), isEmpty);
      await service.saveNote(
        bookId: 19,
        chapter: 23,
        startWordId: 19023001001,
        endWordId: 19023001003,
        content: 'In the OLEB',
      );
      // A highlight here leaves the BSB's alone, though the words overlap.
      await service.addHighlight(
        bookId: 19,
        chapter: 23,
        startWordId: 19023001002,
        endWordId: 19023001004,
        color: HighlightColor.blue,
      );
      expect(
        (await service.getHighlights(19, 23)).single.color,
        HighlightColor.blue,
      );
      expect((await service.getAllNotes()).single.translationId, 'oleb');

      Canon.current = bsb;
      final highlights = await service.getHighlights(19, 23);
      expect(highlights.single.color, HighlightColor.yellow);
      expect(highlights.single.endWordId, 19023001003);
      expect(await service.getNotes(19, 23), isEmpty);

      // A backup keeps both translations', and says whose each is.
      final backup = AnnotationBackup.fromJson(
        (await service.createBackup()).toJson(),
      );
      expect(backup.highlights.map((h) => h.translationId).toSet(), {
        'bsb',
        'oleb',
      });
      expect(backup.notes.single.translationId, 'oleb');
      await (await AnnotationDatabaseHelper().database).close();
    },
  );

  test('a backup from before translations reads as the BSB', () {
    final backup = AnnotationBackup.fromJson('''
      {"version": 3, "app": "bsb", "exported_at": "2026-09-10T15:00:00.000Z",
       "highlights": [{"id": "h1", "book_id": 19, "chapter": 32,
         "start_word_id": 19032001000, "end_word_id": 19032001005,
         "color": "yellow", "created_at": 0, "updated_at": 0}],
       "notes": [{"id": "n1", "book_id": 19, "chapter": 32,
         "start_word_id": 19032001000, "end_word_id": 19032001005,
         "content": "Note", "created_at": 0, "updated_at": 0}]}
    ''');
    expect(backup.highlights.single.translationId, 'bsb');
    expect(backup.notes.single.translationId, 'bsb');
  });
}
