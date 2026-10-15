import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_strings.dart';
import '../data/curriculum.dart';
import '../models/study_models.dart';
import '../providers/app_state.dart';
import '../services/curriculum_repository.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'chat_screen.dart';
import 'past_papers_screen.dart';
import 'pdf_viewer_screen.dart';
import 'quiz_screen.dart';

class GradeSelectionScreen extends StatelessWidget {
  const GradeSelectionScreen({super.key, this.initialGrade});

  final int? initialGrade;

  void _openGrade(BuildContext context, int grade) {
    if (grade >= 12) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => StreamSelectionScreen(grade: grade)));
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => SubjectSelectionScreen(grade: grade)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = AppStrings(state.isSinhala);
    return Scaffold(
      appBar: AppBar(title: Text(state.isSinhala ? 'ශ්‍රේණිය තෝරන්න' : 'Choose your grade')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(state.isSinhala ? 'ඔබේ ඉගෙනුම් මට්ටමට ගැළපෙන පාඩම් සොයාගන්න.' : 'Find lessons matched to your school level.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: EduColors.muted)),
          const SizedBox(height: 18),
          _GradeGroup(title: state.isSinhala ? 'ප්‍රාථමික · Grade 1–5' : 'PRIMARY · GRADE 1–5', grades: const [1, 2, 3, 4, 5], color: const Color(0xff5CB78A), onSelect: (grade) => _openGrade(context, grade), selected: initialGrade),
          const SizedBox(height: 14),
          _GradeGroup(title: state.isSinhala ? 'කනිෂ්ඨ ද්විතීයික · Grade 6–9' : 'JUNIOR SECONDARY · GRADE 6–9', grades: const [6, 7, 8, 9], color: const Color(0xff4D9DE0), onSelect: (grade) => _openGrade(context, grade), selected: initialGrade),
          const SizedBox(height: 14),
          _GradeGroup(title: state.isSinhala ? 'සාමාන්‍ය පෙළ · Grade 10–11' : 'ORDINARY LEVEL · GRADE 10–11', grades: const [10, 11], color: EduColors.purple, onSelect: (grade) => _openGrade(context, grade), selected: initialGrade),
          const SizedBox(height: 14),
          _GradeGroup(title: state.isSinhala ? 'උසස් පෙළ · Grade 12–13' : 'ADVANCED LEVEL · GRADE 12–13', grades: const [12, 13], color: EduColors.coral, onSelect: (grade) => _openGrade(context, grade), selected: initialGrade),
          const SizedBox(height: 12),
          Text(strings.browse, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: EduColors.muted), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _GradeGroup extends StatelessWidget {
  const _GradeGroup({required this.title, required this.grades, required this.color, required this.onSelect, this.selected});

  final String title;
  final List<int> grades;
  final Color color;
  final ValueChanged<int> onSelect;
  final int? selected;

  @override
  Widget build(BuildContext context) => EduCard(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: grades.map((grade) {
                final isSelected = selected == grade;
                return InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () => onSelect(grade),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(color: isSelected ? color : color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(15)),
                    child: Center(child: Text('$grade', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isSelected ? Colors.white : color))),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
}

class StreamSelectionScreen extends StatelessWidget {
  const StreamSelectionScreen({required this.grade, super.key});

  final int grade;

  @override
  Widget build(BuildContext context) {
    final isSinhala = context.watch<AppState>().isSinhala;
    return Scaffold(
      appBar: AppBar(title: Text(isSinhala ? 'විෂය ධාරාව තෝරන්න' : 'Choose your A/L stream')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GradientPanel(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [const MascotBadge(size: 52), const SizedBox(width: 14), Expanded(child: Text(isSinhala ? 'ඔබේ උසස් පෙළ ගමනට සුදුසු ධාරාව තෝරන්න.' : 'Choose a stream to see your Grade $grade subjects.', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))]),
            ),
          ),
          const SizedBox(height: 17),
          ...streamOptions.map((stream) => Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: EduCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SubjectSelectionScreen(grade: grade, streamId: stream.id))),
                  child: Row(
                    children: [
                      Container(width: 48, height: 48, decoration: BoxDecoration(color: stream.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(15)), child: Center(child: Text(stream.icon, style: const TextStyle(fontSize: 22)))),
                      const SizedBox(width: 13),
                      Expanded(child: Text(stream.title(isSinhala), style: const TextStyle(fontWeight: FontWeight.w800))),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class SubjectSelectionScreen extends StatelessWidget {
  const SubjectSelectionScreen({required this.grade, super.key, this.streamId});

  final int grade;
  final String? streamId;

  @override
  Widget build(BuildContext context) {
    final isSinhala = context.watch<AppState>().isSinhala;
    final subjects = subjectsForGrade(grade, streamId: streamId);
    return Scaffold(
      appBar: AppBar(title: Text(isSinhala ? 'විෂයයක් තෝරන්න' : 'Choose a subject')),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: subjects.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.18, mainAxisSpacing: 12, crossAxisSpacing: 12),
        itemBuilder: (context, index) {
          final subject = subjects[index];
          return EduCard(
            padding: const EdgeInsets.all(16),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChapterListScreen(grade: grade, streamId: streamId, subject: subject))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: subject.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(15)), child: Icon(subject.icon, color: subject.color)),
                Text(subject.title(isSinhala), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(isSinhala ? 'පාඩම් බලන්න  →' : 'View chapters  →', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: EduColors.muted)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ChapterListScreen extends StatelessWidget {
  const ChapterListScreen({required this.grade, required this.subject, super.key, this.streamId});

  final int grade;
  final String? streamId;
  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final isSinhala = context.watch<AppState>().isSinhala;
    return Scaffold(
      appBar: AppBar(title: Text(subject.title(isSinhala))),
      body: FutureBuilder<List<Chapter>>(
        future: CurriculumRepository.chaptersFor(grade: grade, subject: subject),
        builder: (context, snapshot) {
          final chapters = snapshot.data ?? chaptersFor(subject);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              EduCard(
                color: subject.color.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    Container(width: 50, height: 50, decoration: BoxDecoration(color: subject.color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(16)), child: Icon(subject.icon, color: subject.color, size: 28)),
                    const SizedBox(width: 13),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Grade $grade · ${subject.title(isSinhala)}', style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(isSinhala ? 'විෂය නිර්දේශයේ අනුපිළිවෙළට' : 'Chapters in syllabus order', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12))])),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else
                ...chapters.asMap().entries.map((entry) {
                  final index = entry.key;
                  final chapter = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: EduCard(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChapterDetailScreen(grade: grade, streamId: streamId, subject: subject, chapter: chapter))),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(width: 40, height: 40, decoration: BoxDecoration(color: subject.color.withValues(alpha: 0.11), shape: BoxShape.circle), child: Center(child: Text('${index + 1}', style: TextStyle(color: subject.color, fontWeight: FontWeight.w900)))),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(chapter.title(isSinhala), style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(chapter.summary(isSinhala), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: EduColors.muted))])),
                              const Icon(Icons.chevron_right_rounded, color: EduColors.muted),
                            ],
                          ),
                          const SizedBox(height: 13),
                          Row(children: [Expanded(child: ProgressLine(value: chapter.progress, color: subject.color)), const SizedBox(width: 10), Text('${(chapter.progress * 100).round()}%', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: EduColors.muted))]),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class ChapterDetailScreen extends StatelessWidget {
  const ChapterDetailScreen({required this.grade, required this.subject, required this.chapter, super.key, this.streamId});

  final int grade;
  final String? streamId;
  final Subject subject;
  final Chapter chapter;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = AppStrings(state.isSinhala);
    final studyContext = StudyContext(
      grade: grade,
      streamId: streamId,
      subjectId: subject.id,
      subjectName: subject.title(state.isSinhala),
      chapterId: chapter.id,
      chapterName: chapter.title(state.isSinhala),
    );
    final tabs = [strings.notes, strings.video, strings.quiz, strings.papers, strings.chat];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(chapter.title(state.isSinhala), maxLines: 1, overflow: TextOverflow.ellipsis),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: tabs.map((tab) => Tab(text: tab)).toList(),
          ),
        ),
        body: TabBarView(
          children: [
            _NotesTab(chapter: chapter, subject: subject, isSinhala: state.isSinhala),
            _VideoTab(chapter: chapter, isSinhala: state.isSinhala),
            _QuizTab(grade: grade, subject: subject, chapter: chapter, isSinhala: state.isSinhala),
            PastPapersScreen(grade: grade, subject: subject, embedded: true),
            ChatScreen(studyContext: studyContext, embedded: true),
          ],
        ),
      ),
    );
  }
}

class _NotesTab extends StatelessWidget {
  const _NotesTab({required this.chapter, required this.subject, required this.isSinhala});

  final Chapter chapter;
  final Subject subject;
  final bool isSinhala;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          GradientPanel(
            child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.lightbulb_outline_rounded, color: Colors.white, size: 29), const SizedBox(height: 10), Text(chapter.title(isSinhala), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)), const SizedBox(height: 7), Text(chapter.summary(isSinhala), style: TextStyle(color: Colors.white.withValues(alpha: 0.87)))])),
          ),
          const SizedBox(height: 17),
          SectionTitle(title: isSinhala ? 'මෙම පාඩමේ ප්‍රධාන කරුණු' : 'Key ideas in this lesson'),
          const SizedBox(height: 10),
          ...chapter.notes.map((note) => Padding(padding: const EdgeInsets.only(bottom: 10), child: EduCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle_rounded, color: EduColors.green, size: 20), const SizedBox(width: 10), Expanded(child: Text(note, style: const TextStyle(height: 1.55)))])))),
          if (chapter.notesPdfUrl != null && chapter.notesPdfUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () async {
                try {
                  final file = await PdfService.download(url: chapter.notesPdfUrl!, fileName: '${subject.id}-${chapter.id}-notes.pdf');
                  if (!context.mounted) return;
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => PdfViewerScreen(filePath: file.path, title: 'Lesson notes')));
                } catch (error) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF download අසාර්ථකයි: $error')));
                }
              },
              icon: const Icon(Icons.download_rounded),
              label: Text(isSinhala ? 'සටහන් PDF බාගන්න' : 'Download notes PDF'),
            ),
          ],
        ],
      );
}

