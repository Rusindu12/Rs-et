import 'package:dio/dio.dart';

import '../models/study_models.dart';

class AiReply {
  const AiReply({
    required this.text,
    this.provider = 'EduMate AI',
    this.sources = const [],
    this.isPreview = false,
  });

  final String text;
  final String provider;
  final List<Map<String, String>> sources;
  final bool isPreview;
}

class AiService {
  static Dio _client(String baseUrl) => Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 20),
        headers: const {'Content-Type': 'application/json'},
      ));

  static Future<bool> checkHealth(String baseUrl) async {
    try {
      final response = await _client(baseUrl).get('/api/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<AiReply> ask({
    required String baseUrl,
    required String message,
    required StudyContext studyContext,
    required List<ChatMessage> history,
  }) async {
    if (baseUrl.trim().isEmpty) return _previewReply(studyContext);
    try {
      final response = await _client(baseUrl).post(
        '/api/chat',
        data: {
          'message': message,
          'context': studyContext.toMap(),
          'history': history
              .where((item) => !item.isPreview)
              .map((item) => {
                    'role': item.isUser ? 'user' : 'assistant',
                    'content': item.text,
                  })
              .toList(),
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final rawSources = data['sources'] as List? ?? const [];
      final sources = rawSources.whereType<Map>().map((item) => {
            'title': item['title']?.toString() ?? 'Source',
            'url': item['url']?.toString() ?? '',
          }).toList();
      final provider = data['provider']?.toString() ?? 'EduMate AI';
      return AiReply(
        text: data['reply']?.toString() ?? 'මට ඒකට පිළිතුරක් සකස් කරගන්න බැරි වුණා.',
        provider: provider,
        sources: sources,
        isPreview: provider == 'not_configured' || data['preview'] == true,
      );
    } catch (_) {
      return _previewReply(studyContext);
    }
  }

  static AiReply _previewReply(StudyContext studyContext) => AiReply(
        isPreview: true,
        provider: 'Offline preview',
        text: 'දැනට EduMate AI backend එක සම්බන්ධ වී නැහැ. '
            '${studyContext.subjectName} විෂයයේ '
            '${studyContext.chapterName ?? 'ඔබ තෝරාගත් පාඩම'} ගැන අහන්න පුළුවන් — '
            'සැබෑ AI පිළිතුරු ලබාගැනීමට Profile → AI server URL එකට ඔබේ FastAPI server URL එක දාන්න.\n\n'
            'මේ අතර, පාඩමේ Notes සහ Quiz offline ලෙස භාවිතා කරන්න පුළුවන්.',
      );
}
