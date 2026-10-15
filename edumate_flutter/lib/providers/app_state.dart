import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/study_models.dart';
import '../services/firebase_service.dart';

class AppState extends ChangeNotifier {
  AppState(this._box);

  final Box<dynamic> _box;
  StudentProfile? profile;
  bool isDarkMode = false;
  bool isSinhala = true;
  bool notificationsEnabled = true;
  String backendUrl = 'http://10.0.2.2:8000';
  final List<Map<String, dynamic>> quizHistory = [];
  final Set<String> _studyDays = {};

  Future<void> restore() async {
    final savedProfile = _box.get('profile');
    if (savedProfile is Map) profile = StudentProfile.fromMap(savedProfile);
    isDarkMode = _box.get('darkMode', defaultValue: false) as bool;
    isSinhala = _box.get('isSinhala', defaultValue: true) as bool;
    notificationsEnabled =
        _box.get('notificationsEnabled', defaultValue: true) as bool;
    backendUrl = _box.get('backendUrl', defaultValue: backendUrl) as String;
    final savedHistory = _box.get('quizHistory');
    if (savedHistory is List) {
      quizHistory
        ..clear()
        ..addAll(savedHistory.whereType<Map>().map(
          (item) => Map<String, dynamic>.from(item),
        ));
    }
    final savedDays = _box.get('studyDays');
    if (savedDays is List) {
      _studyDays
        ..clear()
        ..addAll(savedDays.map((item) => item.toString()));
    }
  }

  Future<void> setProfile(StudentProfile value) async {
    profile = value;
    await _box.put('profile', value.toMap());
    notifyListeners();
  }

  Future<void> updateProfile(StudentProfile value) => setProfile(value);

  Future<void> logout() async {
    profile = null;
    await _box.delete('profile');
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    isDarkMode = value;
    await _box.put('darkMode', value);
    notifyListeners();
  }

  Future<void> setLanguage(bool sinhala) async {
    isSinhala = sinhala;
    await _box.put('isSinhala', sinhala);
    notifyListeners();
  }

  Future<void> setNotifications(bool value) async {
    notificationsEnabled = value;
    await _box.put('notificationsEnabled', value);
    notifyListeners();
  }

  Future<void> setBackendUrl(String value) async {
    backendUrl = value.trim().replaceFirst(RegExp(r'/+$'), '');
    await _box.put('backendUrl', backendUrl);
    notifyListeners();
  }

  List<ChatMessage> loadChat(String key) {
    final raw = _box.get('chat:$key');
    if (raw is! List) return [];
    return raw.whereType<Map>().map(ChatMessage.fromMap).toList();
  }

  Future<void> saveChat(String key, List<ChatMessage> messages) async {
    final limited = messages.length > 60
        ? messages.sublist(messages.length - 60)
        : messages;
    await _box.put('chat:$key', limited.map((item) => item.toMap()).toList());
    final uid = profile?.uid;
    if (uid != null) await FirebaseService.saveChat(uid, key, limited);
  }

  Future<void> recordStudySession() async {
    _studyDays.add(_dateKey(DateTime.now()));
    // Retain only the last 400 days on-device.
    if (_studyDays.length > 400) {
      final sorted = _studyDays.toList()..sort();
      _studyDays
        ..clear()
        ..addAll(sorted.skip(sorted.length - 400));
    }
    await _box.put('studyDays', _studyDays.toList());
    notifyListeners();
  }

  int get studyStreakDays {
    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    if (!_studyDays.contains(_dateKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (_studyDays.contains(_dateKey(cursor)) && streak < 400) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  void recordQuiz({required int score, required int total, required String subject}) {
    final result = {
      'score': score,
      'total': total,
      'subject': subject,
      'date': DateTime.now().toIso8601String(),
    };
    quizHistory.insert(0, result);
    if (quizHistory.length > 40) quizHistory.removeLast();
    _box.put('quizHistory', quizHistory);
    final uid = profile?.uid;
    if (uid != null) FirebaseService.saveQuizResult(uid, result);
    recordStudySession();
    notifyListeners();
  }

  Map<String, double> get quizPerformanceBySubject {
    final totals = <String, double>{};
    final counts = <String, int>{};
    for (final entry in quizHistory) {
      final subject = entry['subject']?.toString() ?? 'Quiz';
      final total = (entry['total'] as num?)?.toDouble() ?? 0;
      final score = (entry['score'] as num?)?.toDouble() ?? 0;
      if (total <= 0) continue;
      totals[subject] = (totals[subject] ?? 0) + score / total * 100;
      counts[subject] = (counts[subject] ?? 0) + 1;
    }
    return totals.map((subject, total) =>
        MapEntry(subject, total / (counts[subject] ?? 1)));
  }

  List<String> get weakSubjects => quizPerformanceBySubject.entries
      .where((entry) => entry.value < 60)
      .map((entry) => entry.key)
      .toList();

  double get averageQuizPercent {
    if (quizHistory.isEmpty) return 0;
    final results = quizHistory.where((item) => (item['total'] as num?)?.toDouble() != 0).toList();
    if (results.isEmpty) return 0;
    final sum = results.fold<double>(0, (value, item) {
      final total = (item['total'] as num?)?.toDouble() ?? 1;
      final score = (item['score'] as num?)?.toDouble() ?? 0;
      return value + (total == 0 ? 0 : score / total * 100);
    });
    return sum / results.length;
  }
}
