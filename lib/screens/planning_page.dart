import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/storage_service.dart';
import '../services/firebase_auth_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════════════════════

enum GoalStatus { pending, inProgress, achieved }

class GoalModel {
  String id;
  String title;
  String description;
  DateTime targetDate;
  GoalStatus status;

  GoalModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.targetDate,
    this.status = GoalStatus.pending,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'targetDate': targetDate.toIso8601String(),
        'status': status.index,
      };

  factory GoalModel.fromJson(Map<String, dynamic> m) => GoalModel(
        id: m['id'],
        title: m['title'],
        description: m['description'] ?? '',
        targetDate: DateTime.parse(m['targetDate']),
        status: GoalStatus.values[m['status'] ?? 0],
      );
}

class NoteModel {
  String id;
  String title;
  String content;
  DateTime createdAt;
  int colorIndex;

  NoteModel({
    required this.id,
    this.title = '',
    this.content = '',
    required this.createdAt,
    this.colorIndex = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'colorIndex': colorIndex,
      };

  factory NoteModel.fromJson(Map<String, dynamic> m) => NoteModel(
        id: m['id'],
        title: m['title'] ?? '',
        content: m['content'] ?? '',
        createdAt: DateTime.parse(m['createdAt']),
        colorIndex: m['colorIndex'] ?? 0,
      );
}

class HabitModel {
  String id;
  String name;
  String emoji;
  Map<String, bool> completions;

  HabitModel({
    required this.id,
    required this.name,
    this.emoji = '⭐',
    Map<String, bool>? completions,
  }) : completions = completions ?? {};

