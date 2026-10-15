import 'package:flutter/material.dart';

class StudentProfile {
  const StudentProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.grade,
    this.streamId,
  });

  final String uid;
  final String name;
  final String email;
  final int grade;
  final String? streamId;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'grade': grade,
        'streamId': streamId,
      };

  factory StudentProfile.fromMap(Map<dynamic, dynamic> map) => StudentProfile(
        uid: map['uid']?.toString() ?? 'local-student',
        name: map['name']?.toString() ?? 'Student',
        email: map['email']?.toString() ?? '',
        grade: (map['grade'] as num?)?.toInt() ?? 10,
        streamId: map['streamId']?.toString(),
      );

  StudentProfile copyWith({String? name, int? grade, String? streamId}) =>
      StudentProfile(
        uid: uid,
        name: name ?? this.name,
        email: email,
        grade: grade ?? this.grade,
        streamId: streamId ?? this.streamId,
      );
}

class Subject {
  const Subject({
    required this.id,
    required this.nameEn,
    required this.nameSi,
    required this.icon,
    required this.colorValue,
    this.shortEn,
    this.shortSi,
  });

  final String id;
  final String nameEn;
  final String nameSi;
  final String? shortEn;
  final String? shortSi;
  final IconData icon;
  final int colorValue;

  Color get color => Color(colorValue);
  String title(bool sinhala) => sinhala ? nameSi : nameEn;
  String get shortTitle => shortEn ?? nameEn;
}

class Chapter {
  const Chapter({
    required this.id,
    required this.titleEn,
    required this.titleSi,
    this.summaryEn = '',
    this.summarySi = '',
    this.progress = 0,
    this.notes = const [],
    this.videoUrl,
    this.notesPdfUrl,
  });

  final String id;
  final String titleEn;
  final String titleSi;
  final String summaryEn;
  final String summarySi;
  final double progress;
  final List<String> notes;
  final String? videoUrl;
  final String? notesPdfUrl;

  String title(bool sinhala) => sinhala ? titleSi : titleEn;
  String summary(bool sinhala) => sinhala ? summarySi : summaryEn;
}

class StreamOption {
  const StreamOption({
    required this.id,
    required this.nameEn,
    required this.nameSi,
    required this.icon,
    required this.colorValue,
  });

  final String id;
  final String nameEn;
  final String nameSi;
  final String icon;
  final int colorValue;

  Color get color => Color(colorValue);
  String title(bool sinhala) => sinhala ? nameSi : nameEn;
}

class StudyContext {
  const StudyContext({
    required this.grade,
    this.streamId,
    this.subjectId,
    this.subjectName = 'General study',
    this.chapterId,
    this.chapterName,
  });

  final int grade;
  final String? streamId;
  final String? subjectId;
  final String subjectName;
  final String? chapterId;
  final String? chapterName;

  String get storageKey =>
      'g$grade-${streamId ?? 'general'}-${subjectId ?? 'all'}-${chapterId ?? 'all'}';

  Map<String, dynamic> toMap() => {
        'grade': grade,
        'stream': streamId,
        'subjectId': subjectId,
        'subject': subjectName,
        'chapterId': chapterId,
        'chapter': chapterName,
      };
}

class ChatMessage {
  const ChatMessage({
    required this.isUser,
    required this.text,
    required this.createdAt,
    this.sources = const [],
    this.isPreview = false,
  });

  final bool isUser;
  final String text;
  final DateTime createdAt;
  final List<Map<String, String>> sources;
  final bool isPreview;

  Map<String, dynamic> toMap() => {
        'isUser': isUser,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'sources': sources,
        'isPreview': isPreview,
      };

  factory ChatMessage.fromMap(Map<dynamic, dynamic> map) => ChatMessage(
        isUser: map['isUser'] == true,
        text: map['text']?.toString() ?? '',
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        sources: (map['sources'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => item.map(
                  (key, value) => MapEntry(key.toString(), value.toString()),
                ))
            .toList(),
        isPreview: map['isPreview'] == true,
      );
}

class QuizQuestion {
  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
}
