import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();

  try {
    await database.open();
    runApp(MyApp(database: database));
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(body: Center(child: Text('Database error: $e'))),
      ),
    );
  }
}

class Folder {
  final int id;
  final String name;
  final String createdAt;
  final int count;

  Folder(this.id, this.name, this.createdAt, this.count);

  factory Folder.fromMap(Map<String, Object?> row) {
    return Folder(
      row['id'] as int,
      row['name'] as String,
      row['created_at'] as String,
      (row['card_count'] as int?) ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return {'name': name, 'created_at': createdAt};
  }
}

class CardRecord {
  final int? id;
  final String title;
  final String suit;
  final String notes;
  final String? imageRef;
  final int folderId;

  CardRecord({
    this.id,
    required this.title,
    required this.suit,
    required this.notes,
    this.imageRef,
    required this.folderId,
  });

  factory CardRecord.fromMap(Map<String, Object?> row) {
    return CardRecord(
      id: row['id'] as int,
      title: row['title'] as String,
      suit: row['suit'] as String,
      notes: row['notes'] as String,
      imageRef: row['image_ref'] as String?,
      folderId: row['folder_id'] as int,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'title': title,
      'suit': suit,
      'notes': notes,
      'image_ref': imageRef,
      'folder_id': folderId,
    };
  }
}

class AppDatabase {
  late Database db;