  int get streak {
    int count = 0;
    DateTime day = DateTime.now();
    while (true) {
      final key = _key(day);
      if (completions[key] == true) {
        count++;
        day = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return count;
  }

  int get totalCompletions =>
      completions.values.where((v) => v == true).length;

  static String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';
  String todayKey() => _key(DateTime.now());
  String keyFor(DateTime d) => _key(d);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'completions': completions,
      };

  factory HabitModel.fromJson(Map<String, dynamic> m) => HabitModel(
        id: m['id'],
        name: m['name'],
        emoji: m['emoji'] ?? '⭐',
        completions: (m['completions'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v as bool)) ??
            {},
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// PERSISTENCE
// ═══════════════════════════════════════════════════════════════════════════

class PlanningStorage {
  static const _goalsKey = 'engazz_goals';
  static const _notesKey = 'engazz_notes';
  static const _habitsKey = 'engazz_habits';

  static Future<void> saveGoals(List<GoalModel> g) async {
    final p = await SharedPreferences.getInstance();
    final key = await StorageService.getUserScopedKey(_goalsKey);
    final data = g.map((e) => e.toJson()).toList();
    await p.setString(key, jsonEncode(data));
    StorageService.syncDocToFirestore('goals', data);
  }

  static Future<List<GoalModel>> loadGoals() async {
    final p = await SharedPreferences.getInstance();
    final key = await StorageService.getUserScopedKey(_goalsKey);
    var raw = p.getString(key);

    if ((raw == null || raw == '[]') && FirebaseAuthService.currentUser != null) {
      final cloudData = await StorageService.fetchDocFromFirestore('goals');
      if (cloudData != null && cloudData is List && cloudData.isNotEmpty) {
        raw = jsonEncode(cloudData);
        await p.setString(key, raw);
      }
    }

    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => GoalModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveNotes(List<NoteModel> n) async {
    final p = await SharedPreferences.getInstance();
    final key = await StorageService.getUserScopedKey(_notesKey);
    final data = n.map((e) => e.toJson()).toList();
    await p.setString(key, jsonEncode(data));
    StorageService.syncDocToFirestore('notes', data);
  }

  static Future<List<NoteModel>> loadNotes() async {
    final p = await SharedPreferences.getInstance();
    final key = await StorageService.getUserScopedKey(_notesKey);
    var raw = p.getString(key);

    if ((raw == null || raw == '[]') && FirebaseAuthService.currentUser != null) {
      final cloudData = await StorageService.fetchDocFromFirestore('notes');
      if (cloudData != null && cloudData is List && cloudData.isNotEmpty) {
        raw = jsonEncode(cloudData);
        await p.setString(key, raw);
      }
    }

    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => NoteModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveHabits(List<HabitModel> h) async {
    final p = await SharedPreferences.getInstance();
    final key = await StorageService.getUserScopedKey(_habitsKey);
    final data = h.map((e) => e.toJson()).toList();
    await p.setString(key, jsonEncode(data));
    StorageService.syncDocToFirestore('habits', data);
  }

  static Future<List<HabitModel>> loadHabits() async {
    final p = await SharedPreferences.getInstance();
    final key = await StorageService.getUserScopedKey(_habitsKey);
    var raw = p.getString(key);

    if ((raw == null || raw == '[]') && FirebaseAuthService.currentUser != null) {
      final cloudData = await StorageService.fetchDocFromFirestore('habits');
      if (cloudData != null && cloudData is List && cloudData.isNotEmpty) {
        raw = jsonEncode(cloudData);
        await p.setString(key, raw);
      }
    }

    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => HabitModel.fromJson(e))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PLANNING PAGE (GREEN THEME)
// ═══════════════════════════════════════════════════════════════════════════

class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key});

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage>
    with TickerProviderStateMixin {
  late final TabController _tab;

  List<GoalModel> _goals = [];
  List<NoteModel> _notes = [];
  List<HabitModel> _habits = [];
  bool _loading = true;

  // Rich green note colors
  static const List<Color> _noteColors = [
    Color(0xFF0E3827), // زمردي ملكي
    Color(0xFF134531), // أخضر غابي
    Color(0xFF0C2B1F), // صنوبري داكن
    Color(0xFF184937), // يشب كلاسيكي
    Color(0xFF103F2D), // زيتي عميق
    Color(0xFF08261A), // داكن ملكي
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final goals = await PlanningStorage.loadGoals();
    final notes = await PlanningStorage.loadNotes();
    final habits = await PlanningStorage.loadHabits();
    setState(() {
      _goals = goals;
      _notes = notes;
      _habits = habits;
      _loading = false;
    });
  }

  // ── Goals ─────────────────────────────────────────────────────────────────

  void _addGoal(String title, String desc, DateTime date) {
    setState(() {
      _goals.add(GoalModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: desc,
        targetDate: date,
      ));
      _goals.sort((a, b) => a.targetDate.compareTo(b.targetDate));
    });
    PlanningStorage.saveGoals(_goals);
  }

  void _cycleGoalStatus(GoalModel g) {
    setState(() {
      g.status = GoalStatus.values[(g.status.index + 1) % 3];
    });
    PlanningStorage.saveGoals(_goals);
  }

  void _deleteGoal(GoalModel g) {
    setState(() => _goals.remove(g));
    PlanningStorage.saveGoals(_goals);
  }

  // ── Notes ─────────────────────────────────────────────────────────────────

  void _addNote() {
    final note = NoteModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      colorIndex: _notes.length % _noteColors.length,
    );
    setState(() => _notes.insert(0, note));
    PlanningStorage.saveNotes(_notes);
    _openNote(note);
  }

  void _openNote(NoteModel note) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _NoteEditor(note: note)),
    );
    setState(() {});
    PlanningStorage.saveNotes(_notes);
  }

  void _deleteNote(NoteModel n) {
    setState(() => _notes.remove(n));
    PlanningStorage.saveNotes(_notes);
  }

  // ── Habits ────────────────────────────────────────────────────────────────

