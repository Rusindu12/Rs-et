import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class PdfService {
  static Future<File> download({
    required String url,
    required String fileName,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${directory.path}/$safeName');
    await Dio().download(url, file.path);
    return file;
  }

  static Future<File> export({
    required String baseUrl,
    required String endpoint,
    required Map<String, dynamic> payload,
    required String fileName,
  }) async {
    if (baseUrl.trim().isEmpty) {
      throw StateError('AI server URL එක Profile settings වල සකසන්න.');
    }
    final response = await Dio().post<List<int>>(
      '$baseUrl$endpoint',
      data: payload,
      options: Options(
        responseType: ResponseType.bytes,
        headers: const {'Accept': 'application/pdf'},
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) throw StateError('PDF එක හිස්ව ලැබුණා.');
    final directory = await getApplicationDocumentsDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${directory.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
