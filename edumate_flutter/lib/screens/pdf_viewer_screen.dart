import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

import '../theme/app_theme.dart';

class PdfViewerScreen extends StatelessWidget {
  const PdfViewerScreen({required this.filePath, required this.title, super.key});

  final String filePath;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title), actions: [const Padding(padding: EdgeInsets.only(right: 14), child: Icon(Icons.picture_as_pdf_rounded, color: EduColors.coral))]),
        body: PDFView(
          filePath: filePath,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          onError: (error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF කියවන්න බැරි වුණා: $error'))),
          onPageError: (page, error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Page $page: $error'))),
        ),
      );
}