class _VideoTab extends StatelessWidget {
  const _VideoTab({required this.chapter, required this.isSinhala});

  final Chapter chapter;
  final bool isSinhala;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          EduCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Container(width: 92, height: 92, decoration: BoxDecoration(color: EduColors.coral.withValues(alpha: 0.11), shape: BoxShape.circle), child: const Icon(Icons.play_circle_fill_rounded, size: 62, color: EduColors.coral)),
                const SizedBox(height: 16),
                Text(isSinhala ? 'පාඩම් වීඩියෝව' : 'Lesson video', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                Text(isSinhala ? 'ගුරුවරයා සකස් කළ වීඩියෝවක් මෙහි දිස්වනු ඇත.' : 'A teacher-curated lesson video will appear here.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: EduColors.muted, height: 1.5)),
                if (chapter.videoUrl != null && chapter.videoUrl!.isNotEmpty) ...[
                  const SizedBox(height: 17),
                  FilledButton.icon(
                    onPressed: () async {
                      final uri = Uri.tryParse(chapter.videoUrl!);
                      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(isSinhala ? 'වීඩියෝව නරඹන්න' : 'Watch video'),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
}

class _QuizTab extends StatelessWidget {
  const _QuizTab({required this.grade, required this.subject, required this.chapter, required this.isSinhala});

  final int grade;
  final Subject subject;
  final Chapter chapter;
  final bool isSinhala;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          EduCard(
            color: const Color(0xffFFF4E8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.quiz_rounded, color: Color(0xffE89439), size: 34), const SizedBox(height: 12), Text(isSinhala ? 'දැනුම පරීක්ෂා කරමු!' : 'Ready for a quick check?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(isSinhala ? 'කෙටි ප්‍රශ්න 5ක් · පිළිතුරු සමඟ පැහැදිලි කිරීම' : '5 questions · instant explanations', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: EduColors.muted)), const SizedBox(height: 16), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuizScreen(subject: subject, chapter: chapter))), icon: const Icon(Icons.play_arrow_rounded), label: Text(isSinhala ? 'Quiz එක ආරම්භ කරන්න' : 'Start quiz')))]),
          ),
        ],
      );
}