  void _addHabit(String name, String emoji) {
    setState(() {
      _habits.add(HabitModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        emoji: emoji,
      ));
    });
    PlanningStorage.saveHabits(_habits);
  }

  void _toggleHabit(HabitModel h, String key) {
    setState(() {
      h.completions[key] = !(h.completions[key] ?? false);
    });
    PlanningStorage.saveHabits(_habits);
  }

  void _deleteHabit(HabitModel h) {
    setState(() => _habits.remove(h));
    PlanningStorage.saveHabits(_habits);
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showAddGoalDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setModal) {
        return Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 24, left: 24, right: 24),
          decoration: const BoxDecoration(
            color: Color(0xFF0E2C20),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('🎯 هدف جديد',
                  style: TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _sheetField(titleCtrl, 'عنوان الهدف', Icons.flag_rounded),
              const SizedBox(height: 12),
              _sheetField(descCtrl, 'وصف (اختياري)', Icons.notes_rounded,
                  maxLines: 3),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    builder: (c, child) => Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Color(0xFF10B981),
                          surface: Color(0xFF0E2C20),
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setModal(() => selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          color: Color(0xFF34D399), size: 20),
                      const SizedBox(width: 12),
                      Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F9B58),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty) return;
                    _addGoal(titleCtrl.text.trim(),
                        descCtrl.text.trim(), selectedDate);
                    Navigator.pop(context);
                  },
                  child: const Text('إضافة الهدف',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _showAddHabitDialog() {
    final nameCtrl = TextEditingController();
    String selectedEmoji = '⭐';
    const emojis = ['⭐', '📚', '💪', '🏃', '💧', '🧘', '✍️', '🎯', '🌙', '🍎'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setModal) {
        return Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 24, left: 24, right: 24),
          decoration: const BoxDecoration(
            color: Color(0xFF0E2C20),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('✅ عادة جديدة',
                  style: TextStyle(color: Colors.white,
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _sheetField(nameCtrl, 'اسم العادة', Icons.check_circle_outline),
              const SizedBox(height: 16),
              const Text('اختر إيموجي:',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: emojis.map((e) {
                  final sel = selectedEmoji == e;
                  return GestureDetector(
                    onTap: () => setModal(() => selectedEmoji = e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFF10B981) : Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                          child: Text(e, style: const TextStyle(fontSize: 22))),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F9B58),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    _addHabit(nameCtrl.text.trim(), selectedEmoji);
                    Navigator.pop(context);
                  },
                  child: const Text('إضافة',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String hint, IconData icon,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: const Color(0xFF34D399), size: 20),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF071911),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1ED760))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF071911),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0A2419),
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F9B58), Color(0xFF082218)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1ED760).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('🧠',
                                  style: TextStyle(fontSize: 22)),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('التخطيط',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold)),
                                Text(
                                  '${_goals.length} هدف · ${_notes.length} ملاحظة · ${_habits.length} عادة',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tab,
              indicatorColor: const Color(0xFF1ED760),
              indicatorWeight: 3,
              labelColor: const Color(0xFF1ED760),
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: '🎯 أهداف'),
                Tab(text: '📝 ملاحظات'),
                Tab(text: '✅ عادات'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _TimelineTab(
              goals: _goals,
              onCycle: _cycleGoalStatus,
              onDelete: _deleteGoal,
              onAdd: _showAddGoalDialog,
            ),
            _NotesTab(
              notes: _notes,
              colors: _noteColors,
              onAdd: _addNote,
              onOpen: _openNote,
              onDelete: _deleteNote,
            ),
            _HabitsTab(
              habits: _habits,
              onToggle: _toggleHabit,
              onDelete: _deleteHabit,
              onAdd: _showAddHabitDialog,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TIMELINE TAB
// ═══════════════════════════════════════════════════════════════════════════

class _TimelineTab extends StatelessWidget {
  const _TimelineTab({
    required this.goals,
    required this.onCycle,
    required this.onDelete,
    required this.onAdd,
  });

  final List<GoalModel> goals;
  final void Function(GoalModel) onCycle;
  final void Function(GoalModel) onDelete;
  final VoidCallback onAdd;

  static const _statusColors = [
    Color(0xFF34D399), // pending - mint
    Color(0xFFF59E0B), // inProgress - amber
    Color(0xFF1ED760), // achieved - vibrant green
  ];

  static const _statusLabels = ['قيد الانتظار', 'جارٍ', 'محقق ✓'];
  static const _statusIcons = [
    Icons.radio_button_unchecked,
    Icons.timelapse_rounded,
    Icons.check_circle_rounded,
  ];

  String _formatDate(DateTime d) {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    final now = DateTime.now();
    final diff = d.difference(now).inDays;
    String relative;
    if (diff < 0) {
      relative = 'منذ ${-diff} يوم';
    } else if (diff == 0) {
      relative = 'اليوم';
    } else if (diff == 1) {
      relative = 'غداً';
    } else {
      relative = 'بعد $diff يوم';
    }
    return '${d.day} ${months[d.month - 1]} ${d.year} · $relative';
  }

  @override
  Widget build(BuildContext context) {
    return goals.isEmpty
        ? _emptyState(
            '🎯', 'لا أهداف بعد', 'أضف هدفاً وحدد تاريخ تحقيقه', onAdd)
        : Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: goals.length,
                itemBuilder: (_, i) {
                  final g = goals[i];
                  final color = _statusColors[g.status.index];
                  final isLast = i == goals.length - 1;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Timeline line & dot ────────────────────────
                      SizedBox(
                        width: 32,
                        child: Column(
                          children: [
                            const SizedBox(height: 18),
                            Container(
                              width: 16, height: 16,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  )
                                ],
                              ),
                            ),
                            if (!isLast)
                              Container(
                                width: 2,
                                height: 72, // fixed connector line height
                                color: Colors.white12,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // ── Card ───────────────────────────────────────
                      Expanded(
                        child: GestureDetector(
                          onTap: () => onCycle(g),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E2C20),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: color.withValues(alpha: 0.3),
                                  width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(g.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: g.status ==
                                                    GoalStatus.achieved
                                                ? Colors.white38
                                                : Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            decoration: g.status ==
                                                    GoalStatus.achieved
                                                ? TextDecoration.lineThrough
                                                : null,
                                          )),
                                    ),
                                    GestureDetector(
                                      onTap: () => onDelete(g),
                                      child: const Icon(Icons.close_rounded,
                                          color: Colors.white24, size: 18),
                                    ),
                                  ],
                                ),
                                if (g.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(g.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12)),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Icon(_statusIcons[g.status.index],
                                        color: color, size: 14),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                          _statusLabels[g.status.index],
                                          style: TextStyle(
                                              color: color, fontSize: 11)),
                                    ),
                                    const Spacer(),
                                    const Icon(Icons.calendar_today_rounded,
                                        color: Colors.white24, size: 12),
                                    const SizedBox(width: 4),
                                    Text(_formatDate(g.targetDate),
                                        style: const TextStyle(
                                            color: Colors.white24,
                                            fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              // FAB
              Positioned(
                bottom: 84, right: 16,
                child: _GreenFAB(onTap: onAdd, icon: Icons.add),
              ),
            ],
          );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NOTES TAB
// ═══════════════════════════════════════════════════════════════════════════

class _NotesTab extends StatelessWidget {
  const _NotesTab({
    required this.notes,
    required this.colors,
    required this.onAdd,
    required this.onOpen,
    required this.onDelete,
  });

  final List<NoteModel> notes;
  final List<Color> colors;
  final VoidCallback onAdd;
  final void Function(NoteModel) onOpen;
  final void Function(NoteModel) onDelete;

  @override
  Widget build(BuildContext context) {
    return notes.isEmpty
        ? _emptyState('📝', 'لا ملاحظات بعد',
            'أضف ملاحظة كخطة يومك أو أي فكرة', onAdd)
        : Stack(
            children: [
              GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: notes.length,
                itemBuilder: (_, i) {
                  final n = notes[i];
                  final color = colors[n.colorIndex % colors.length];
                  return GestureDetector(
                    onTap: () => onOpen(n),
                    onLongPress: () => onDelete(n),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (n.title.isNotEmpty) ...[
                            Text(n.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(height: 1, color: Colors.white12),
                            const SizedBox(height: 8),
                          ],
                          Expanded(
                            child: Text(
                              n.content.isEmpty
                                  ? 'اضغط للتعديل...'
                                  : n.content,
                              maxLines: 8,
                              overflow: TextOverflow.fade,
                              style: TextStyle(
                                color: n.content.isEmpty
                                    ? Colors.white24
                                    : Colors.white70,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${n.createdAt.day}/${n.createdAt.month}/${n.createdAt.year}',
                            style: const TextStyle(
                                color: Colors.white24, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 84, right: 16,
                child: _GreenFAB(onTap: onAdd, icon: Icons.add),
              ),
            ],
          );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HABITS TAB
// ═══════════════════════════════════════════════════════════════════════════

class _HabitsTab extends StatefulWidget {
  const _HabitsTab({
    required this.habits,
    required this.onToggle,
    required this.onDelete,
    required this.onAdd,
  });

  final List<HabitModel> habits;
  final void Function(HabitModel, String) onToggle;
  final void Function(HabitModel) onDelete;
  final VoidCallback onAdd;

  @override
  State<_HabitsTab> createState() => _HabitsTabState();
}

class _HabitsTabState extends State<_HabitsTab> {
  int _weekOffset = 0;

  List<DateTime> _getDays() {
    final now = DateTime.now().add(Duration(days: _weekOffset * 7));
    return List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
  }

  void _showHabitStats(HabitModel h) {
    final todayKey = h.todayKey();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final doneNow = h.completions[todayKey] ?? false;
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF0E2C20),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(h.emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'إجمالي الإنجاز: ${h.totalCompletions} مرة',
                              style: const TextStyle(
                                  color: Color(0xFF1ED760), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white54),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            children: [
                              const Text('🏆 إجمالي المرات',
                                  style: TextStyle(
                                      color: Colors.white60, fontSize: 12)),
                              const SizedBox(height: 6),
                              Text(
                                '${h.totalCompletions}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            children: [
                              const Text('🔥 سلسلة مستمرة',
                                  style: TextStyle(
                                      color: Colors.white60, fontSize: 12)),
                              const SizedBox(height: 6),
                              Text(
                                '${h.streak} يوم',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: doneNow
                            ? const Color(0xFF10B981)
                            : const Color(0xFF0F9B58),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: Icon(
                          doneNow
                              ? Icons.check_circle_rounded
                              : Icons.add_task_rounded,
                          color: Colors.white),
                      label: Text(
                        doneNow
                            ? 'تم تسجيل عادة اليوم بنجاح ✓'
                            : 'تسجيل إنجاز اليوم',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      onPressed: () {
                        widget.onToggle(h, todayKey);
                        setModalState(() {});
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDays();
    final dayNames = ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];

    return widget.habits.isEmpty
        ? _emptyState(
            '✅', 'لا عادات بعد', 'أضف عادة وتابع تقدمك يومياً', widget.onAdd)
        : Stack(
            children: [
              Column(
                children: [
                  // Week Selector Header
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E2C20),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios_rounded,
                              color: Colors.white70, size: 16),
                          tooltip: 'الأسبوع السابق',
                          onPressed: () => setState(() => _weekOffset--),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _weekOffset == 0
                                  ? Icons.calendar_today_rounded
                                  : Icons.history_rounded,
                              color: const Color(0xFF1ED760),
                              size: 15,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _weekOffset == 0
                                  ? 'الأسبوع الحالي (آخر 7 أيام)'
                                  : _weekOffset == -1
                                      ? 'الأسبوع الماضي'
                                      : 'قبل ${-_weekOffset} أسابيع',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        if (_weekOffset < 0)
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white70, size: 16),
                            tooltip: 'الأسبوع التالي',
                            onPressed: () => setState(() => _weekOffset++),
                          )
                        else
                          const SizedBox(width: 40),
                      ],
                    ),
                  ),

                  // Days Header row
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E2C20).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 3,
                          child: Text(
                            'العادة والإنجازات',
                            style:
                                TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ),
                        ...days.map((d) {
                          final isToday = d.day == DateTime.now().day &&
                              d.month == DateTime.now().month &&
                              d.year == DateTime.now().year;
                          return Expanded(
                            child: Center(
                              child: Text(
                                dayNames[d.weekday % 7],
                                style: TextStyle(
                                  color: isToday
                                      ? const Color(0xFF1ED760)
                                      : Colors.white38,
                                  fontSize: 12,
                                  fontWeight: isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(width: 36),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: widget.habits.length,
                      itemBuilder: (_, i) {
                        final h = widget.habits[i];
                        return Dismissible(
                          key: Key(h.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade900,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_rounded,
                                color: Colors.white),
                          ),
                          onDismissed: (_) => widget.onDelete(h),
                          child: GestureDetector(
                            onTap: () => _showHabitStats(h),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E2C20),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.white10, width: 1),
                              ),
                              child: Row(
                                children: [
                                  // Name & total completions badge
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      children: [
                                        Text(h.emoji,
                                            style:
                                                const TextStyle(fontSize: 20)),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                h.name,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          const Color(0xFF1ED760)
                                                              .withValues(
                                                                  alpha: 0.15),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      '🏆 ${h.totalCompletions} مرة',
                                                      style: const TextStyle(
                                                        color:
                                                            Color(0xFF1ED760),
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  if (h.streak > 0) ...[
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '🔥${h.streak}',
                                                      style: const TextStyle(
                                                        color: Colors.orange,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Day checkboxes
                                  ...days.map((d) {
                                    final key = h.keyFor(d);
                                    final done = h.completions[key] ?? false;
                                    final isToday =
                                        d.day == DateTime.now().day &&
                                            d.month == DateTime.now().month &&
                                            d.year == DateTime.now().year;
                                    return Expanded(
                                      child: Center(
                                        child: GestureDetector(
                                          onTap: () {
                                            widget.onToggle(h, key);
                                            setState(() {});
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 200),
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color: done
                                                  ? const Color(0xFF10B981)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: done
                                                    ? const Color(0xFF10B981)
                                                    : isToday
                                                        ? const Color(
                                                            0xFF1ED760)
                                                        : Colors.white12,
                                                width: isToday ? 2 : 1,
                                              ),
                                            ),
                                            child: done
                                                ? const Icon(
                                                    Icons.check_rounded,
                                                    color: Colors.white,
                                                    size: 16)
                                                : null,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                  const SizedBox(width: 36),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 84,
                right: 16,
                child: _GreenFAB(onTap: widget.onAdd, icon: Icons.add),
              ),
            ],
          );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NOTE EDITOR
// ═══════════════════════════════════════════════════════════════════════════

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({required this.note});
  final NoteModel note;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final TextEditingController _title;
  late final TextEditingController _content;

  static const List<Color> _palette = [
    Color(0xFF0E3827), // زمردي ملكي
    Color(0xFF134531), // أخضر غابي
    Color(0xFF0C2B1F), // صنوبري داكن
    Color(0xFF184937), // يشب كلاسيكي
    Color(0xFF103F2D), // زيتي عميق
    Color(0xFF08261A), // داكن ملكي
  ];

  static const List<String> _paletteNames = [
    'زمردي', 'غابي', 'صنوبري', 'يشب', 'زيتي', 'داكن'
  ];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note.title);
    _content = TextEditingController(text: widget.note.content);
  }

  @override
  void dispose() {
    widget.note.title = _title.text;
    widget.note.content = _content.text;
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = _palette[widget.note.colorIndex % _palette.length];
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            widget.note.title = _title.text;
            widget.note.content = _content.text;
            Navigator.pop(context);
          },
        ),
        actions: [
          // Color picker
          PopupMenuButton<int>(
            color: const Color(0xFF0E2C20),
            icon: const Icon(Icons.palette_outlined, color: Colors.white70),
            onSelected: (i) => setState(() => widget.note.colorIndex = i),
            itemBuilder: (_) => List.generate(_palette.length, (i) {
              return PopupMenuItem(
                value: i,
                child: Row(
                  children: [
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: _palette[i],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_paletteNames[i],
                        style: const TextStyle(color: Colors.white)),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            TextField(
              controller: _title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'العنوان...',
                hintStyle: TextStyle(color: Colors.white24, fontSize: 22),
                border: InputBorder.none,
              ),
              onChanged: (v) => widget.note.title = v,
            ),
            const Divider(color: Colors.white12),
            Expanded(
              child: TextField(
                controller: _content,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 15, height: 1.6),
                decoration: const InputDecoration(
                  hintText: 'اكتب ملاحظتك هنا...',
                  hintStyle: TextStyle(color: Colors.white24),
                  border: InputBorder.none,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                onChanged: (v) => widget.note.content = v,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

Widget _emptyState(
    String emoji, String title, String sub, VoidCallback onAdd) {
  return Stack(
    children: [
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(sub,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      ),
      Positioned(
        bottom: 84, right: 16,
        child: _GreenFAB(onTap: onAdd, icon: Icons.add),
      ),
    ],
  );
}

class _GreenFAB extends StatefulWidget {
  const _GreenFAB({required this.onTap, required this.icon});
  final VoidCallback onTap;
  final IconData icon;

  @override
  State<_GreenFAB> createState() => _GreenFABState();
}

class _GreenFABState extends State<_GreenFAB>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.9)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) async {
        await _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F9B58), Color(0xFF1ED760)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F9B58).withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(widget.icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
