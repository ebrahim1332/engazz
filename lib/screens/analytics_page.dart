import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'days_page.dart';
import 'tasks.dart';
import 'planning_page.dart';

// ═══════════════════════════════════════════════════════════════════════════
// FILTER ENUM
// ═══════════════════════════════════════════════════════════════════════════

enum AnalyticsPeriod {
  today,
  thisWeek,
  thisMonth,
  thisYear,
  allTime,
}

extension AnalyticsPeriodLabel on AnalyticsPeriod {
  String get label {
    switch (this) {
      case AnalyticsPeriod.today:
        return 'اليوم';
      case AnalyticsPeriod.thisWeek:
        return 'الأسبوع';
      case AnalyticsPeriod.thisMonth:
        return 'الشهر';
      case AnalyticsPeriod.thisYear:
        return 'السنة';
      case AnalyticsPeriod.allTime:
        return 'الكل';
    }
  }

  String get subtitle {
    switch (this) {
      case AnalyticsPeriod.today:
        return 'إحصائيات ومهام وجلسات اليوم';
      case AnalyticsPeriod.thisWeek:
        return 'مؤشرات الأداء لآخر 7 أيام';
      case AnalyticsPeriod.thisMonth:
        return 'تحليلات الإنجاز لشهر ${DateTime.now().month}';
      case AnalyticsPeriod.thisYear:
        return 'التقرير الشامل لسنة ${DateTime.now().year}';
      case AnalyticsPeriod.allTime:
        return 'إجمالي إحصائياتك منذ بداية الاستخدام';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BAR DATA MODEL
// ═══════════════════════════════════════════════════════════════════════════

class _BarData {
  final String label;
  final String dateLabel;
  final int total;
  final int completed;
  final int minutes;

  _BarData({
    required this.label,
    required this.dateLabel,
    required this.total,
    required this.completed,
    this.minutes = 0,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// ANALYTICS PAGE (ACTIVE & REAL-TIME WITH SESSIONS)
// ═══════════════════════════════════════════════════════════════════════════

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with SingleTickerProviderStateMixin {
  AnalyticsPeriod _period = AnalyticsPeriod.allTime;
  bool _isLoading = true;

  List<DayModel> _allDays = [];
  List<SessionModel> _allSessions = [];
  List<GoalModel> _allGoals = [];
  List<HabitModel> _allHabits = [];

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final days = await StorageService.loadDays();
    final sessions = await StorageService.loadSessionModels();
    final goals = await PlanningStorage.loadGoals();
    final habits = await PlanningStorage.loadHabits();

    if (mounted) {
      setState(() {
        _allDays = days;
        _allSessions = sessions;
        _allGoals = goals;
        _allHabits = habits;
        _isLoading = false;
      });
      _animCtrl.forward(from: 0.0);
    }
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  // ── Date Filtering ────────────────────────────────────────────────────────

  bool _isDateInPeriod(DateTime d) {
    final now = DateTime.now();
    final dayOnly = _startOfDay(d);
    final today = _startOfDay(now);

    switch (_period) {
      case AnalyticsPeriod.today:
        return dayOnly.isAtSameMomentAs(today);

      case AnalyticsPeriod.thisWeek:
        final startOfWeek = today.subtract(const Duration(days: 6));
        return !dayOnly.isBefore(startOfWeek) && !dayOnly.isAfter(today);

      case AnalyticsPeriod.thisMonth:
        return dayOnly.year == now.year && dayOnly.month == now.month;

      case AnalyticsPeriod.thisYear:
        return dayOnly.year == now.year;

      case AnalyticsPeriod.allTime:
        return true;
    }
  }

  List<DayModel> get _filteredDays {
    return _allDays.where((d) => _isDateInPeriod(d.date)).toList();
  }

  List<TaskModel> get _filteredTasks {
    final List<TaskModel> tasks = [];
    for (final d in _filteredDays) {
      tasks.addAll(d.tasks);
    }
    return tasks;
  }

  List<SessionModel> get _filteredSessions {
    return _allSessions.where((s) => _isDateInPeriod(s.timestamp)).toList();
  }

  // ── Metrics Calculation ───────────────────────────────────────────────────

  int get _totalTasks => _filteredTasks.length;

  int get _completedTasks =>
      _filteredTasks.where((t) => t.isCompleted).length;

  double get _completionRate {
    if (_totalTasks == 0) return 0.0;
    return (_completedTasks / _totalTasks) * 100.0;
  }

  int get _completedTaskMinutes {
    return _filteredTasks
        .where((t) => t.isCompleted)
        .fold(0, (sum, t) => sum + (t.hours * 60) + t.minutes);
  }

  int get _focusSeconds {
    return _filteredSessions.fold(0, (sum, s) => sum + s.durationSeconds);
  }

  int get _focusMinutes => _focusSeconds ~/ 60;

  int get _totalProductiveMinutes => _completedTaskMinutes + _focusMinutes;

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes د';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '$h س';
    return '$h س $m د';
  }

  String _formatSeconds(int totalSecs) {
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    if (m < 60) {
      return '$m د $s ث';
    }
    final h = m ~/ 60;
    final remM = m % 60;
    return '$h س $remM د';
  }

  int get _habitCompletionsInPeriod {
    int count = 0;
    for (final h in _allHabits) {
      h.completions.forEach((dateKey, isDone) {
        if (isDone) {
          try {
            final parts = dateKey.split('-');
            if (parts.length == 3) {
              final d = DateTime(int.parse(parts[0]), int.parse(parts[1]),
                  int.parse(parts[2]));
              if (_isDateInPeriod(d)) count++;
            }
          } catch (_) {}
        }
      });
    }
    return count;
  }

  int get _achievedGoalsCount {
    return _allGoals.where((g) => g.status == GoalStatus.achieved).length;
  }

  int get _bestStreak {
    if (_allHabits.isEmpty) return 0;
    return _allHabits.map((h) => h.streak).fold(0, math.max);
  }

  double get _overallScore {
    if (_totalTasks == 0 && _filteredSessions.isEmpty && _allHabits.isEmpty) {
      return 0.0;
    }
    double score = 0;
    if (_totalTasks > 0) {
      score += (_completedTasks / _totalTasks) * 50;
    }
    if (_filteredSessions.isNotEmpty) {
      score += math.min(30.0, _filteredSessions.length * 10.0);
    }
    if (_habitCompletionsInPeriod > 0) score += 10;
    if (_achievedGoalsCount > 0) score += 10;
    return math.min(100.0, math.max(0.0, score));
  }

  String get _scoreTitle {
    final s = _overallScore;
    if (s == 0) return 'لا يوجد نشاط مسجل 💤';
    if (s >= 85) return 'إنجاز أسطوري 🔥';
    if (s >= 70) return 'أداء استثنائي ⚡';
    if (s >= 50) return 'تقدم ممتاز 🎯';
    return 'بداية مشجعة 🌱';
  }

  // ── Toggle Task Completion Live ───────────────────────────────────────────

  void _toggleTask(TaskModel task) {
    setState(() {
      task.isCompleted = !task.isCompleted;
    });
    StorageService.saveDays(_allDays);
  }

  // ── Dynamic Chart Data Generator ──────────────────────────────────────────

  List<_BarData> _generateBarData() {
    final now = DateTime.now();
    final today = _startOfDay(now);
    final List<_BarData> list = [];

    switch (_period) {
      case AnalyticsPeriod.today:
        // Hourly / task breakdown for today
        final todayDays = _allDays
            .where((d) => _startOfDay(d.date).isAtSameMomentAs(today));
        final todayTasks = todayDays.expand((d) => d.tasks).toList();

        // Also add today's sessions as bars
        final todaySessions = _allSessions.where(
            (s) => _startOfDay(s.timestamp).isAtSameMomentAs(today)).toList();

        if (todayTasks.isEmpty && todaySessions.isEmpty) {
          return [];
        }

        // Tasks bars
        for (int i = 0; i < todayTasks.length; i++) {
          final t = todayTasks[i];
          final mins = (t.hours * 60) + t.minutes;
          list.add(_BarData(
            label: 'م${i + 1}',
            dateLabel: t.title,
            total: 1,
            completed: t.isCompleted ? 1 : 0,
            minutes: mins,
          ));
        }

        // Sessions bars
        for (int i = 0; i < todaySessions.length; i++) {
          final s = todaySessions[i];
          final mins = s.durationSeconds ~/ 60;
          list.add(_BarData(
            label: 'ج${i + 1}',
            dateLabel: 'جلسة مؤقت (${_formatSeconds(s.durationSeconds)})',
            total: 1,
            completed: 1,
            minutes: mins,
          ));
        }
        break;

      case AnalyticsPeriod.thisWeek:
        // 7 days of the last week
        const arabicDays = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];
        for (int i = 6; i >= 0; i--) {
          final targetDate = today.subtract(Duration(days: i));

          final matchingDays = _allDays.where((d) =>
              _startOfDay(d.date).isAtSameMomentAs(targetDate));
          final matchingSessions = _allSessions.where((s) =>
              _startOfDay(s.timestamp).isAtSameMomentAs(targetDate));

          int tot = 0;
          int comp = 0;
          int mins = 0;

          // Tasks
          for (final md in matchingDays) {
            tot += md.tasks.length;
            comp += md.tasks.where((t) => t.isCompleted).length;
            mins += md.tasks
                .where((t) => t.isCompleted)
                .fold(0, (s, t) => s + (t.hours * 60) + t.minutes);
          }

          // Focus sessions on that day
          for (final ms in matchingSessions) {
            tot += 1;
            comp += 1;
            mins += ms.durationSeconds ~/ 60;
          }

          final dayLabel = arabicDays[targetDate.weekday % 7];
          list.add(_BarData(
            label: dayLabel,
            dateLabel: '${targetDate.day}/${targetDate.month}',
            total: tot,
            completed: comp,
            minutes: mins,
          ));
        }
        break;

      case AnalyticsPeriod.thisMonth:
        // 4 weeks of the month
        for (int w = 1; w <= 4; w++) {
          final int startDay = (w - 1) * 7 + 1;
          final int endDay = w == 4 ? 31 : w * 7;

          final monthDays = _allDays.where((d) {
            final s = _startOfDay(d.date);
            return s.year == now.year &&
                s.month == now.month &&
                s.day >= startDay &&
                s.day <= endDay;
          });

          final monthSessions = _allSessions.where((s) {
            final st = _startOfDay(s.timestamp);
            return st.year == now.year &&
                st.month == now.month &&
                st.day >= startDay &&
                st.day <= endDay;
          });

          int tot = 0;
          int comp = 0;
          int mins = 0;

          for (final md in monthDays) {
            tot += md.tasks.length;
            comp += md.tasks.where((t) => t.isCompleted).length;
            mins += md.tasks
                .where((t) => t.isCompleted)
                .fold(0, (s, t) => s + (t.hours * 60) + t.minutes);
          }

          for (final ms in monthSessions) {
            tot += 1;
            comp += 1;
            mins += ms.durationSeconds ~/ 60;
          }

          list.add(_BarData(
            label: 'أ$w',
            dateLabel: 'أسبوع $w',
            total: tot,
            completed: comp,
            minutes: mins,
          ));
        }
        break;

      case AnalyticsPeriod.thisYear:
        // 12 months
        const monthNames = [
          'ي', 'ف', 'م', 'أ', 'م', 'ي', 'ي', 'أ', 'س', 'أ', 'ن', 'د'
        ];
        for (int m = 1; m <= 12; m++) {
          final yearDays = _allDays.where((d) {
            final s = _startOfDay(d.date);
            return s.year == now.year && s.month == m;
          });

          final yearSessions = _allSessions.where((s) {
            final st = _startOfDay(s.timestamp);
            return st.year == now.year && st.month == m;
          });

          int tot = 0;
          int comp = 0;
          int mins = 0;

          for (final md in yearDays) {
            tot += md.tasks.length;
            comp += md.tasks.where((t) => t.isCompleted).length;
            mins += md.tasks
                .where((t) => t.isCompleted)
                .fold(0, (s, t) => s + (t.hours * 60) + t.minutes);
          }

          for (final ms in yearSessions) {
            tot += 1;
            comp += 1;
            mins += ms.durationSeconds ~/ 60;
          }

          list.add(_BarData(
            label: monthNames[m - 1],
            dateLabel: 'شهر $m',
            total: tot,
            completed: comp,
            minutes: mins,
          ));
        }
        break;

      case AnalyticsPeriod.allTime:
        // All recorded days
        for (int i = 0; i < math.min(8, _allDays.length); i++) {
          final d = _allDays[i];
          final comp = d.tasks.where((t) => t.isCompleted).length;
          final mins = d.tasks
              .where((t) => t.isCompleted)
              .fold(0, (s, t) => s + (t.hours * 60) + t.minutes);
          list.add(_BarData(
            label: '${d.date.day}',
            dateLabel: '${d.date.day}/${d.date.month}',
            total: d.tasks.length,
            completed: comp,
            minutes: mins,
          ));
        }
        break;
    }

    return list;
  }

  List<double> _generateWavePoints(List<_BarData> bars) {
    if (bars.isEmpty) return [];
    return bars.map((b) => b.minutes.toDouble()).toList();
  }

  // ── Build UI ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bars = _generateBarData();
    final wavePoints = _generateWavePoints(bars);
    final tasks = _filteredTasks;
    final sessions = _filteredSessions;

    return Scaffold(
      backgroundColor: const Color(0xFF071911),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0A2419),
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📊', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'تحليلات الأداء والمهام وجلسات التركيز',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1ED760)),
          tooltip: 'تحديث البيانات',
          onPressed: () {
            setState(() => _isLoading = true);
            _loadData();
          },
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1ED760)),
            )
          : RefreshIndicator(
              color: const Color(0xFF1ED760),
              backgroundColor: const Color(0xFF0E3827),
              onRefresh: _loadData,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Period Filter ──────────────────────────────────────
                    _buildPeriodSelector(),
                    const SizedBox(height: 16),

                    // ── Hero Gauge ─────────────────────────────────────────
                    _buildOverallScoreCard(),
                    const SizedBox(height: 16),

                    // ── KPI Grid ───────────────────────────────────────────
                    _buildKpiGrid(),
                    const SizedBox(height: 20),

                    // ── Dynamic Bar Chart (Tasks + Sessions) ───────────────
                    _buildBarChartSection(bars),
                    const SizedBox(height: 20),

                    // ── Real Focus Wave Chart ──────────────────────────────
                    _buildWaveChartSection(wavePoints),
                    const SizedBox(height: 20),

                    // ── Energy Balance Donut ────────────────────────────────
                    _buildBalanceDonutSection(),
                    const SizedBox(height: 20),

                    // ── Sessions In Period (Real Timer Sessions) ───────────
                    _buildSessionsSection(sessions),
                    const SizedBox(height: 20),

                    // ── Live Tasks In Period ───────────────────────────────
                    _buildTasksSection(tasks),
                    const SizedBox(height: 20),

                    // ── Smart Insights ─────────────────────────────────────
                    _buildInsightsSection(),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // WIDGET BUILDERS
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0E2C20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF1ED760).withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: AnalyticsPeriod.values.map((p) {
          final isSelected = _period == p;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _period = p);
                _loadData();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF0F9B58), Color(0xFF1ED760)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color:
                                const Color(0xFF0F9B58).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    p.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOverallScoreCard() {
    final score = _overallScore;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E3827), Color(0xFF0A261B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF1ED760).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // Circular Score Gauge
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(88, 88),
                  painter: _RadialScorePainter(score: score),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${score.toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'معدل القوة',
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Info Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1ED760).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _period.subtitle,
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _scoreTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _totalTasks > 0 || _filteredSessions.isNotEmpty
                      ? '$_completedTasks مهمة مكتملة · ${_filteredSessions.length} جلسة تركيز (${_formatDuration(_focusMinutes)})'
                      : 'لا يوجد نشاط مسجل في هذا النطاق الزمني',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.35,
      children: [
        _buildKpiCard(
          title: 'جلسات المؤقت الفعلية',
          value: '${_filteredSessions.length}',
          unit: 'جلسة مسجلة',
          icon: Icons.timer_outlined,
          iconColor: const Color(0xFF1ED760),
          badge: _focusMinutes > 0 ? _formatDuration(_focusMinutes) : '0 د',
        ),
        _buildKpiCard(
          title: 'إجمالي وقت الإنجاز',
          value: _formatDuration(_totalProductiveMinutes),
          unit: 'مهام + جلسات',
          icon: Icons.hourglass_bottom_rounded,
          iconColor: const Color(0xFF34D399),
          badge: 'الوقت المستثمر',
        ),
        _buildKpiCard(
          title: 'المهام المكتملة',
          value: '$_completedTasks',
          unit: 'من $_totalTasks',
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFF10B981),
          badge: '${_completionRate.toInt()}% نسبة',
        ),
        _buildKpiCard(
          title: 'تفاعل العادات',
          value: '$_habitCompletionsInPeriod',
          unit: 'مرة أنجزتها',
          icon: Icons.local_fire_department_rounded,
          iconColor: Colors.orangeAccent,
          badge: '🔥 سلسلة $_bestStreak',
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color iconColor,
    required String badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E2C20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    unit,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Productivity Bar Chart ───────────────────────────────────────────────

  Widget _buildBarChartSection(List<_BarData> bars) {
    final hasData = bars.any((b) => b.total > 0 || b.completed > 0 || b.minutes > 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E2C20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart_rounded,
                      color: Color(0xFF1ED760), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'أعمدة إنجاز ${_period.label} (مهام وجلسات)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _legendDot(const Color(0xFF1ED760), 'مكتمل'),
                  const SizedBox(width: 8),
                  _legendDot(Colors.white24, 'المتبقي'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasData)
            Container(
              height: 120,
              alignment: Alignment.center,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_busy_rounded,
                      color: Colors.white24, size: 36),
                  SizedBox(height: 8),
                  Text(
                    'لا توجد مهام أو جلسات مسجلة في هذه الفترة',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 140,
              child: CustomPaint(
                size: const Size(double.infinity, 140),
                painter: _BarChartPainter(bars: bars),
              ),
            ),
        ],
      ),
    );
  }

