import 'package:flutter/material.dart';
import 'tasks.dart';
import 'main_screen.dart';
import '../services/storage_service.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

class DayModel {
  final String id;
  final DateTime date;
  final String? note;
  final List<TaskModel> tasks;

  DayModel({required this.date, this.note, List<TaskModel>? tasks})
      : id = '${date.year}-${date.month}-${date.day}',
        tasks = tasks ?? [];

  String get dayName {
    const arabic = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return arabic[date.weekday - 1];
  }

  String get monthName {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    return months[date.month - 1];
  }

  String get fullDate => '$dayName ${date.day} $monthName ${date.year}';
}

// ─── Filters ─────────────────────────────────────────────────────────────────

enum DayFilter {
  all,
  lastWeek,
  lastMonth,
  thisYear,
  lastYear,
}

extension DayFilterLabel on DayFilter {
  String get label {
    switch (this) {
      case DayFilter.all:
        return 'الكل';
      case DayFilter.lastWeek:
        return 'آخر أسبوع';
      case DayFilter.lastMonth:
        return 'آخر شهر';
      case DayFilter.thisYear:
        return 'هذه السنة';
      case DayFilter.lastYear:
        return 'السنة الماضية';
    }
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class DaysPage extends StatefulWidget {
  const DaysPage({super.key});

  @override
  State<DaysPage> createState() => _DaysPageState();
}

class _DaysPageState extends State<DaysPage> with TickerProviderStateMixin {
  List<DayModel> _days = [];
  bool _isLoading = true;

  DayFilter _selectedFilter = DayFilter.all;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final days = await StorageService.loadDays();
    if (mounted) {
      setState(() {
        _days = days;
        _isLoading = false;
      });
    }
  }

  Future<void> _save() => StorageService.saveDays(_days);

  List<DayModel> get _filtered {
    final now = DateTime.now();
    return _days.where((d) {
      switch (_selectedFilter) {
        case DayFilter.all:
          return true;
        case DayFilter.lastWeek:
          return d.date.isAfter(now.subtract(const Duration(days: 7)));
        case DayFilter.lastMonth:
          return d.date.isAfter(now.subtract(const Duration(days: 30)));
        case DayFilter.thisYear:
          return d.date.year == now.year;
        case DayFilter.lastYear:
          return d.date.year == now.year - 1;
      }
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _addDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'اختر اليوم المراد إضافته',
      cancelText: 'إلغاء',
      confirmText: 'إضافة',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1ED760),
              onPrimary: Color(0xFF071911),
              surface: Color(0xFF0E3827),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF0A2419),
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        );
      },
    );

    if (picked == null) return;

    final exists = _days.any(
      (d) =>
          d.date.year == picked.year &&
          d.date.month == picked.month &&
          d.date.day == picked.day,
    );

    if (exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('هذا اليوم مضاف بالفعل في القائمة!'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.orange.shade700,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _days.insert(0, DayModel(date: picked));
    });
    await _save();
  }

  Future<void> _openTasks(DayModel day) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, _) => TasksPage(
          tasks: day.tasks,
          onChanged: () => _save(),
        ),
        transitionsBuilder: (context, animation, _, child) {
          final curved =
              CurvedAnimation(parent: animation, curve: Curves.easeInOut);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                      .animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    // حفظ وتحديث بعد الرجوع من صفحة المهام
    await _save();
    if (mounted) setState(() {});
  }

  void _deleteDay(int index) {
    setState(() {
      _days.remove(_filtered[index]);
    });
    _save();
  }

  // ── palette ─────────────────────────────────────────────────────────────────
  static const List<List<Color>> _cardGradients = [
    [Color(0xFF0F9B58), Color(0xFF1ED760)],
    [Color(0xFF1A6B4A), Color(0xFF26C05E)],
    [Color(0xFF0D7A47), Color(0xFF24D66B)],
    [Color(0xFF145C3A), Color(0xFF1FBF58)],
    [Color(0xFF0E8A52), Color(0xFF22D462)],
  ];

  LinearGradient _gradientFor(int index) {
    final g = _cardGradients[index % _cardGradients.length];
    return LinearGradient(
        colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F6F8),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0F9B58)),
        ),
      );
    }

    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 74),
        child: _AnimatedFAB(onTap: _addDay),
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F9B58),
        automaticallyImplyLeading: false,
        title: const Text(
          'Engazz',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F9B58), Color(0xFF1ED760)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'أيامي',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_days.length} يوم مسجّل',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => MainScreen.switchTab(context, 3),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.22),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                          icon: const Text('📊',
                              style: TextStyle(fontSize: 15)),
                          label: const Text(
                            'التحليلات',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => MainScreen.switchTab(context, 2),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.22),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                          icon: const Text('🧠',
                              style: TextStyle(fontSize: 15)),
                          label: const Text(
                            'التخطيط',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Filter chips ────────────────────────────────────────────────────
          const SizedBox(height: 16),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: DayFilter.values.map((f) {
                final selected = _selectedFilter == f;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF0F9B58)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF0F9B58),
                        width: 1.5,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF0F9B58).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : [],
                    ),
                    child: Text(
                      f.label,
                      style: TextStyle(
                        color: selected ? Colors.white : const Color(0xFF0F9B58),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // ── Cards list ──────────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'لا توجد أيام في هذه الفترة',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'اضغط + لإضافة يوم جديد',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final day = filtered[index];
                      return _DayCard(
                        day: day,
                        gradient: _gradientFor(index),
                        onTap: () => _openTasks(day),
                        onDelete: () => _deleteDay(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Day Card ─────────────────────────────────────────────────────────────────

class _DayCard extends StatefulWidget {
  const _DayCard({
    required this.day,
    required this.gradient,
    required this.onTap,
    required this.onDelete,
  });

  final DayModel day;
  final LinearGradient gradient;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = widget.day.date.year == now.year &&
        widget.day.date.month == now.month &&
        widget.day.date.day == now.day;

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
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.colors.first.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Day number bubble ──────────────────────────────────────
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.day.date.day.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                      Text(
                        widget.day.monthName.substring(0, 3),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // ── Date info ──────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.day.dayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isToday) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'اليوم',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.day.date.day} ${widget.day.monthName} ${widget.day.date.year}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                      if (widget.day.note != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.day.note!,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Actions ────────────────────────────────────────────────
                Column(
                  children: [
                    GestureDetector(
                      onTap: widget.onDelete,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white70, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white, size: 28),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Animated FAB ─────────────────────────────────────────────────────────────

class _AnimatedFAB extends StatefulWidget {
  const _AnimatedFAB({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_AnimatedFAB> createState() => _AnimatedFABState();
}

class _AnimatedFABState extends State<_AnimatedFAB>
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
          width: 60,
          height: 60,
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
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}
