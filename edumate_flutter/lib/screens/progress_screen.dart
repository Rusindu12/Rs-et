import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isSinhala = state.isSinhala;
    final performance = state.quizPerformanceBySubject;
    final subjects = performance.isEmpty
        ? const ['Maths', 'Science', 'English', 'History', 'ICT']
        : performance.keys.take(5).toList();
    final values = performance.isEmpty
        ? const [78.0, 66.0, 82.0, 71.0, 88.0]
        : subjects.map((subject) => performance[subject] ?? 0).toList();
    final weakSubjects = state.weakSubjects;

    return Scaffold(
      appBar: AppBar(
        title: Text(isSinhala ? 'ඔබේ ඉගෙනුම් ප්‍රගතිය' : 'Your learning progress'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.local_fire_department_rounded,
                  value: '${state.studyStreakDays} days',
                  caption: isSinhala ? 'අඛණ්ඩ ඉගෙනීම' : 'Study streak',
                  color: const Color(0xffF39B4A),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: _MetricCard(
                  icon: Icons.emoji_events_rounded,
                  value: state.quizHistory.isEmpty
                      ? '—'
                      : '${state.averageQuizPercent.round()}%',
                  caption: isSinhala ? 'සාමාන්‍ය ලකුණු' : 'Average score',
                  color: EduColors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          EduCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSinhala ? 'විෂය අනුව ප්‍රතිඵල' : 'Performance by subject',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                Text(
                  performance.isEmpty
                      ? (isSinhala
                          ? 'Sample preview · quiz සම්පූර්ණ කළාම ඔබේ ලකුණු මෙහි පෙන්වයි.'
                          : 'Sample preview · finish a quiz to see your own scores here.')
                      : (isSinhala
                          ? 'Quiz ප්‍රතිඵල අනුව සාමාන්‍ය ලකුණු'
                          : 'Average score from completed quizzes'),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: EduColors.muted),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      maxY: 100,
                      minY: 0,
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 38,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= subjects.length) {
                                return const SizedBox.shrink();
                              }
                              final label = subjects[index];
                              return SideTitleWidget(
                                meta: meta,
                                child: SizedBox(
                                  width: 56,
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: EduColors.muted,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: List.generate(
                        subjects.length,
                        (index) => BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: values[index],
                              width: 22,
                              borderRadius: BorderRadius.circular(9),
                              gradient: const LinearGradient(
                                colors: [Color(0xff8982FF), EduColors.purple],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    duration: const Duration(milliseconds: 500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          EduCard(
            color: const Color(0xffFFF7E8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_rounded,
                    color: Color(0xffEDA63E)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    weakSubjects.isNotEmpty
                        ? '${isSinhala ? 'තවත් පුහුණු විය යුතු විෂයයන්:' : 'Subjects to revisit:'} ${weakSubjects.join(', ')}'
                        : (isSinhala
                            ? 'Quiz කිහිපයක් සම්පූර්ණ කළාම දුර්වල පාඩම් වඩා නිවැරදිව හඳුනාගන්න පුළුවන්.'
                            : 'Complete quizzes to get personalized weak-area suggestions.'),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isSinhala ? 'මෑත quiz' : 'Recent quizzes',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (state.quizHistory.isEmpty)
            EduCard(
              child: Text(isSinhala
                  ? 'ඔබේ පළමු quiz එක සම්පූර්ණ කළාම ප්‍රතිඵල මෙහි දිස්වෙයි.'
                  : 'Finish a quiz and your results will show up here.'),
            )
          else
            ...state.quizHistory.take(8).map((item) {
              final score = (item['score'] as num?)?.toInt() ?? 0;
              final total = (item['total'] as num?)?.toInt() ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: EduCard(
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: EduColors.green),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(item['subject']?.toString() ?? 'Quiz',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Text('$score / $total',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: EduColors.purple)),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.caption,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) => EduCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              caption,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: EduColors.muted),
            ),
          ],
        ),
      );
}
