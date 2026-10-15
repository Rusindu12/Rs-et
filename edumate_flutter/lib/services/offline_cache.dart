import 'package:hive/hive.dart';

import '../models/study_models.dart';

/// Hive cache for Firestore lesson data and quiz questions. The bundled sample
/// curriculum remains the first fallback if a chapter has never been downloaded.
class OfflineCache {
  static Box<dynamic> get _box => Hive.box<dynamic>('edumate_local');

  static Future<void> saveChapters(String key, List<Chapter> chapters) async {
    await _box.put('cache:chapters:$key', chapters.map((chapter) => {
          'id': chapter.id,
          'titleEn': chapter.titleEn,
          'titleSi': chapter.titleSi,
          'summaryEn': chapter.summaryEn,
          'summarySi': chapter.summarySi,
          'progress': chapter.progress,
          'notes': chapter.notes,
          'videoUrl': chapter.videoUrl,
          'notesPdfUrl': chapter.notesPdfUrl,
        }).toList());
  }

  static List<Chapter>? loadChapters(String key) {
    final raw = _box.get('cache:chapters:$key');
    if (raw is! List || raw.isEmpty) return null;
    return raw.whereType<Map>().map((item) => Chapter(
          id: item['id']?.toString() ?? '',
          titleEn: item['titleEn']?.toString() ?? '',
          titleSi: item['titleSi']?.toString() ?? '',
          summaryEn: item['summaryEn']?.toString() ?? '',
          summarySi: item['summarySi']?.toString() ?? '',
          progress: (item['progress'] as num?)?.toDouble() ?? 0,
          notes: (item['notes'] as List? ?? const []).map((note) => note.toString()).toList(),
          videoUrl: item['videoUrl']?.toString(),
          notesPdfUrl: item['notesPdfUrl']?.toString(),
        )).toList();
  }

  static Future<void> saveQuiz(String key, List<QuizQuestion> questions) async {
    await _box.put('cache:quiz:$key', questions.map((question) => {
          'question': question.question,
          'options': question.options,
          'correctIndex': question.correctIndex,
          'explanation': question.explanation,
        }).toList());
  }

  static List<QuizQuestion>? loadQuiz(String key) {
    final raw = _box.get('cache:quiz:$key');
    if (raw is! List || raw.isEmpty) return null;
    return raw.whereType<Map>().map((item) => QuizQuestion(
          question: item['question']?.toString() ?? '',
          options: (item['options'] as List? ?? const []).map((option) => option.toString()).toList(),
          correctIndex: (item['correctIndex'] as num?)?.toInt() ?? 0,
          explanation: item['explanation']?.toString() ?? '',
        )).toList();
  }
}