  Future<void> open() async {
    final path = p.join(await getDatabasesPath(), 'fall_festival.db');

    db = await openDatabase(
      path,
      version: 2,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE guests (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            age INTEGER NOT NULL
          )
        ''');
        await createNewTables(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await createNewTables(database);
        }
      },
    );
  }

  Future<void> createNewTables(Database database) async {
    await database.execute('''
      CREATE TABLE folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        suit TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        image_ref TEXT,
        folder_id INTEGER NOT NULL,
        FOREIGN KEY (folder_id)
        REFERENCES folders(id) ON DELETE CASCADE
      )
    ''');

    await database.execute(
      'CREATE INDEX idx_cards_folder_id ON cards(folder_id)',
    );
  }

  Future<List<Map<String, Object?>>> getGuests() {
    return db.query('guests', orderBy: 'id ASC');
  }

  Future<int> addGuest(String name, int age) {
    return db.insert('guests', {'name': name.trim(), 'age': age});
  }

  Future<int> updateGuest(int id, String name, int age) {
    return db.update(
      'guests',
      {'name': name.trim(), 'age': age},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteGuest(int id) {
    return db.delete('guests', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Folder>> getFolders() async {
    final rows = await db.rawQuery('''
      SELECT f.id, f.name, f.created_at,
      COUNT(c.id) AS card_count
      FROM folders f
      LEFT JOIN cards c ON c.folder_id = f.id
      GROUP BY f.id, f.name, f.created_at
      ORDER BY f.name COLLATE NOCASE
    ''');

    return rows.map(Folder.fromMap).toList();
  }

  Future<int> addFolder(String name) {
    return db.insert('folders', {
      'name': name.trim(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<int> deleteFolder(int id) {
    return db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CardRecord>> getCards(int folderId) async {
    final rows = await db.query(
      'cards',
      where: 'folder_id = ?',
      whereArgs: [folderId],
      orderBy: 'title COLLATE NOCASE ASC, id ASC',
    );

    return rows.map(CardRecord.fromMap).toList();
  }

  Future<int> saveCard(CardRecord card) {
    if (card.id == null) {
      return db.insert('cards', card.toMap());
    }

    return db.update(
      'cards',
      card.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  Future<int> deleteCard(int id) {
    return db.delete('cards', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> getInfo() async {
    final version = await db.getVersion();
    final keys = await db.rawQuery('PRAGMA foreign_keys');
    final relations = await db.rawQuery('PRAGMA foreign_key_list(cards)');
    final indexes = await db.rawQuery('PRAGMA index_list(cards)');
    final guests = await getGuests();

    return 'Database: fall_festival.db\n\n'
        'Version: $version\n\n'
        'Foreign keys: $keys\n\n'
        'Card relationships: $relations\n\n'
        'Indexes: $indexes\n\n'
        'Original guest count: ${guests.length}\n\n'
        'Original records:\n$guests';
  }
}

class MyApp extends StatelessWidget {
  final AppDatabase? database;

  const MyApp({super.key, this.database});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Card Collection',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepOrange,
        scaffoldBackgroundColor: const Color(0xfffaf8f5),
      ),
      home: database == null
          ? const Scaffold(body: Center(child: Text('Database not connected')))
          : FolderScreen(database: database!),
    );
  }
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

Future<bool> confirmDelete(BuildContext context, String name) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete Item'),
      content: Text('Delete "$name"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  return result ?? false;
}

class FolderScreen extends StatefulWidget {
  final AppDatabase database;

  const FolderScreen({super.key, required this.database});

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  List<Folder> folders = [];
  bool loading = true;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadFolders();
  }

  Future<void> loadFolders() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await widget.database.getFolders();
      if (!mounted) return;
      setState(() => folders = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> addFolder() async {
    String name = '';

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => name = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, name),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (!mounted || result == null) return;

    if (result.trim().isEmpty) {
      showMessage(context, 'Folder name cannot be empty');
      return;
    }

    setState(() => busy = true);

    try {
      final id = await widget.database.addFolder(result);
      if (!mounted) return;
      showMessage(context, 'Folder saved with ID $id');
      await loadFolders();
    } catch (e) {
      if (!mounted) return;
      showMessage(context, 'Could not save folder: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> removeFolder(Folder folder) async {
    final yes = await confirmDelete(
      context,
      '${folder.name} and all its cards',
    );

    if (!mounted || !yes) return;

    setState(() => busy = true);

    try {
      final count = await widget.database.deleteFolder(folder.id);
      if (!mounted) return;
      showMessage(context, '$count folder deleted');
      await loadFolders();
    } catch (e) {
      if (!mounted) return;
      showMessage(context, 'Delete failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void openGuests() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GuestScreen(database: widget.database)),
    );
  }

  void openInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InfoScreen(database: widget.database)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Card Collection'),
        actions: [
          IconButton(
            tooltip: 'Festival Guests',
            icon: const Icon(Icons.people_outline),
            onPressed: busy ? null : openGuests,
          ),
          IconButton(
            tooltip: 'Database Info',
            icon: const Icon(Icons.storage_outlined),
            onPressed: busy ? null : openInfo,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: busy ? null : loadFolders,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: loadFolders,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : folders.isEmpty
          ? const Center(
              child: Text(
                'No folders yet\nTap Add Folder to start',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.folder_outlined, size: 32),
                    title: Text(folder.name),
                    subtitle: Text('ID ${folder.id} - ${folder.count} cards'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: busy ? null : () => removeFolder(folder),
                    ),
                    onTap: busy
                        ? null
                        : () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CardsScreen(
                                  database: widget.database,
                                  folder: folder,
                                ),
                              ),
                            );
                            if (!mounted) return;
                            await loadFolders();
                          },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: busy ? null : addFolder,
        icon: const Icon(Icons.add),
        label: const Text('Add Folder'),
      ),
    );
  }
}

class CardsScreen extends StatefulWidget {
  final AppDatabase database;
  final Folder folder;

  const CardsScreen({super.key, required this.database, required this.folder});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  List<CardRecord> cards = [];
  bool loading = true;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadCards();
  }

  Future<void> loadCards() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await widget.database.getCards(widget.folder.id);
      if (!mounted) return;
      setState(() => cards = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openCard([CardRecord? card]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CardFormScreen(
          database: widget.database,
          folderId: widget.folder.id,
          card: card,
        ),
      ),
    );

    if (!mounted) return;
    if (saved == true) await loadCards();
  }

  Future<void> removeCard(CardRecord card) async {
    final yes = await confirmDelete(context, card.title);

    if (!mounted || !yes) return;

    setState(() => busy = true);

    try {
      final count = await widget.database.deleteCard(card.id!);
      if (!mounted) return;
      showMessage(context, '$count card deleted');
      await loadCards();
    } catch (e) {
      if (!mounted) return;
      showMessage(context, 'Delete failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: busy ? null : loadCards,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : cards.isEmpty
          ? const Center(child: Text('No cards in this folder'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index];

                return Card(
                  child: ListTile(
                    leading: CardPicture(card: card),
                    title: Text(card.title),
                    subtitle: Text(
                      'ID ${card.id} - ${card.suit}\n${card.notes}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: busy ? null : () => removeCard(card),
                    ),
                    onTap: busy ? null : () => openCard(card),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: busy ? null : () => openCard(),
        icon: const Icon(Icons.add),
        label: const Text('Add Card'),
      ),
    );
  }
}

class CardPicture extends StatelessWidget {
  final CardRecord card;

  const CardPicture({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    String symbol = '♠';

    if (card.suit == 'Hearts') symbol = '♥';
    if (card.suit == 'Diamonds') symbol = '♦';
    if (card.suit == 'Clubs') symbol = '♣';

    final isRed = card.suit == 'Hearts' || card.suit == 'Diamonds';

    final fallback = Center(
      child: Text(
        symbol,
        style: TextStyle(
          fontSize: 38,
          color: isRed ? Colors.red : Colors.black87,
        ),
      ),
    );

    final reference = card.imageRef?.trim() ?? '';
    final uri = Uri.tryParse(reference);

    if (reference.isEmpty ||
        uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return SizedBox(width: 55, height: 60, child: fallback);
    }

    return SizedBox(
      width: 55,
      height: 60,
      child: Image.network(
        reference,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => fallback,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return fallback;
        },
      ),
    );
  }
}

class CardFormScreen extends StatefulWidget {
  final AppDatabase database;
  final int folderId;
  final CardRecord? card;

  const CardFormScreen({
    super.key,
    required this.database,
    required this.folderId,
    this.card,
  });

  @override
  State<CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends State<CardFormScreen> {
  final formKey = GlobalKey<FormState>();

  late TextEditingController titleController;
  late TextEditingController notesController;
  late TextEditingController imageController;

  String suit = 'Hearts';
  bool saving = false;

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(text: widget.card?.title ?? '');
    notesController = TextEditingController(text: widget.card?.notes ?? '');
    imageController = TextEditingController(text: widget.card?.imageRef ?? '');
    suit = widget.card?.suit ?? 'Hearts';
  }

  @override
  void dispose() {
    titleController.dispose();
    notesController.dispose();
    imageController.dispose();
    super.dispose();
  }

  Future<void> saveCard() async {
    if (saving || !formKey.currentState!.validate()) return;

    setState(() => saving = true);

    final image = imageController.text.trim();

    final card = CardRecord(
      id: widget.card?.id,
      title: titleController.text.trim(),
      suit: suit,
      notes: notesController.text,
      imageRef: image.isEmpty ? null : image,
      folderId: widget.folderId,
    );

    try {
      final result = await widget.database.saveCard(card);

      if (result == 0) {
        throw Exception('Card not found');
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showMessage(context, 'Save failed: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.card == null ? 'Add Card' : 'Edit Card'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: titleController,
                maxLength: 60,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'Card Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a card title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: suit,
                decoration: const InputDecoration(
                  labelText: 'Suit',
                  border: OutlineInputBorder(),
                ),
                items: ['Hearts', 'Diamonds', 'Clubs', 'Spades']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => suit = value);
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesController,
                enabled: !saving,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: imageController,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'Image URL (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: saving ? null : saveCard,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(saving ? 'Saving...' : 'Save Card'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GuestScreen extends StatefulWidget {
  final AppDatabase database;

  const GuestScreen({super.key, required this.database});

  @override
  State<GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final ageController = TextEditingController();

  List<Map<String, Object?>> guests = [];
  int? editingId;
  bool loading = true;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadGuests();
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    super.dispose();
  }

  Future<void> loadGuests() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final rows = await widget.database.getGuests();
      if (!mounted) return;
      setState(() => guests = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void startEdit(Map<String, Object?> guest) {
    setState(() {
      editingId = guest['id'] as int;
      nameController.text = guest['name'] as String;
      ageController.text = '${guest['age']}';
    });
  }

  void cancelEdit() {
    setState(() {
      editingId = null;
      nameController.clear();
      ageController.clear();
    });
  }

  Future<void> saveGuest() async {
    if (busy || !formKey.currentState!.validate()) return;

    setState(() => busy = true);

    final name = nameController.text.trim();
    final age = int.parse(ageController.text.trim());
    final currentId = editingId;

    try {
      int result;
      String message;

      if (currentId == null) {
        result = await widget.database.addGuest(name, age);
        message = 'Guest saved with ID $result';
      } else {
        result = await widget.database.updateGuest(currentId, name, age);

        if (result == 0) {
          throw Exception('Guest not found');
        }

        message = 'Updated guest ID $currentId';
      }

      if (!mounted) return;

      cancelEdit();
      showMessage(context, message);
      await loadGuests();
    } catch (e) {
      if (!mounted) return;
      showMessage(context, 'Save failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> removeGuest(Map<String, Object?> guest) async {
    final id = guest['id'] as int;
    final name = guest['name'] as String;

    final yes = await confirmDelete(context, '$name (ID $id)');

    if (!mounted || !yes) return;

    setState(() => busy = true);

    try {
      final count = await widget.database.deleteGuest(id);

      if (!mounted) return;

      if (editingId == id) cancelEdit();

      showMessage(context, 'Deleted $count guest');
      await loadGuests();
    } catch (e) {
      if (!mounted) return;
      showMessage(context, 'Delete failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fall Festival Roster'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: busy ? null : loadGuests,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            editingId == null
                ? 'Add a festival guest'
                : 'Editing guest ID $editingId',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: nameController,
                  enabled: !busy,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name cannot be blank';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: ageController,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final age = int.tryParse(value?.trim() ?? '');
                    if (age == null || age < 0 || age > 130) {
                      return 'Enter an age between 0 and 130';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: busy ? null : saveGuest,
                child: Text(editingId == null ? 'Add Guest' : 'Save Changes'),
              ),
              OutlinedButton(
                onPressed: busy || editingId == null ? null : cancelEdit,
                child: const Text('Cancel Edit'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Saved Guests: ${guests.length}',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (error != null)
            Text('Error: $error')
          else if (guests.isEmpty)
            const Text('No festival guests yet')
          else
            ...guests.map((guest) {
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${guest['id']}')),
                  title: Text('${guest['name']}'),
                  subtitle: Text('ID: ${guest['id']}  Age: ${guest['age']}'),
                  trailing: Wrap(
                    spacing: 0,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: busy ? null : () => startEdit(guest),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: busy ? null : () => removeGuest(guest),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class InfoScreen extends StatefulWidget {
  final AppDatabase database;

  const InfoScreen({super.key, required this.database});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  late Future<String> info;

  @override
  void initState() {
    super.initState();
    info = widget.database.getInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Database Info')),
      body: FutureBuilder<String>(
        future: info,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(snapshot.data!),
          );
        },
      ),
    );
  }
}
