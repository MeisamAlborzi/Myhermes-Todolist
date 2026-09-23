import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const TodoApp());

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'لیست کارهای غلام',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const TodoPage(),
    );
  }
}

class Task {
  String title;
  bool done;
  Task(this.title, {this.done = false});
  Map<String, dynamic> toJson() => {'t': title, 'd': done};
  factory Task.fromJson(Map<String, dynamic> j) =>
      Task(j['t'] as String, done: j['d'] as bool? ?? false);
}

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});
  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final List<Task> _tasks = [];
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('tasks');
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
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        'tasks', jsonEncode(_tasks.map((t) => t.toJson()).toList()));
  }

  void _add() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    setState(() => _tasks.add(Task(t)));
    _ctrl.clear();
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('غلام | لیست کارها')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration:
                        const InputDecoration(hintText: 'کار جدید...'),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _add, child: const Text('+')),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (c, i) {
                final t = _tasks[i];
                return Dismissible(
                  key: ValueKey('${t.title}-$i'),
                  background: Container(color: Colors.red),
                  onDismissed: (_) {
                    setState(() => _tasks.removeAt(i));
                    _save();
                  },
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
                    onTap: () {
                      setState(() => t.done = !t.done);
                      _save();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
