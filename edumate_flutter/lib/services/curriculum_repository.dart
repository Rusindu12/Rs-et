import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/curriculum.dart' as syllabus;
import '../models/study_models.dart';
import 'firebase_service.dart';
import 'offline_cache.dart';

/// Reads Firestore content when available and keeps a local Hive copy for
/// offline study. Bundled examples are always available as a final fallback.
class CurriculumRepository {
  static Future<List<Chapter>> chaptersFor({
    required int grade,
    required Subject subject,
  }) async {
    final cacheKey = 'g$grade-${subject.id}';
    final bundled = syllabus.chaptersFor(subject);
    if (!FirebaseService.isReady) {
      return OfflineCache.loadChapters(cacheKey) ?? bundled;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('grades')
          .doc('$grade')
          .collection('subjects')
          .doc(subject.id)
          .collection('chapters')
          .orderBy('order')
          .get();
      if (snapshot.docs.isEmpty) {
        return OfflineCache.loadChapters(cacheKey) ?? bundled;
      }

      final chapters = snapshot.docs.map((doc) {
        final data = doc.data();
        final content = data['content'] is Map
            ? Map<String, dynamic>.from(data['content'] as Map)
            : <String, dynamic>{};
        return Chapter(
          id: doc.id,
          titleEn: data['titleEn']?.toString() ?? doc.id,
          titleSi: data['titleSi']?.toString() ?? data['titleEn']?.toString() ?? doc.id,
          summaryEn: data['summaryEn']?.toString() ?? '',
          summarySi: data['summarySi']?.toString() ?? '',
          progress: 0,
          notes: (content['notes'] as List? ?? const [])
              .map((item) => item.toString())
              .toList(),
          videoUrl: content['videoUrl']?.toString(),
          notesPdfUrl: content['notesPdfUrl']?.toString(),
        );
      }).toList();
      await OfflineCache.saveChapters(cacheKey, chapters);
      return chapters;
    } catch (_) {
      return OfflineCache.loadChapters(cacheKey) ?? bundled;
    }
  }
}
