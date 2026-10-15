import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

import '../data/curriculum.dart';
import '../models/study_models.dart';
import '../providers/app_state.dart';
import '../services/ai_service.dart';
import '../services/firebase_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'pdf_viewer_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.studyContext, this.embedded = false});

  final StudyContext? studyContext;
  final bool embedded;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  final _speech = stt.SpeechToText();
  final _tts = FlutterTts();
  final List<ChatMessage> _messages = [];
  bool _sending = false;
  bool _listening = false;
  bool _scanning = false;
  bool _serverOnline = false;

  StudyContext _contextFor(AppState state) => widget.studyContext ?? StudyContext(
        grade: state.profile?.grade ?? 10,
        streamId: state.profile?.streamId,
        subjectId: 'general',
        subjectName: state.isSinhala ? 'සාමාන්‍ය අධ්‍යයනය' : 'General study',
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreChat());
  }

  Future<void> _restoreChat() async {
    if (!mounted) return;
    final state = context.read<AppState>();
    final studyContext = _contextFor(state);
    var saved = state.loadChat(studyContext.storageKey);
    if (saved.isEmpty && state.profile != null) {
      saved = await FirebaseService.loadChat(state.profile!.uid, studyContext.storageKey);
      if (saved.isNotEmpty) await state.saveChat(studyContext.storageKey, saved);
    }
    final online = await AiService.checkHealth(state.backendUrl);
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(saved);
      _serverOnline = online;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  Future<void> _send({String? textOverride}) async {
    final state = context.read<AppState>();
    final messageText = (textOverride ?? _controller.text).trim();
    if (messageText.isEmpty || _sending) return;
    _controller.clear();
    final studyContext = _contextFor(state);
    setState(() {
      _sending = true;
      _messages.add(ChatMessage(isUser: true, text: messageText, createdAt: DateTime.now()));
    });
    await state.recordStudySession();
    await state.saveChat(studyContext.storageKey, _messages);
    _scrollToBottom();
    try {
      final result = await AiService.ask(
        baseUrl: state.backendUrl,
        message: messageText,
        studyContext: studyContext,
        history: _messages.take(_messages.length - 1).toList(),
      );
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          isUser: false,
          text: result.text,
          createdAt: DateTime.now(),
          sources: result.sources,
          isPreview: result.isPreview,
        ));
        _sending = false;
        _serverOnline = !result.isPreview;
      });
      await state.saveChat(studyContext.storageKey, _messages);
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _serverOnline = false;
        _messages.add(ChatMessage(
          isUser: false,
          text: 'සම්බන්ධතාවය තාවකාලිකව නැති වුණා. Notes සහ downloaded content offline භාවිතා කළ හැකියි.',
          createdAt: DateTime.now(),
          isPreview: true,
        ));
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final available = await _speech.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && mounted) {
          setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!available) {
      if (mounted) _showToast('Voice input ලබාගත නොහැකි байна. Keyboard එක භාවිතා කරන්න.');
      return;
    }
    if (mounted) setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        _controller.text = result.recognizedWords;
        _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
        if (result.finalResult && mounted) setState(() => _listening = false);
      },
      listenFor: const Duration(seconds: 35),
      pauseFor: const Duration(seconds: 4),
    );
  }

  Future<void> _scanHomework() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: const Icon(Icons.camera_alt_rounded, color: EduColors.purple), title: const Text('Take a photo'), onTap: () => Navigator.pop(context, ImageSource.camera)),
              ListTile(leading: const Icon(Icons.photo_library_rounded, color: EduColors.purple), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
              Text('On-device OCR extracts printed text. Sinhala-script recognition may vary by device/model.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: EduColors.muted)),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    try {
      final image = await _imagePicker.pickImage(source: source, imageQuality: 85);
      if (image == null) return;
      setState(() => _scanning = true);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognized = await recognizer.processImage(InputImage.fromFilePath(image.path));
      await recognizer.close();
      if (!mounted) return;
      setState(() => _scanning = false);
      if (recognized.text.trim().isEmpty) {
        _showToast('Text හඳුනාගත නොහැකි වුණා. පැහැදිලි photo එකක් උත්සාහ කරන්න.');
        return;
      }
      await _send(textOverride: 'මෙම ගෙදර වැඩ ප්‍රශ්නය විසඳා, පියවරෙන් පියවර පැහැදිලි කරන්න:\n\n${recognized.text}');
    } catch (error) {
      if (!mounted) return;
      setState(() => _scanning = false);
      _showToast('Image එක scan කරන්න බැරි වුණා: $error');
    }
  }

  Future<void> _speak(String text) async {
    final state = context.read<AppState>();
    try {
      await _tts.setLanguage(state.isSinhala ? 'si-LK' : 'en-US');
      await _tts.setSpeechRate(0.46);
      await _tts.speak(text);
    } catch (_) {
      _showToast('මෙම device එකේ තෝරාගත් voice එක නොමැත.');
    }
  }

  Future<void> _exportConversation() async {
    final state = context.read<AppState>();
    if (_messages.isEmpty) {
      _showToast('Export කිරීමට chat එකක් නැහැ.');
      return;
    }
    try {
      final file = await PdfService.export(
        baseUrl: state.backendUrl,
        endpoint: '/api/export/chat.pdf',
        payload: {
          'title': 'EduMate AI study chat',
          'messages': _messages.map((item) => {'role': item.isUser ? 'user' : 'assistant', 'content': item.text}).toList(),
          'context': _contextFor(state).toMap(),
        },
        fileName: 'edumate-chat.pdf',
      );
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PdfViewerScreen(filePath: file.path, title: 'Chat export')));
    } catch (error) {
      if (mounted) _showToast('PDF export අසාර්ථකයි: $error');
    }
  }

  void _showToast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final studyContext = _contextFor(state);
    final body = Column(
      children: [
        if (!_serverOnline)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: const Color(0xffFFF6E8), borderRadius: BorderRadius.circular(13)),
            child: Row(children: [const Icon(Icons.cloud_off_rounded, size: 17, color: Color(0xffD7952E)), const SizedBox(width: 8), Expanded(child: Text(state.isSinhala ? 'Offline preview · පාඩම් සටහන් සහ quiz තවම භාවිතා කළ හැකියි' : 'Offline preview · notes and quizzes are still available', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xff8D6728)))), IconButton(visualDensity: VisualDensity.compact, onPressed: () async { final online = await AiService.checkHealth(state.backendUrl); if (mounted) setState(() => _serverOnline = online); }, icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xff8D6728)))]),
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 3, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: EduColors.purple.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [const Icon(Icons.school_outlined, color: EduColors.purple, size: 18), const SizedBox(width: 8), Expanded(child: Text('Grade ${studyContext.grade} · ${studyContext.subjectName}${studyContext.chapterName == null ? '' : ' · ${studyContext.chapterName}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: EduColors.purple)))]),
        ),
        Expanded(
          child: _messages.isEmpty
              ? _EmptyChat(isSinhala: state.isSinhala, onSuggestion: (value) => _send(textOverride: value), scanning: _scanning)
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  itemCount: _messages.length + (_sending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_sending && index == _messages.length) return const _TypingIndicator();
                    return _MessageBubble(message: _messages[index], onSpeak: _speak);
                  },
                ),
        ),
        _Composer(
          controller: _controller,
          sending: _sending,
          listening: _listening,
          scanning: _scanning,
          onSend: () => _send(),
          onListen: _toggleListening,
          onScan: _scanHomework,
        ),
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [const MascotBadge(size: 38, color: EduColors.purple), const SizedBox(width: 9), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(state.isSinhala ? 'AI අධ්‍යයන සහායක' : 'AI study buddy', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)), Text(_serverOnline ? 'Connected to EduMate API' : 'Ready for offline study', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: _serverOnline ? EduColors.green : EduColors.muted))])]),
        actions: [IconButton(tooltip: 'Export chat PDF', onPressed: _exportConversation, icon: const Icon(Icons.picture_as_pdf_outlined)), const SizedBox(width: 7)],
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.isSinhala, required this.onSuggestion, required this.scanning});

  final bool isSinhala;
  final ValueChanged<String> onSuggestion;
  final bool scanning;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(duration: const Duration(milliseconds: 250), width: 92, height: 92, decoration: BoxDecoration(color: EduColors.purple.withValues(alpha: 0.1), shape: BoxShape.circle), child: scanning ? const Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator(strokeWidth: 3)) : const Icon(Icons.smart_toy_rounded, color: EduColors.purple, size: 48)),
              const SizedBox(height: 15),
              Text(scanning ? (isSinhala ? 'ප්‍රශ්නය කියවමින්…' : 'Reading your question…') : (isSinhala ? 'අද ඉගෙනගන්න කැමති මොනවාද?' : 'What would you like to learn today?'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Text(isSinhala ? 'ඔබේ ශ්‍රේණිය සහ පාඩමට ගැළපෙන ප්‍රශ්නයක් අහන්න.' : 'Ask a question matched to your grade and current lesson.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: EduColors.muted, height: 1.5)),
              const SizedBox(height: 19),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _SuggestionChip(label: isSinhala ? 'මෙම අදහස උදාහරණයකින් කියන්න' : 'Explain this with an example', onTap: () => onSuggestion(isSinhala ? 'මෙම පාඩමේ ප්‍රධාන අදහස සරල උදාහරණයකින් පැහැදිලි කරන්න.' : 'Explain the main idea of this lesson with a simple example.')),
                  _SuggestionChip(label: isSinhala ? 'මට ප්‍රශ්නයක් දෙන්න' : 'Give me a practice question', onTap: () => onSuggestion(isSinhala ? 'මෙම පාඩම ගැන පුහුණු ප්‍රශ්නයක් දෙන්න.' : 'Give me one practice question about this lesson.')),
                  _SuggestionChip(label: isSinhala ? 'පියවරෙන් පියවර විසඳන්න' : 'Solve step by step', onTap: () => onSuggestion(isSinhala ? 'මෙම ගැටලුව පියවරෙන් පියවර විසඳා දෙන්න.' : 'Solve this problem step by step.')),
                ],
              ),
            ],
          ),
        ),
      );
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
        onPressed: onTap,
        backgroundColor: Colors.white,
        side: BorderSide(color: EduColors.purple.withValues(alpha: 0.13)),
        label: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: EduColors.purple, fontWeight: FontWeight.w700)),
      );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onSpeak});

  final ChatMessage message;
  final ValueChanged<String> onSpeak;

  @override
  Widget build(BuildContext context) {
    final user = message.isUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.84),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: Column(
            crossAxisAlignment: user ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
                decoration: BoxDecoration(
                  color: user ? EduColors.purple : Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.only(topLeft: const Radius.circular(19), topRight: const Radius.circular(19), bottomLeft: Radius.circular(user ? 19 : 5), bottomRight: Radius.circular(user ? 5 : 19)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.035), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.isPreview) Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('PREVIEW / OFFLINE', style: TextStyle(color: user ? Colors.white70 : EduColors.muted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.6))),
                    Text(message.text, style: TextStyle(color: user ? Colors.white : Theme.of(context).colorScheme.onSurface, height: 1.5, fontSize: 14)),
                    if (!user && message.sources.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Text('Sources', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, color: EduColors.purple)),
                      ...message.sources.map((source) => InkWell(
                            onTap: source['url'] == null || source['url']!.isEmpty ? null : () => launchUrl(Uri.parse(source['url']!), mode: LaunchMode.externalApplication),
                            child: Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [const Icon(Icons.link_rounded, size: 15, color: EduColors.purple), const SizedBox(width: 5), Expanded(child: Text(source['title'] ?? 'Source', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: EduColors.purple, decoration: TextDecoration.underline)))])),
                          )),
                    ],
                  ],
                ),
              ),
              if (!user)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Text(TimeOfDay.fromDateTime(message.createdAt).format(context), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: EduColors.muted, fontSize: 10)), IconButton(visualDensity: VisualDensity.compact, constraints: const BoxConstraints(minWidth: 32, minHeight: 30), onPressed: () => onSpeak(message.text), icon: const Icon(Icons.volume_up_outlined, size: 17, color: EduColors.muted))]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(18)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 10), Text('EduMate is thinking…')]),
        ),
      );
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.listening, required this.scanning, required this.onSend, required this.onListen, required this.onScan});

  final TextEditingController controller;
  final bool sending;
  final bool listening;
  final bool scanning;
  final VoidCallback onSend;
  final VoidCallback onListen;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton.filledTonal(tooltip: 'Scan homework', onPressed: scanning ? null : onScan, icon: scanning ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.document_scanner_outlined, size: 20)),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(hintText: 'ප්‍රශ්නයක් අහන්න… / Ask a question', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 13)),
                ),
              ),
              const SizedBox(width: 5),
              IconButton(tooltip: listening ? 'Stop voice input' : 'Voice input', onPressed: onListen, icon: Icon(listening ? Icons.stop_circle_rounded : Icons.mic_none_rounded, color: listening ? EduColors.coral : EduColors.purple)),
              IconButton.filled(tooltip: 'Send', onPressed: sending ? null : onSend, icon: const Icon(Icons.arrow_upward_rounded), style: IconButton.styleFrom(backgroundColor: EduColors.purple, foregroundColor: Colors.white)),
            ],
          ),
        ),
      );
}
