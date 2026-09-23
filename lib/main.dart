import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() => runApp(const ModernTodoApp());

// ---------- Model ----------
enum Priority { low, medium, high }

extension PriorityX on Priority {
  String get label =>
      this == Priority.high ? 'مهم' : this == Priority.medium ? 'متوسط' : 'عادی';
  Color get color => this == Priority.high
      ? Colors.red
      : this == Priority.medium
          ? Colors.orange
          : Colors.grey;
}

const kCategories = ['همه', 'کاری', 'شخصی', 'خرید', 'درس', 'سلامتی', 'سایر'];

class SubTask {
  String title;
  bool done;
  SubTask(this.title, {this.done = false});
  Map<String, dynamic> toJson() => {'t': title, 'd': done};
  factory SubTask.fromJson(Map<String, dynamic> j) => SubTask(
        j['t'] as String,
        done: j['d'] as bool? ?? false,
      );
}

class Task {
  String title;
  bool done;
  String category;
  int priority; // 0 low 1 med 2 high
  String? due; // yyyy-MM-dd
  String note;
  List<SubTask> subs;
  int createdAt;
  Task(this.title,
      {this.done = false,
      this.category = 'شخصی',
      this.priority = 0,
      this.due,
      this.note = '',
      List<SubTask>? subs,
      int? createdAt})
      : subs = subs ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;
  Map<String, dynamic> toJson() => {
        't': title,
        'd': done,
        'c': category,
        'p': priority,
        'due': due,
        'n': note,
        'subs': subs.map((s) => s.toJson()).toList(),
        'ts': createdAt,
      };
  factory Task.fromJson(Map<String, dynamic> j) => Task(
        j['t'] as String,
        done: j['d'] as bool? ?? false,
        category: j['c'] as String? ?? 'شخصی',
        priority: (j['p'] as num?)?.toInt() ?? 0,
        due: j['due'] as String?,
        note: j['n'] as String? ?? '',
        subs: ((j['subs'] as List?) ?? [])
            .map((e) => SubTask.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        createdAt: (j['ts'] as num?)?.toInt(),
      );
  bool get overdue {
    if (due == null || done) return false;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return due!.compareTo(today) < 0;
  }
}

// ---------- App ----------
class ModernTodoApp extends StatefulWidget {
  const ModernTodoApp({super.key});
  @override
  State<ModernTodoApp> createState() => _ModernTodoAppState();
}

class _ModernTodoAppState extends State<ModernTodoApp> {
  bool dark = false;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ModernTodoList',
      debugShowCheckedModeBanner: false,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal,
          fontFamily: 'Vazirmatn'),
      darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.teal),
      home: TodoPage(
        dark: dark,
        onTheme: () => setState(() => dark = !dark),
      ),
    );
  }
}

enum SortMode { newest, oldest, priority, dueDate }

