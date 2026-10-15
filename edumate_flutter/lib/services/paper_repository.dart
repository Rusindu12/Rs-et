import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/study_models.dart';
import 'firebase_service.dart';

class PastPaper {
  const PastPaper({
    required this.id,
    required this.year,
    required this.title,
    required this.markingScheme,
    this.pdfUrl,
  });

  final String id;
  final int year;
  final String title;
  final bool markingScheme;
  final String? pdfUrl;
}

class PaperRepository {
  static Future<List<PastPaper>> load({
    required int grade,
    required Subject subject,
    required bool markingScheme,
  }) async {
    if (!FirebaseService.isReady) return const [];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('grades')
          .doc('$grade')
          .collection('subjects')
          .doc(subject.id)
          .collection('papers')
          .where('markingScheme', isEqualTo: markingScheme)
          .orderBy('year', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return PastPaper(
          id: doc.id,
          year: (data['year'] as num?)?.toInt() ?? 0,
          title: data['title']?.toString() ?? doc.id,
          markingScheme: data['markingScheme'] == true,
          pdfUrl: data['pdfUrl']?.toString(),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }
}
