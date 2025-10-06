// lib/main.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final model = AssignmentModel();
  await model.load();
  runApp(ChangeNotifierProvider(
    create: (_) => model,
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Assignment Tracker',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      home: const HomeScreen(),
    );
  }
}

/* -------------------------
   Models & Storage (JSON)
   ------------------------- */

class Assignment {
  String id;
  String title;
  String? dueDateIso;
  bool completed;
  Assignment({
    required this.id,
    required this.title,
    this.dueDateIso,
    this.completed = false,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dueDateIso': dueDateIso,
        'completed': completed,
      };
  factory Assignment.fromJson(Map<String, dynamic> j) => Assignment(
      id: j['id'],
      title: j['title'],
      dueDateIso: j['dueDateIso'],
      completed: j['completed'] ?? false);
}

class Student {
  String id;
  String name;
  String? className;
  List<Assignment> assignments;
  Student({
    required this.id,
    required this.name,
    this.className,
    List<Assignment>? assignments,
  }) : assignments = assignments ?? [];
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'className': className,
        'assignments': assignments.map((a) => a.toJson()).toList(),
      };
  factory Student.fromJson(Map<String, dynamic> j) => Student(
        id: j['id'],
        name: j['name'],
        className: j['className'],
        assignments: (j['assignments'] as List<dynamic>? ?? [])
            .map((e) => Assignment.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class AssignmentModel extends ChangeNotifier {
  static const _storageKey = 'assignment_data_v1';
  List<Student> students = [];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        students = list
            .map((e) => Student.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (e) {
        students = [];
      }
    } else {
      students = [];
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    final raw = jsonEncode(students.map((s) => s.toJson()).toList());
    await p.setString(_storageKey, raw);
  }

  void addStudent(String name, {String? className}) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    students.insert(0, Student(id: id, name: name, className: className));
    _save();
    notifyListeners();
  }

  void deleteStudent(String id) {
    students.removeWhere((s) => s.id == id);
    _save();
    notifyListeners();
  }

  void addAssignment(String studentId, String title, DateTime? dueDate) {
    final s = students.firstWhere((st) => st.id == studentId);
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    s.assignments.insert(
        0,
        Assignment(
          id: id,
          title: title,
          dueDateIso: dueDate?.toIso8601String(),
        ));
    _save();
    notifyListeners();
  }

  void toggleAssignment(String studentId, String assignmentId) {
    final s = students.firstWhere((st) => st.id == studentId);
    final a = s.assignments.firstWhere((as) => as.id == assignmentId);
    a.completed = !a.completed;
    _save();
    notifyListeners();
  }

  void deleteAssignment(String studentId, String assignmentId) {
    final s = students.firstWhere((st) => st.id == studentId);
    s.assignments.removeWhere((a) => a.id == assignmentId);
    _save();
    notifyListeners();
  }

  double completionPercent(Student s) {
    if (s.assignments.isEmpty) return 0.0;
    final done = s.assignments.where((a) => a.completed).length;
    return done / s.assignments.length;
  }

  void clearAll() {
    students = [];
    _save();
    notifyListeners();
  }
}

/* -------------------------
   Screens & UI
   ------------------------- */

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showAddStudentDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final classCtrl = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Add Student'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Student name')),
                TextField(controller: classCtrl, decoration: const InputDecoration(labelText: 'Class (optional)')),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final cls = classCtrl.text.trim();
                    if (name.isNotEmpty) {
                      Provider.of<AssignmentModel>(context, listen: false).addStudent(name, className: cls.isEmpty ? null : cls);
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Add'))
            ],
          );
        });
  }

  void _showAddDummyData(BuildContext context) {
    final model = Provider.of<AssignmentModel>(context, listen: false);
    model.addStudent('Aisha Khan', className: '8A');
    model.addAssignment(model.students.first.id, 'Math HW 1', DateTime.now().add(const Duration(days: 3)));
    model.addAssignment(model.students.first.id, 'Science Project', DateTime.now().add(const Duration(days: 7)));
    model.addStudent('Rohit Verma', className: '8B');
    model.addAssignment(model.students[1].id, 'English Essay', null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignment Tracker'),
        actions: [
          IconButton(
              tooltip: 'Clear all data',
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                          title: const Text('Clear everything?'),
                          content: const Text('This will remove all students and assignments saved locally.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                            ElevatedButton(
                                onPressed: () {
                                  Provider.of<AssignmentModel>(context, listen: false).clearAll();
                                  Navigator.pop(ctx);
                                },
                                child: const Text('Clear'))
                          ],
                        ));
              },
              icon: const Icon(Icons.delete_forever))
        ],
      ),
      body: Consumer<AssignmentModel>(builder: (context, model, _) {
        if (model.students.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(height: 180, width: 180, child: Lottie.network('https://assets9.lottiefiles.com/packages/lf20_jbrw3hcz.json')),
              const SizedBox(height: 12),
              const Text('No students yet', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                  onPressed: () => _showAddStudentDialog(context),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add first student')),
              const SizedBox(height: 6),
              TextButton(onPressed: () => _showAddDummyData(context), child: const Text('Add sample data'))
            ]),
          );
        }

        return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: model.students.length,
            itemBuilder: (context, i) {
              final s = model.students[i];
              final percent = model.completionPercent(s);
              final pctInt = (percent * 100).round();
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      Colors.blue.withOpacity(0.03 + percent * 0.12)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 3))],
                ),
                child: ListTile(
                  leading: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 52,
                        width: 52,
                        child: CircularProgressIndicator(
                          value: percent,
                          strokeWidth: 5,
                        ),
                      ),
                      Text('${pctInt}%')
                    ],
                  ),
                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${s.assignments.length} assignments • ${s.className ?? '—'}'),
                  trailing: PopupMenuButton(
                    onSelected: (value) {
                      if (value == 'delete') {
                        showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                                  title: const Text('Delete student?'),
                                  content: const Text('This will delete the student and all assignments.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                    ElevatedButton(
                                        onPressed: () {
                                          Provider.of<AssignmentModel>(context, listen: false).deleteStudent(s.id);
                                          Navigator.pop(ctx);
                                        },
                                        child: const Text('Delete'))
                                  ],
                                ));
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'delete', child: Text('Delete'))
                    ],
                  ),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => StudentDetailScreen(studentId: s.id)));
                  },
                ),
              );
            });
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
              context: context,
              builder: (ctx) {
                return SafeArea(
                  child: Wrap(children: [
                    ListTile(
                      leading: const Icon(Icons.person_add),
                      title: const Text('Add Student'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showAddStudentDialog(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.playlist_add),
                      title: const Text('Add sample data'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showAddDummyData(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.close),
                      title: const Text('Close'),
                      onTap: () => Navigator.pop(ctx),
                    )
                  ]),
                );
              });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class StudentDetailScreen extends StatelessWidget {
  final String studentId;
  const StudentDetailScreen({super.key, required this.studentId});

  void _showAddAssignmentDialog(BuildContext context, Student s) {
    final titleCtrl = TextEditingController();
    DateTime? chosen;
    showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(builder: (ctx2, setState) {
            return AlertDialog(
              title: const Text('Add Assignment'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 8),
                Row(children: [
                  ElevatedButton(
                      onPressed: () async {
                        final dt = await showDatePicker(
                            context: ctx2,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100));
                        if (dt != null) setState(() => chosen = dt);
                      },
                      child: const Text('Pick due date')),
                  const SizedBox(width: 12),
                  Text(chosen == null ? 'No date' : DateFormat.yMMMd().format(chosen!)),
                ])
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () {
                      final title = titleCtrl.text.trim();
                      if (title.isNotEmpty) {
                        Provider.of<AssignmentModel>(context, listen: false)
                            .addAssignment(s.id, title, chosen);
                        Navigator.pop(ctx2);
                      }
                    },
                    child: const Text('Add'))
              ],
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AssignmentModel>(builder: (context, model, _) {
      final s = model.students.firstWhere((st) => st.id == studentId, orElse: () => Student(id: '0', name: 'Unknown'));
      final percent = model.completionPercent(s);
      return Scaffold(
        appBar: AppBar(
          title: Text(s.name),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Center(child: Text('${(percent * 100).round()}% completed')),
            )
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(s.className ?? 'No class', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: percent, minHeight: 8),
                  ]),
                ),
                const SizedBox(width: 12),
                SizedBox(width: 80, height: 80, child: Lottie.network('https://assets6.lottiefiles.com/packages/lf20_puciaact.json')),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: s.assignments.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('No assignments', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                            onPressed: () => _showAddAssignmentDialog(context, s),
                            icon: const Icon(Icons.playlist_add),
                            label: const Text('Add assignment'))
                      ]),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: s.assignments.length,
                      itemBuilder: (ctx, i) {
                        final a = s.assignments[i];
                        final dueStr = a.dueDateIso == null ? 'No due date' : DateFormat.yMMMd().format(DateTime.parse(a.dueDateIso!));
                        return Dismissible(
                          key: Key(a.id),
                          background: Container(color: Colors.red, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20), child: const Icon(Icons.delete, color: Colors.white)),
                          secondaryBackground: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                          onDismissed: (_) {
                            Provider.of<AssignmentModel>(context, listen: false).deleteAssignment(s.id, a.id);
                          },
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: CheckboxListTile(
                              value: a.completed,
                              onChanged: (_) => Provider.of<AssignmentModel>(context, listen: false).toggleAssignment(s.id, a.id),
                              title: Text(a.title, style: TextStyle(decoration: a.completed ? TextDecoration.lineThrough : TextDecoration.none)),
                              subtitle: Text(dueStr),
                              secondary: a.completed ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.circle_outlined),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ),
                        );
                      }),
            )
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddAssignmentDialog(context, s),
          child: const Icon(Icons.add_task),
        ),
      );
    });
  }
}
