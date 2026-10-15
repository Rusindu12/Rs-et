import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/curriculum.dart';
import '../models/study_models.dart';
import '../providers/app_state.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  int _grade = 10;
  String _streamId = 'physical-science';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _createAccount({bool demo = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      String uid = 'local-${DateTime.now().millisecondsSinceEpoch}';
      String email = _email.text.trim();
      if (!demo) {
        if (!FirebaseService.isReady) {
          throw StateError('Firebase සකසා නැහැ. Demo mode එකෙන් ඉදිරියට යන්න.');
        }
        final credential = await FirebaseService.createAccount(email, _password.text);
        uid = credential.user?.uid ?? uid;
      }
      final profile = StudentProfile(
        uid: uid,
        name: _name.text.trim(),
        email: email,
        grade: _grade,
        streamId: _grade >= 12 ? _streamId : null,
      );
      await context.read<AppState>().setProfile(profile);
      await FirebaseService.saveProfile(profile);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSinhala = context.watch<AppState>().isSinhala;
    return Scaffold(
      appBar: AppBar(title: Text(isSinhala ? 'ගිණුමක් සාදන්න' : 'Create your account')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
                children: [
                  const EduCard(
                    color: Color(0xffF0EFFF),
                    child: Row(
                      children: [
                        MascotBadge(size: 54, color: EduColors.purple),
                        SizedBox(width: 14),
                        Expanded(child: Text('A little profile helps us build your grade-wise study plan.')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: isSinhala ? 'ඔබේ නම' : 'Your name', prefixIcon: const Icon(Icons.person_outline_rounded)),
                    validator: (value) => value == null || value.trim().isEmpty ? 'නම ඇතුළත් කරන්න' : null,
                  ),
                  const SizedBox(height: 13),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                    validator: (value) => value == null || !value.contains('@') ? 'නිවැරදි email එකක් ඇතුළත් කරන්න' : null,
                  ),
                  const SizedBox(height: 13),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: InputDecoration(labelText: isSinhala ? 'මුරපදය (අවම අකුරු 6)' : 'Password (at least 6 characters)', prefixIcon: const Icon(Icons.lock_outline_rounded)),
                    validator: (value) => value == null || value.length < 6 ? 'මුරපදය අකුරු 6ක් හෝ වැඩි විය යුතුයි' : null,
                  ),
                  const SizedBox(height: 13),
                  DropdownButtonFormField<int>(
                    value: _grade,
                    decoration: InputDecoration(labelText: isSinhala ? 'ශ්‍රේණිය' : 'Grade', prefixIcon: const Icon(Icons.school_outlined)),
                    items: List.generate(13, (index) => index + 1)
                        .map((grade) => DropdownMenuItem(value: grade, child: Text('Grade $grade  ·  ${stageForGrade(grade, sinhala: isSinhala)}')))
                        .toList(),
                    onChanged: (value) => setState(() => _grade = value ?? 10),
                  ),
                  if (_grade >= 12) ...[
                    const SizedBox(height: 13),
                    DropdownButtonFormField<String>(
                      value: _streamId,
                      decoration: InputDecoration(labelText: isSinhala ? 'උසස් පෙළ විෂය ධාරාව' : 'A/L stream', prefixIcon: const Icon(Icons.auto_awesome_outlined)),
                      items: streamOptions
                          .map((stream) => DropdownMenuItem(value: stream.id, child: Text('${stream.icon}  ${stream.title(isSinhala)}')))
                          .toList(),
                      onChanged: (value) => setState(() => _streamId = value ?? _streamId),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _busy ? null : () => _createAccount(),
                    style: FilledButton.styleFrom(backgroundColor: EduColors.purple, padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _busy ? const CircularProgressIndicator(color: Colors.white) : Text(isSinhala ? 'ගිණුම සාදන්න' : 'Create account'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _createAccount(demo: true),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                    child: Text(isSinhala ? 'Demo profile එකක් සාදන්න' : 'Create a local demo profile'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Demo profile එක device එකේ පමණක් සුරැකේ. Cloud sync සඳහා Firebase Auth/Firestore සකසන්න.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: EduColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
