import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/curriculum.dart';
import '../models/study_models.dart';
import '../providers/app_state.dart';
import '../services/offline_cache.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'pdf_viewer_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, this.subject, this.chapter, this.active = true});

  final Subject? subject;
  final Chapter? chapter;
  final bool active;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _confetti = ConfettiController(duration: const Duration(seconds: 3));
  Timer? _timer;
  int _questionIndex = 0;
  int? _selectedIndex;
  int _secondsLeft = 180;
  bool _finished = false;
  bool _recorded = false;
  late List<QuizQuestion> _questions;
  final Map<int, int> _answers = {};

  String get _subjectName => widget.subject?.nameEn ?? 'Mathematics';
  String get _quizCacheKey => 'quiz-${widget.subject?.id ?? 'mathematics'}';

  @override
  void initState() {
    super.initState();
    _questions = OfflineCache.loadQuiz(_quizCacheKey) ?? quizForSubject(widget.subject?.id);
    OfflineCache.saveQuiz(_quizCacheKey, _questions);
    if (widget.active) _startTimer();
  }

  @override
  void didUpdateWidget(covariant QuizScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _startTimer();
    } else if (!widget.active && oldWidget.active) {
      _timer?.cancel();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _finished) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        setState(() => _secondsLeft = 0);
        _finishQuiz();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _choose(int index) {
    if (_selectedIndex != null || _finished) return;
    setState(() {
      _selectedIndex = index;
      _answers[_questionIndex] = index;
    });
  }

  void _next() {
    if (_selectedIndex == null) return;
    if (_questionIndex == _questions.length - 1) {
      _finishQuiz();
      return;
    }
    setState(() {
      _questionIndex++;
      _selectedIndex = _answers[_questionIndex];
    });
  }

  void _finishQuiz() {
    if (_finished) return;
    _timer?.cancel();
    final score = _answers.entries
        .where((entry) => _questions[entry.key].correctIndex == entry.value)
        .length;
    setState(() => _finished = true);
    _confetti.play();
    if (!_recorded) {
      _recorded = true;
      context.read<AppState>().recordQuiz(
            score: score,
            total: _questions.length,
            subject: _subjectName,
          );
    }
  }

  void _restart() {
    setState(() {
      _questionIndex = 0;
      _selectedIndex = null;
      _secondsLeft = 180;
      _finished = false;
      _recorded = false;
      _answers.clear();
    });
    _confetti.stop();
    _startTimer();
  }

  Future<void> _exportResult() async {
    final state = context.read<AppState>();
    final score = _answers.entries
        .where((entry) => _questions[entry.key].correctIndex == entry.value)
        .length;
    try {
      final file = await PdfService.export(
        baseUrl: state.backendUrl,
        endpoint: '/api/export/quiz.pdf',
        payload: {
          'title': 'EduMate AI · $_subjectName',
          'score': score,
          'total': _questions.length,
          'questions': _questions.asMap().entries.map((entry) => {
                'question': entry.value.question,
                'selected': _answers[entry.key] == null
                    ? 'Not answered'
                    : entry.value.options[_answers[entry.key]!],
                'correct': entry.value.options[entry.value.correctIndex],
                'explanation': entry.value.explanation,
              }).toList(),
        },
        fileName: 'edumate-quiz-result.pdf',
      );
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PdfViewerScreen(filePath: file.path, title: 'Quiz result'),
      ));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF export අසාර්ථකයි: $error')));
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSinhala = context.watch<AppState>().isSinhala;
    if (_finished) return _resultView(context, isSinhala);
    final question = _questions[_questionIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.chapter?.title(isSinhala) ??
              (isSinhala ? 'දෛනික Quiz' : 'Quick quiz'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: _secondsLeft < 30
                  ? const Color(0xffFFF0F0)
                  : EduColors.purple.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined,
                    size: 17,
                    color: _secondsLeft < 30 ? EduColors.coral : EduColors.purple),
                const SizedBox(width: 5),
                Text(
                  _formatTime(_secondsLeft),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _secondsLeft < 30 ? EduColors.coral : EduColors.purple,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 5, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isSinhala
                        ? 'ප්‍රශ්නය ${_questionIndex + 1} / ${_questions.length}'
                        : 'QUESTION ${_questionIndex + 1} OF ${_questions.length}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: EduColors.muted,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                  ),
                ),
                Text(
                  '${((_questionIndex + 1) / _questions.length * 100).round()}%',
                  style: const TextStyle(
                      color: EduColors.purple, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ProgressLine(value: (_questionIndex + 1) / _questions.length),
            const SizedBox(height: 19),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: EduCard(
                key: ValueKey(_questionIndex),
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: EduColors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.help_outline_rounded,
                          color: EduColors.purple),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      question.question,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...question.options.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AnswerOption(
                    index: entry.key,
                    label: entry.value,
                    selected: _selectedIndex == entry.key,
                    correct: _selectedIndex != null &&
                        entry.key == question.correctIndex,
                    wrong: _selectedIndex == entry.key &&
                        entry.key != question.correctIndex,
                    enabled: _selectedIndex == null,
                    onTap: () => _choose(entry.key),
                  ),
                )),
            if (_selectedIndex != null) ...[
              const SizedBox(height: 4),
              EduCard(
                color: _selectedIndex == question.correctIndex
                    ? const Color(0xffECF8F0)
                    : const Color(0xffFFF1EF),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _selectedIndex == question.correctIndex
                          ? Icons.check_circle_rounded
                          : Icons.lightbulb_rounded,
                      color: _selectedIndex == question.correctIndex
                          ? EduColors.green
                          : EduColors.coral,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(question.explanation,
                        style: const TextStyle(height: 1.5))),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                      backgroundColor: EduColors.purple,
                      padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: Text(_questionIndex == _questions.length - 1
                      ? (isSinhala ? 'ප්‍රතිඵල බලන්න' : 'See my result')
                      : (isSinhala ? 'ඊළඟ ප්‍රශ්නය' : 'Next question')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resultView(BuildContext context, bool isSinhala) {
    final score = _answers.entries
        .where((entry) => _questions[entry.key].correctIndex == entry.value)
        .length;
    final percent = (score / _questions.length * 100).round();
    return Scaffold(
      appBar: AppBar(title: Text(isSinhala ? 'Quiz ප්‍රතිඵලය' : 'Quiz result')),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(22, 25, 22, 28),
            children: [
              Center(
                child: Container(
                  width: 124,
                  height: 124,
                  decoration: BoxDecoration(
                    color: EduColors.purple.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    percent >= 60
                        ? Icons.emoji_events_rounded
                        : Icons.school_rounded,
                    size: 68,
                    color: percent >= 60
                        ? const Color(0xffF2B84B)
                        : EduColors.purple,
                  ),
                ),
              ),
              const SizedBox(height: 19),
              Text(
                percent >= 80
                    ? (isSinhala ? 'නියමයි! 🌟' : 'Amazing work! 🌟')
                    : (isSinhala ? 'හොඳ උත්සාහයක්! 💜' : 'Great effort! 💜'),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                isSinhala
                    ? 'ඉගෙනීමේ හැම පියවරක්ම වැදගත්.'
                    : 'Every practice session makes you stronger.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: EduColors.muted),
              ),
              const SizedBox(height: 20),
              EduCard(
                child: Column(
                  children: [
                    Text('$score / ${_questions.length}',
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: EduColors.purple)),
                    const SizedBox(height: 4),
                    Text(
                      '${isSinhala ? 'ලකුණු' : 'score'} · $percent%',
                      style: const TextStyle(
                          color: EduColors.muted, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 15),
                    ProgressLine(value: score / _questions.length),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _exportResult,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(isSinhala
                    ? 'ප්‍රතිඵල PDF එක බාගන්න'
                    : 'Export result PDF'),
              ),
              const SizedBox(height: 9),
              OutlinedButton.icon(
                onPressed: _restart,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(isSinhala ? 'නැවත උත්සාහ කරන්න' : 'Try again'),
              ),
            ],
          ),
          IgnorePointer(
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 22,
              maxBlastForce: 18,
              minBlastForce: 6,
              emissionFrequency: 0.05,
              gravity: 0.22,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.index,
    required this.label,
    required this.selected,
    required this.correct,
    required this.wrong,
    required this.enabled,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool selected;
  final bool correct;
  final bool wrong;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = correct
        ? EduColors.green
        : (wrong ? EduColors.coral : EduColors.purple);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: correct
            ? const Color(0xffECF8F0)
            : (wrong
                ? const Color(0xffFFF1EF)
                : Theme.of(context).cardTheme.color),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: selected || correct ? color : const Color(0xffECECF5),
          width: selected || correct ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(17),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(
                        alpha: selected || correct ? 0.14 : 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(65 + index),
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(label,
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                if (correct)
                  const Icon(Icons.check_circle_rounded, color: EduColors.green)
                else if (wrong)
                  const Icon(Icons.cancel_rounded, color: EduColors.coral),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