class TodoPage extends StatefulWidget {
  final bool dark;
  final VoidCallback onTheme;
  const TodoPage({super.key, required this.dark, required this.onTheme});
  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final List<Task> _tasks = [];
  final _searchCtrl = TextEditingController();
  String _filterCat = 'همه';
  bool _showDone = true;
  SortMode _sort = SortMode.newest;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('tasks_v2');
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => Task.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        setState(() {
          _tasks
            ..clear()
            ..addAll(list);
        });
        return;
      } catch (_) {}
    }
    // migrate v1
    final old = p.getString('tasks');
    if (old != null) {
      try {
        final list = (jsonDecode(old) as List)
            .map((e) => Task(e['t'] as String, done: e['d'] as bool? ?? false))
            .toList();
        setState(() {
          _tasks
            ..clear()
            ..addAll(list);
        });
        _save();
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        'tasks_v2', jsonEncode(_tasks.map((t) => t.toJson()).toList()));
  }

  List<Task> get _visible {
    var list = _tasks.where((t) {
      if (!_showDone && t.done) return false;
      if (_filterCat != 'همه' && t.category != _filterCat) return false;
      if (_query.isNotEmpty &&
          !t.title.toLowerCase().contains(_query.toLowerCase())) return false;
      return true;
    }).toList();
    switch (_sort) {
      case SortMode.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortMode.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortMode.priority:
        list.sort((a, b) => b.priority.compareTo(a.priority));
        break;
      case SortMode.dueDate:
        list.sort((a, b) => (a.due ?? '9999').compareTo(b.due ?? '9999'));
        break;
    }
    return list;
  }

  void _clearDone() {
    setState(() => _tasks.removeWhere((t) => t.done));
    _save();
  }

  void _detailSheet(Task t) {
    final noteCtrl = TextEditingController(text: t.note);
    final subCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => Padding(
          padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(c).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      hintText: 'یادداشت...',
                      border: OutlineInputBorder()),
                  onChanged: (v) {
                    t.note = v;
                    _save();
                  },
                ),
                const SizedBox(height: 12),
                Text('زیروظایف (${t.subs.where((s) => s.done).length}/${t.subs.length})',
                    style:
                        const TextStyle(fontWeight: FontWeight.bold)),
                for (var i = 0; i < t.subs.length; i++)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      t.subs[i].title,
                      style: TextStyle(
                        decoration: t.subs[i].done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    value: t.subs[i].done,
                    onChanged: (_) => setS(() {
                      setState(
                          () => t.subs[i].done = !t.subs[i].done);
                      _save();
                    }),
                    secondary: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => setS(() {
                        setState(() => t.subs.removeAt(i));
                        _save();
                      }),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: subCtrl,
                        decoration: const InputDecoration(
                            hintText: 'زیروظیفه جدید...',
                            isDense: true),
                        onSubmitted: (_) {
                          if (subCtrl.text.trim().isEmpty) return;
                          setS(() => setState(() => t.subs.add(
                              SubTask(subCtrl.text.trim()))));
                          subCtrl.clear();
                          _save();
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        if (subCtrl.text.trim().isEmpty) return;
                        setS(() => setState(() => t.subs
                            .add(SubTask(subCtrl.text.trim()))));
                        subCtrl.clear();
                        _save();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('بستن'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addSheet() {
    String title = '';
    String cat = 'شخصی';
    int pri = 1;
    DateTime? due;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => Padding(
          padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(c).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('کار جدید',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'عنوان کار...', border: OutlineInputBorder()),
                onChanged: (v) => title = v,
                onSubmitted: (_) {
                  if (title.trim().isNotEmpty) {
                    setState(() => _tasks.add(Task(title.trim(),
                        category: cat,
                        priority: pri,
                        due: due == null
                            ? null
                            : DateFormat('yyyy-MM-dd').format(due!))));
                    _save();
                    Navigator.pop(c);
                  }
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: [
                  for (final cc in kCategories.skip(1))
                    ChoiceChip(
                      label: Text(cc),
                      selected: cat == cc,
                      onSelected: (_) => setS(() => cat = cc),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('اولویت: '),
                  for (final p in Priority.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                        label: Text(p.label),
                        selected: pri == p.index,
                        selectedColor: p.color.withOpacity(0.25),
                        onSelected: (_) => setS(() => pri = p.index),
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  Text(due == null
                      ? 'مهلت: ندارد'
                      : 'مهلت: ${DateFormat('yyyy/MM/dd').format(due!)}'),
                  TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: c,
                        firstDate: DateTime.now()
                            .subtract(const Duration(days: 1)),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365 * 3)),
                        initialDate: DateTime.now(),
                      );
                      if (d != null) setS(() => due = d);
                    },
                    child: const Text('انتخاب تاریخ'),
                  ),
                  if (due != null)
                    TextButton(
                        onPressed: () => setS(() => due = null),
                        child: const Text('حذف')),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  if (title.trim().isEmpty) return;
                  setState(() => _tasks.add(Task(title.trim(),
                      category: cat,
                      priority: pri,
                      due: due == null
                          ? null
                          : DateFormat('yyyy-MM-dd').format(due!))));
                  _save();
                  Navigator.pop(c);
                },
                child: const Text('افزودن'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final doneCount = _tasks.where((t) => t.done).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ModernTodoList'),
        actions: [
          IconButton(
            icon: Icon(widget.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onTheme,
          ),
          PopupMenuButton<SortMode>(
            icon: const Icon(Icons.sort),
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (c) => const [
              PopupMenuItem(
                  value: SortMode.newest, child: Text('جدیدترین')),
              PopupMenuItem(value: SortMode.oldest, child: Text('قدیمی‌ترین')),
              PopupMenuItem(
                  value: SortMode.priority, child: Text('اولویت')),
              PopupMenuItem(
                  value: SortMode.dueDate, child: Text('نزدیک‌ترین مهلت')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: 'حذف انجام‌شده‌ها',
            onPressed: _tasks.any((t) => t.done) ? _clearDone : null,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_tasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: doneCount / _tasks.length,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$doneCount/${_tasks.length}'),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'جستجو...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final cc in kCategories)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: FilterChip(
                      label: Text(cc),
                      selected: _filterCat == cc,
                      onSelected: (_) =>
                          setState(() => _filterCat = cc),
                    ),
                  ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('انجام‌شده‌ها'),
                  selected: _showDone,
                  onSelected: (_) =>
                      setState(() => _showDone = !_showDone),
                ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const Center(child: Text('کاری نیست 🎉'))
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (c, i) {
                      final t = visible[i];
                      final pr = Priority
                          .values[t.priority.clamp(0, 2)];
                      return Dismissible(
                        key: ValueKey('${t.createdAt}-${t.title}'),
                        background: Container(color: Colors.red),
                        onDismissed: (_) {
                          setState(() => _tasks.remove(t));
                          _save();
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: ListTile(
                            leading: Checkbox(
                              value: t.done,
                              onChanged: (_) {
                                setState(() => t.done = !t.done);
                                _save();
                              },
                            ),
                            title: Text(
                              t.title,
                              style: TextStyle(
                                decoration: t.done
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Wrap(
                              spacing: 6,
                              crossAxisAlignment:
                                  WrapCrossAlignment.center,
                              children: [
                                Chip(
                                  label: Text(t.category,
                                      style:
                                          const TextStyle(fontSize: 11)),
                                  visualDensity:
                                      VisualDensity.compact,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: pr.color.withOpacity(0.15),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: Text(pr.label,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: pr.color)),
                                ),
                                if (t.due != null)
                                  Text(
                                      t.overdue
                                          ? '📅 ${t.due} — عقب‌افتاده!'
                                          : '📅 ${t.due}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: t.overdue
                                              ? Colors.red
                                              : null)),
                                if (t.note.isNotEmpty)
                                  const Text('📝 یادداشت',
                                      style: TextStyle(fontSize: 11)),
                                if (t.subs.isNotEmpty)
                                  Text(
                                      '☑ ${t.subs.where((s) => s.done).length}/${t.subs.length}',
                                      style: const TextStyle(
                                          fontSize: 11)),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  size: 20),
                              onPressed: () => _detailSheet(t),
                            ),
                            onTap: () {
                              setState(() => t.done = !t.done);
                              _save();
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSheet,
        child: const Icon(Icons.add),
      ),
    );
  }
}