  // ── Smooth Focus Wave Chart ──────────────────────────────────────────────

  Widget _buildWaveChartSection(List<double> points) {
    final totalMins = points.fold<double>(0, (s, p) => s + p);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E2C20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.show_chart_rounded,
                      color: Color(0xFF34D399), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'منحنى إجمالي دقائق التركيز والإنجاز',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                'المجموع: ${_formatDuration(totalMins.toInt())}',
                style:
                    const TextStyle(color: Color(0xFF34D399), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (totalMins == 0)
            Container(
              height: 110,
              alignment: Alignment.center,
              child: const Text(
                'سجّل جلسات أو أنجز مهاماً ليظهر منحنى تقدمك الفعلي 📈',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            )
          else
            SizedBox(
              height: 120,
              child: CustomPaint(
                size: const Size(double.infinity, 120),
                painter: _WaveChartPainter(points: points),
              ),
            ),
        ],
      ),
    );
  }

  // ── Energy Balance Donut ─────────────────────────────────────────────────

  Widget _buildBalanceDonutSection() {
    final taskScore = _completedTasks.toDouble();
    final sessionScore = _filteredSessions.length.toDouble();
    final habitScore = _habitCompletionsInPeriod.toDouble();
    final hasAny = (taskScore + sessionScore + habitScore) > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E2C20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_outline_rounded,
                  color: Color(0xFF1ED760), size: 18),
              SizedBox(width: 8),
              Text(
                'توزيع طاقة الإنجاز والنشاط',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: CustomPaint(
                  size: const Size(90, 90),
                  painter: _DonutChartPainter(
                    r1: hasAny ? taskScore : 0.0,
                    r2: hasAny ? sessionScore : 0.0,
                    r3: hasAny ? habitScore : 0.0,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _donutLegendRow(
                      color: const Color(0xFF1ED760),
                      title: 'المهام المكتملة',
                      subtitle: '$_completedTasks مهمة في الفترة',
                    ),
                    const SizedBox(height: 8),
                    _donutLegendRow(
                      color: const Color(0xFF34D399),
                      title: 'جلسات المؤقت',
                      subtitle: '${_filteredSessions.length} جلسة (${_formatDuration(_focusMinutes)})',
                    ),
                    const SizedBox(height: 8),
                    _donutLegendRow(
                      color: const Color(0xFFF59E0B),
                      title: 'تفاعل العادات',
                      subtitle: '$_habitCompletionsInPeriod إنجاز عادة',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sessions In Period (Real Timer Sessions List) ─────────────────────────

  Widget _buildSessionsSection(List<SessionModel> sessions) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E2C20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      color: Color(0xFF1ED760), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'جلسات التركيز المسجلة في ${_period.label} (${sessions.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                _formatDuration(_focusMinutes),
                style: const TextStyle(
                    color: Color(0xFF1ED760),
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sessions.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: Text(
                'لا توجد جلسات مؤقت مسجلة في ${_period.label} حتى الآن ⏱️',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sessions.length,
              separatorBuilder: (_, x) =>
                  Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
              itemBuilder: (context, index) {
                final s = sessions[index];
                final durationStr = _formatSeconds(s.durationSeconds);
                final timeStr =
                    '${s.timestamp.hour.toString().padLeft(2, '0')}:${s.timestamp.minute.toString().padLeft(2, '0')}';
                final dateStr = '${s.timestamp.day}/${s.timestamp.month}';

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1ED760).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.alarm_on_rounded,
                            color: Color(0xFF1ED760), size: 14),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'جلسة تركيز #${index + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'التاريخ: $dateStr في $timeStr',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1ED760).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                const Color(0xFF1ED760).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          durationStr,
                          style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Live Tasks Section (Interactive Checklist) ───────────────────────────

  Widget _buildTasksSection(List<TaskModel> tasks) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E2C20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.playlist_add_check_rounded,
                      color: Color(0xFF1ED760), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'قائمة مهام ${_period.label} (${tasks.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                'اضغط لتغيير الحالة',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Text('📝', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 8),
                  Text(
                    'لا توجد مهام مضافة في ${_period.label}',
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F9B58),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: const Text('إضافة مهمة من شاشة الأيام',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tasks.length,
              separatorBuilder: (_, x) =>
                  Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
              itemBuilder: (context, index) {
                final task = tasks[index];
                final durationText = task.timeFormatted;

                return InkWell(
                  onTap: () => _toggleTask(task),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: task.isCompleted
                                ? const Color(0xFF1ED760)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: task.isCompleted
                                  ? const Color(0xFF1ED760)
                                  : Colors.white38,
                              width: 1.5,
                            ),
                          ),
                          child: task.isCompleted
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.black, size: 16)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              color: task.isCompleted
                                  ? Colors.white38
                                  : Colors.white,
                              fontSize: 13,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  color: Colors.white38, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                durationText,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Smart Insights Section ───────────────────────────────────────────────

  Widget _buildInsightsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E2C20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF1ED760).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('💡', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                'رؤى تحليلية ذكية',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _insightItem(
            icon: Icons.timer_outlined,
            color: const Color(0xFF1ED760),
            text: _filteredSessions.isNotEmpty
                ? 'أنجزت ${_filteredSessions.length} جلسة تركيز في ${_period.label} بإجمالي ${_formatDuration(_focusMinutes)}. جلسات المؤقت ترفع كفاءتك بنسبة تتجاوز 40%!'
                : 'لم تسجل جلسات مؤقت في ${_period.label} بعد. استخدام جلسات 25 دقيقة يساعدك على الحفاظ على أعلى مستويات التركيز.',
          ),
          const SizedBox(height: 8),
          _insightItem(
            icon: Icons.hourglass_bottom_rounded,
            color: const Color(0xFF34D399),
            text:
                'إجمالي الوقت الإنتاجي الفعلي (مهام + جلسات) هو ${_formatDuration(_totalProductiveMinutes)}.',
          ),
          const SizedBox(height: 8),
          _insightItem(
            icon: Icons.local_fire_department_rounded,
            color: Colors.orangeAccent,
            text: _bestStreak > 0
                ? 'أفضل سلسلة إنجاز عادات مسجلة لديك هي $_bestStreak أيام متتالية! الاستمرارية سر النجاح.'
                : 'حدد عادة يومية بسيطة في متتبع العادات لبدء بناء سلسلة إنجاز قوية.',
          ),
        ],
      ),
    );
  }

  Widget _insightItem({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 12),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _donutLegendRow({
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CUSTOM PAINTERS (ALL DATA-DRIVEN)
// ═══════════════════════════════════════════════════════════════════════════

class _BarChartPainter extends CustomPainter {
  final List<_BarData> bars;
  _BarChartPainter({required this.bars});

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;

    final maxVal = bars.map((b) => b.total).fold(1, math.max).toDouble();
    final chartHeight = size.height - 24;
    final totalBars = bars.length;
    final barSlot = size.width / totalBars;
    final barWidth = math.min(24.0, barSlot * 0.55);

    final bgPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.fill;

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0F9B58), Color(0xFF1ED760)],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    for (int i = 0; i < bars.length; i++) {
      final b = bars[i];
      final centerX = (i * barSlot) + (barSlot / 2);
      final left = centerX - (barWidth / 2);

      final totalH = b.total > 0 ? (b.total / maxVal) * chartHeight : 4.0;
      final compH = b.total > 0 ? (b.completed / maxVal) * chartHeight : 0.0;

      // Background bar (total)
      final totalRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, chartHeight - totalH, barWidth, totalH),
        const Radius.circular(5),
      );
      canvas.drawRRect(totalRRect, bgPaint);

      // Completed filled bar
      if (compH > 0) {
        final compRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, chartHeight - compH, barWidth, compH),
          const Radius.circular(5),
        );
        canvas.drawRRect(compRRect, fillPaint);
      }

      // X Label
      final tp = TextPainter(
        text: TextSpan(
          text: b.label,
          style: const TextStyle(
              color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, Offset(centerX - (tp.width / 2), size.height - 16));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) => true;
}

