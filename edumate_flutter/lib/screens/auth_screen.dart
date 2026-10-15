import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/study_models.dart';
import '../providers/app_state.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'signup_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    if (!FirebaseService.isReady) {
      _showMessage('Firebase තවම සකසා නැහැ. Demo mode එකෙන් ඇතුළු වෙන්න.');
      return;
    }
    setState(() => _busy = true);
    try {
      final credential = await FirebaseService.signInWithEmail(
        _email.text,
        _password.text,
      );
      final user = credential.user;
      if (user == null) throw StateError('User account එක හමු වුණේ නැහැ.');
      final saved = await FirebaseService.loadProfile(user.uid);
      final profile = saved ?? StudentProfile(
        uid: user.uid,
        name: user.displayName ?? user.email?.split('@').first ?? 'Student',
        email: user.email ?? _email.text.trim(),
        grade: 10,
      );
      await context.read<AppState>().setProfile(profile);
    } catch (error) {
      _showMessage('Sign in අසාර්ථකයි: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _googleSignIn() async {
    if (!FirebaseService.isReady) {
      _showMessage('Google sign-in සඳහා Firebase project එක සම්බන්ධ කරන්න.');
      return;
    }
    setState(() => _busy = true);
    try {
      final credential = await FirebaseService.signInWithGoogle();
      final user = credential?.user;
      if (user != null) {
        await context.read<AppState>().setProfile(StudentProfile(
              uid: user.uid,
              name: user.displayName ?? 'Student',
              email: user.email ?? '',
              grade: 10,
            ));
      }
    } catch (error) {
      _showMessage('Google sign-in අසාර්ථකයි: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueDemo() async {
    await context.read<AppState>().setProfile(const StudentProfile(
      uid: 'local-demo-student',
      name: 'Nadeesha',
      email: 'demo@edumate.lk',
      grade: 10,
    ));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isSinhala = state.isSinhala;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const MascotBadge(size: 58, color: EduColors.purple),
                      const SizedBox(width: 13),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('EduMate AI', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                          Text('Learn with confidence', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: EduColors.muted)),
                        ],
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => state.setLanguage(!state.isSinhala),
                        child: Text(isSinhala ? 'EN' : 'සිං'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  Text(
                    isSinhala ? 'ආයුබෝවන් 👋' : 'Hello there 👋',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isSinhala
                        ? 'ඔබේ ඉගෙනුම් ගමනට නැවත එක්වන්න.'
                        : 'Sign in and pick up where you left off.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: EduColors.muted),
                  ),
                  const SizedBox(height: 26),
                  EduCard(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                            validator: (value) => value == null || !value.contains('@')
                                ? 'නිවැරදි email එකක් ඇතුළත් කරන්න'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: isSinhala ? 'මුරපදය' : 'Password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              ),
                            ),
                            validator: (value) => value == null || value.length < 6
                                ? 'මුරපදය අවම වශයෙන් අකුරු 6ක් විය යුතුයි'
                                : null,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _busy ? null : _signIn,
                              style: FilledButton.styleFrom(
                                backgroundColor: EduColors.purple,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _busy
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text(isSinhala ? 'ඇතුළු වෙන්න' : 'Sign in', style: const TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(isSinhala ? 'ගිණුමක් නැද්ද?' : 'New to EduMate?'),
                              TextButton(
                                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupScreen())),
                                child: Text(isSinhala ? 'ලියාපදිංචි වෙන්න' : 'Create account'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _googleSignIn,
                    icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                    label: Text(isSinhala ? 'Google සමඟ ඉදිරියට' : 'Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: const BorderSide(color: Color(0xffE7E7F0)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: EduColors.purple.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.tips_and_updates_outlined, color: EduColors.purple),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            FirebaseService.isReady
                                ? 'ඔබේ ගිණුමෙන් ඇතුළු වන්න, නැත්නම් demo mode එක අත්හදා බලන්න.'
                                : 'Demo mode සූදානම්. Firebase config එක නොමැතිව app එක explore කළ හැකියි.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _continueDemo,
                      icon: const Icon(Icons.explore_outlined),
                      label: Text(isSinhala ? 'Demo mode එකෙන් බලන්න' : 'Explore demo mode'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Grade 1–13  •  Sri Lankan syllabus  •  Sinhala + English',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: EduColors.muted),
                    ),
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
