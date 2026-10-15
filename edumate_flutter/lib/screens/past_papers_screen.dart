import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/study_models.dart';
import '../providers/app_state.dart';
import '../services/paper_repository.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'pdf_viewer_screen.dart';

class PastPapersScreen extends StatefulWidget {
  const PastPapersScreen({required this.grade, required this.subject, super.key, this.embedded = false});

  final int grade;
  final Subject subject;
  final bool embedded;

  @override
  State<PastPapersScreen> createState() => _PastPapersScreenState();
}

class _PastPapersScreenState extends State<PastPapersScreen> {
  bool _markingScheme = false;
  int _selectedYear = 0;
  late Future<List<PastPaper>> _papers;

  @override
  void initState() {
    super.initState();
    _papers = _load();
  }

  Future<List<PastPaper>> _load() => PaperRepository.load(
        grade: widget.grade,
        subject: widget.subject,
        markingScheme: _markingScheme,
      );

  void _changeType(bool markingScheme) {
    setState(() {
      _markingScheme = markingScheme;
      _papers = _load();
    });
  }

  Future<void> _openPaper(PastPaper paper) async {
    final url = paper.pdfUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('මෙම පත්‍රයට PDF එකක් තවම upload කර නැහැ. Firestore/Storage link එකක් එක් කරන්න.')),
      );
      return;
    }
    try {
      final file = await PdfService.download(
        url: url,
        fileName: 'grade-${widget.grade}-${widget.subject.id}-${paper.year}-${paper.markingScheme ? 'scheme' : 'paper'}.pdf',
      );
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PdfViewerScreen(filePath: file.path, title: paper.title)));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF download අසාර්ථකයි: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSinhala = context.watch<AppState>().isSinhala;
    final years = List<int>.generate(6, (index) => DateTime.now().year - index);
    final body = ListView(
      padding: EdgeInsets.fromLTRB(20, widget.embedded ? 16 : 8, 20, 26),
      children: [
        EduCard(
          color: const Color(0xffFFF0F0),
          child: Row(
            children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: EduColors.coral.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.picture_as_pdf_rounded, color: EduColors.coral)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Grade ${widget.grade} · ${widget.subject.title(isSinhala)}', style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(isSinhala ? 'විභාගයට පුහුණු වීමට පත්‍ර තෝරන්න' : 'Practice with papers and marking schemes', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: EduColors.muted))])),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(15)),
          child: Row(children: [Expanded(child: _TypeButton(label: isSinhala ? 'ප්‍රශ්න පත්‍ර' : 'Question papers', selected: !_markingScheme, onTap: () => _changeType(false))), Expanded(child: _TypeButton(label: isSinhala ? 'ලකුණු දීමේ පටිපාටි' : 'Marking schemes', selected: _markingScheme, onTap: () => _changeType(true)))]),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _YearChip(label: isSinhala ? 'සියලු වසර' : 'All years', selected: _selectedYear == 0, onTap: () => setState(() => _selectedYear = 0)),
              ...years.map((year) => _YearChip(label: '$year', selected: _selectedYear == year, onTap: () => setState(() => _selectedYear = year))),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<PastPaper>>(
          future: _papers,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()));
            final loaded = snapshot.data ?? const <PastPaper>[];
            final papers = loaded.isNotEmpty
                ? loaded.where((paper) => _selectedYear == 0 || paper.year == _selectedYear).toList()
                : years.where((year) => _selectedYear == 0 || year == _selectedYear).map((year) => PastPaper(id: 'sample-$year', year: year, title: '${widget.subject.nameEn} · $year ${_markingScheme ? 'Marking Scheme' : 'Past Paper'}', markingScheme: _markingScheme)).toList();
            if (papers.isEmpty) {
              return EduCard(child: Text(isSinhala ? 'මේ වසර සඳහා පත්‍රයක් හමු වුණේ නැහැ.' : 'No papers found for this year.'));
            }
            return Column(
              children: papers.map((paper) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: EduCard(
                      onTap: () => _openPaper(paper),
                      child: Row(
                        children: [
                          Container(width: 43, height: 49, decoration: BoxDecoration(color: const Color(0xffFFF0F0), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.description_rounded, color: EduColors.coral)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(paper.title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(paper.pdfUrl == null ? (isSinhala ? 'PDF link එක සකසන්න' : 'PDF link not configured') : '${paper.year} · PDF', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: EduColors.muted))])),
                          IconButton(tooltip: isSinhala ? 'බාගන්න / බලන්න' : 'Download / view', onPressed: () => _openPaper(paper), icon: const Icon(Icons.download_rounded, color: EduColors.purple)),
                        ],
                      ),
                    ),
                  )).toList(),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(isSinhala ? 'සටහන: පත්‍ර PDF ගොනු Firebase Storage වෙත upload කර Firestore document එකට pdfUrl එක් කරන්න.' : 'To publish a paper, upload its PDF to Firebase Storage and add its download URL to the paper document.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: EduColors.muted, height: 1.45)),
      ],
    );
    if (widget.embedded) return Scaffold(body: body);
    return Scaffold(appBar: AppBar(title: Text(isSinhala ? 'පසුගිය ප්‍රශ්න පත්‍ර' : 'Past papers')), body: body);
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(color: selected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(12), boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)] : null),
          child: Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, color: selected ? EduColors.purple : EduColors.muted)),
        ),
      );
}

class _YearChip extends StatelessWidget {
  const _YearChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap(), selectedColor: EduColors.purple.withValues(alpha: 0.13), labelStyle: TextStyle(color: selected ? EduColors.purple : EduColors.muted, fontWeight: FontWeight.w700)),
      );
}