class _WaveChartPainter extends CustomPainter {
  final List<double> points;
  _WaveChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final maxVal = points.reduce(math.max);
    final safeMax = maxVal == 0 ? 10.0 : maxVal;
    final chartH = size.height - 15;
    final stepX = points.length > 1 ? size.width / (points.length - 1) : 0.0;

    final path = Path();
    final fillPath = Path();

    if (points.length == 1) {
      final y = chartH - (points[0] / safeMax) * chartH;
      canvas.drawCircle(Offset(size.width / 2, y), 5,
          Paint()..color = const Color(0xFF1ED760));
      return;
    }

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = chartH - (points[i] / safeMax) * chartH;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chartH);
        fillPath.lineTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevY = chartH - (points[i - 1] / safeMax) * chartH;
        final cx1 = prevX + (x - prevX) / 2;
        final cy1 = prevY;
        final cx2 = prevX + (x - prevX) / 2;
        final cy2 = y;
        path.cubicTo(cx1, cy1, cx2, cy2, x, y);
        fillPath.cubicTo(cx1, cy1, cx2, cy2, x, y);
      }
    }

    fillPath.lineTo(size.width, chartH);
    fillPath.close();

    // Area fill gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF1ED760).withValues(alpha: 0.25),
          const Color(0xFF1ED760).withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Line
    final linePaint = Paint()
      ..color = const Color(0xFF1ED760)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    // Point dots
    final dotPaint = Paint()..color = const Color(0xFF34D399);
    final dotInner = Paint()..color = const Color(0xFF071911);

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = chartH - (points[i] / safeMax) * chartH;
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
      canvas.drawCircle(Offset(x, y), 1.5, dotInner);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveChartPainter oldDelegate) => true;
}

