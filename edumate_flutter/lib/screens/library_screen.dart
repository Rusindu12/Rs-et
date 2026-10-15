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

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile!;
    final strings = AppStrings(state.isSinhala);
    final allSubjects = subjectsForGrade(profile.grade, streamId: profile.streamId);
    final query = _search.text.trim().toLowerCase();
    final subjects = allSubjects.where((subject) => query.isEmpty || subject.nameEn.toLowerCase().contains(query) || subject.nameSi.contains(query)).toList();
    return Scaffold(
      appBar: AppBar(title: Text(strings.library), actions: [IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProgressScreen())), icon: const Icon(Icons.insights_rounded))]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        children: [
          Text(state.isSinhala ? 'සටහන්, විෂයයන් සහ පත්‍ර — එකම තැනක.' : 'Notes, syllabus and exam practice, all in one place.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: EduColors.muted)),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: state.isSinhala ? 'විෂයයක් සොයන්න…' : 'Search subjects…', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: _search.text.isEmpty ? null : IconButton(onPressed: () { _search.clear(); setState(() {}); }, icon: const Icon(Icons.close_rounded))),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _LibraryAction(icon: Icons.school_rounded, title: state.isSinhala ? 'ශ්‍රේණි / විෂය නිර්දේශය' : 'Grade syllabus', color: EduColors.purple, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GradeSelectionScreen(initialGrade: profile.grade))))),
              const SizedBox(width: 10),
              Expanded(child: _LibraryAction(icon: Icons.picture_as_pdf_rounded, title: state.isSinhala ? 'පසුගිය පත්‍ර' : 'Past papers', color: EduColors.coral, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PastPapersScreen(grade: profile.grade, subject: allSubjects.isNotEmpty ? allSubjects.first : primarySubjects[1]))))),
            ],
          ),
          const SizedBox(height: 24),
          SectionTitle(title: '${strings.subjects} · Grade ${profile.grade}'),
          const SizedBox(height: 11),
          if (subjects.isEmpty)
            EduCard(child: Text(state.isSinhala ? 'ගැළපෙන විෂයයක් නැහැ.' : 'No matching subject found.'))
          else
            ...subjects.map((subject) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SubjectRow(
                    subject: subject,
                    isSinhala: state.isSinhala,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChapterListScreen(grade: profile.grade, streamId: profile.streamId, subject: subject))),
                    onPapers: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PastPapersScreen(grade: profile.grade, subject: subject))),
                  ),
                )),
          const SizedBox(height: 16),
          EduCard(
            color: const Color(0xffEEF7FF),
            child: Row(children: [const Icon(Icons.offline_bolt_rounded, color: Color(0xff438FE3), size: 28), const SizedBox(width: 12), Expanded(child: Text(state.isSinhala ? 'Sample පාඩම් offline ලෙස සූදානම්. Download කළ PDF ගොනු device එකේ රැඳේ.' : 'Sample lessons are available offline. Downloaded PDFs stay on this device.', style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5)))]),
          ),
        ],
      ),
    );
  }
}

class _LibraryAction extends StatelessWidget {
  const _LibraryAction({required this.icon, required this.title, required this.color, required this.onTap});

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => EduCard(
        padding: const EdgeInsets.all(13),
        onTap: onTap,
        child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color, size: 21)), const SizedBox(width: 9), Expanded(child: Text(title, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)))]),
      );
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.subject, required this.isSinhala, required this.onTap, required this.onPapers});

  final Subject subject;
  final bool isSinhala;
  final VoidCallback onTap;
  final VoidCallback onPapers;

  @override
  Widget build(BuildContext context) => EduCard(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(
          children: [
            Container(width: 43, height: 43, decoration: BoxDecoration(color: subject.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)), child: Icon(subject.icon, color: subject.color)),
            const SizedBox(width: 11),
            Expanded(child: InkWell(onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(subject.title(isSinhala), style: const TextStyle(fontWeight: FontWeight.w800)), Text(isSinhala ? 'පාඩම් බලන්න' : 'Browse chapters', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: EduColors.muted))]))),
            IconButton(tooltip: isSinhala ? 'ප්‍රශ්න පත්‍ර' : 'Past papers', onPressed: onPapers, icon: const Icon(Icons.picture_as_pdf_outlined, color: EduColors.coral)),
            IconButton(onPressed: onTap, icon: const Icon(Icons.chevron_right_rounded)),
          ],
        ),
      );
}
