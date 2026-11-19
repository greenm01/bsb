import 'package:bsb/app_state.dart';
import 'package:bsb/infrastructure/service_locator.dart';
import 'package:bsb/infrastructure/translations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// Settings → Translation: the BSB and the translations the reader
/// imported, to open, import, or delete.
class TranslationPage extends StatefulWidget {
  const TranslationPage({super.key, this.store});

  final TranslationStore? store;

  @override
  State<TranslationPage> createState() => _TranslationPageState();
}

class _TranslationPageState extends State<TranslationPage> {
  late final TranslationStore _store = widget.store ?? TranslationStore();
  final _appState = getIt<AppState>();
  late Future<List<Translation>> _translations = _store.list();

  void _refresh() => setState(() => _translations = _store.list());

  Future<void> _open(Translation translation) async {
    await _appState.openTranslation(translation);
    if (mounted) setState(() {});
  }

  Future<void> _import() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (file == null || !mounted) return;
    final name = await _askName(_suggestedName(file.name));
    if (name == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 24),
            Expanded(child: Text('Importing…')),
          ],
        ),
      ),
    );
    try {
      final result = await _store.importZip(await file.readAsBytes(), name);
      navigator.pop();
      await _open(result.translation);
      final skipped = result.skippedBooks.isEmpty
          ? ''
          : ' Skipped ${result.skippedBooks.length} files it could not place.';
      messenger.showSnackBar(
        SnackBar(content: Text('Imported ${result.translation.name}.$skipped')),
      );
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Could not import the zip: $e')),
      );
    }
    _refresh();
  }

  /// "oleb-usfm.zip" suggests "OLEB".
  static String _suggestedName(String fileName) {
    final stem = p
        .basenameWithoutExtension(fileName)
        .replaceAll(RegExp(r'[-_ ]?usfm', caseSensitive: false), '');
    return stem.length <= 6 ? stem.toUpperCase() : stem;
  }

  Future<String?> _askName(String suggestion) {
    final controller = TextEditingController(text: suggestion);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name this translation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Such as OLEB'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.pop(context, name);
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(Translation translation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${translation.name}?'),
        content: const Text(
          'Its highlights and notes stay, and come back if you import it '
          'again under the same name.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_appState.translation.id == translation.id) {
      await _open(Translation.bsb);
    }
    await _store.delete(translation);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Translation')),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<Translation>>(
          future: _translations,
          builder: (context, snapshot) {
            final translations = snapshot.data ?? const [Translation.bsb];
            final openId = _appState.translation.id;
            return ListView(
              children: [
                for (final t in translations)
                  ListTile(
                    leading: Icon(
                      t.id == openId
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    title: Text(t.name),
                    onTap: t.id == openId ? null : () => _open(t),
                    trailing: t.isBsb
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete',
                            onPressed: () => _delete(t),
                          ),
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.file_open_outlined),
                  title: const Text('Import USFM Zip'),
                  subtitle: const Text(
                    'A zip of USFM files, one to a book, such as eBible.org '
                    'offers',
                  ),
                  onTap: _import,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