class _RadialScorePainter extends CustomPainter {
  final double score;
  _RadialScorePainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;

    final bgPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    canvas.drawCircle(center, radius, bgPaint);

    if (score <= 0) return;

    final sweepAngle = (score / 100.0) * 2 * math.pi;
    final arcPaint = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFF0F9B58), Color(0xFF1ED760), Color(0xFF34D399)],
        startAngle: 0.0,
        endAngle: 2 * math.pi,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialScorePainter oldDelegate) =>
      oldDelegate.score != score;
}

class _DonutChartPainter extends CustomPainter {
  final double r1;
  final double r2;
  final double r3;
  _DonutChartPainter({required this.r1, required this.r2, required this.r3});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 14) / 2;
    const strokeW = 9.0;

    final total = r1 + r2 + r3;

    if (total == 0) {
      // Empty outline
      final p = Paint()
        ..color = Colors.white12
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW;
      canvas.drawCircle(center, radius, p);
      return;
    }

    double startAngle = -math.pi / 2;

    void drawSegment(double val, Color col) {
      if (val <= 0) return;
      final sweep = (val / total) * 2 * math.pi;
      final p = Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeW;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep > 0.08 ? sweep - 0.05 : sweep,
        false,
        p,
      );
      startAngle += sweep;
    }

    drawSegment(r1, const Color(0xFF1ED760));
    drawSegment(r2, const Color(0xFF34D399));
    drawSegment(r3, const Color(0xFFF59E0B));
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}
