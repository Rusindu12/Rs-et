import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_strings.dart';
import '../data/curriculum.dart';
import '../models/study_models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'curriculum_screens.dart';
import 'past_papers_screen.dart';
import 'progress_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.onSelectTab, super.key});

  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile!;
    final strings = AppStrings(state.isSinhala);
    final subjects = subjectsForGrade(profile.grade, streamId: profile.streamId);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            const MascotBadge(size: 42, color: EduColors.purple),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EduMate AI', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                Text('Sri Lanka • Grade ${profile.grade}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: EduColors.muted)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Progress',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProgressScreen())),
            icon: const Icon(Icons.insights_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: EduColors.purple.withValues(alpha: 0.12),
              child: Text(profile.name.isEmpty ? 'S' : profile.name[0].toUpperCase(), style: const TextStyle(color: EduColors.purple, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
          children: [
            GradientPanel(
              child: Padding(
                padding: const EdgeInsets.all(21),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.isSinhala ? 'ආයුබෝවන්, ${profile.name} 👋' : 'Good day, ${profile.name} 👋',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                state.isSinhala ? 'අදත් පොඩි පියවරක් ඉදිරියට යමු!' : 'Let’s make a little progress today!',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.87)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        const MascotBadge(size: 58),
                      ],
                    ),
                    const SizedBox(height: 19),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(15)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: Color(0xffFFD166), size: 22),
                          const SizedBox(width: 7),
                          Text('${state.studyStreakDays}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                          const SizedBox(width: 5),
                          Text(strings.studyStreak, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SectionTitle(title: state.isSinhala ? 'ඉක්මන් ප්‍රවේශය' : 'Quick access'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.02,
              children: [
                _QuickAction(icon: Icons.auto_awesome_rounded, title: strings.chat, color: EduColors.purple, onTap: () => onSelectTab(1)),
                _QuickAction(icon: Icons.quiz_rounded, title: strings.quiz, color: const Color(0xffF39B4A), onTap: () => onSelectTab(3)),
                _QuickAction(icon: Icons.sticky_note_2_rounded, title: strings.notes, color: const Color(0xff30A98B), onTap: () => onSelectTab(2)),
                _QuickAction(icon: Icons.picture_as_pdf_rounded, title: strings.papers, color: EduColors.coral, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PastPapersScreen(grade: profile.grade, subject: subjects.isEmpty ? primarySubjects[1] : subjects.first))) ,),
                _QuickAction(icon: Icons.search_rounded, title: strings.search, color: const Color(0xff438FE3), onTap: () => onSelectTab(2)),
                _QuickAction(icon: Icons.insights_rounded, title: state.isSinhala ? 'ප්‍රගතිය' : 'Progress', color: const Color(0xffA675D5), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProgressScreen()))),
              ],
            ),
            const SizedBox(height: 24),
            SectionTitle(
              title: '${strings.subjects} · Grade ${profile.grade}',
              actionLabel: strings.browse,
              onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GradeSelectionScreen(initialGrade: profile.grade))),
            ),
            const SizedBox(height: 12),
            if (subjects.isEmpty)
              EduCard(
                child: Column(
                  children: [
                    const Icon(Icons.school_rounded, size: 38, color: EduColors.purple),
                    const SizedBox(height: 8),
                    Text(state.isSinhala ? 'විෂය ධාරාවක් තෝරන්න' : 'Choose your A/L stream'),
                    TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GradeSelectionScreen(initialGrade: profile.grade))), child: Text(strings.browse)),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: subjects.take(4).length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.68, mainAxisSpacing: 11, crossAxisSpacing: 11),
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  return _SubjectCard(
                    subject: subject,
                    sinhala: state.isSinhala,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChapterListScreen(grade: profile.grade, streamId: profile.streamId, subject: subject))),
                  );
                },
              ),
            const SizedBox(height: 24),
            SectionTitle(title: state.isSinhala ? 'අද ඉගෙනුම් ඉලක්කය' : 'Today’s study goal'),
            const SizedBox(height: 10),
            EduCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xffF0EFFF), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.track_changes_rounded, color: EduColors.purple)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(state.isSinhala ? 'විනාඩි 30ක් අධ්‍යයනය කරන්න' : 'Study for 30 minutes', style: const TextStyle(fontWeight: FontWeight.w800))),
                      const Text('20/30 min', style: TextStyle(color: EduColors.muted, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const ProgressLine(value: 0.67),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.title, required this.color, required this.onTap});

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              boxShadow: [BoxShadow(color: const Color(0xff35356B).withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 23)),
                const SizedBox(height: 7),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject, required this.sinhala, required this.onTap});

  final Subject subject;
  final bool sinhala;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => EduCard(
        padding: const EdgeInsets.all(13),
        onTap: onTap,
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: subject.color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(15)), child: Icon(subject.icon, color: subject.color)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subject.title(sinhala), maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(sinhala ? 'පාඩම් 5ක්' : '5 chapters', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: EduColors.muted)),
                ],
              ),
            ),
          ],
        ),
      );
}
