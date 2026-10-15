import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/curriculum.dart';
import '../data/app_strings.dart';
import '../models/study_models.dart';
import '../providers/app_state.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'progress_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editProfile(BuildContext context, AppState state) async {
    final profile = state.profile!;
    final nameController = TextEditingController(text: profile.name);
    var grade = profile.grade;
    var streamId = profile.streamId ?? 'physical-science';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(state.isSinhala ? 'පැතිකඩ සංස්කරණය' : 'Edit profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: InputDecoration(labelText: state.isSinhala ? 'නම' : 'Name')),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: grade,
                  decoration: InputDecoration(labelText: state.isSinhala ? 'ශ්‍රේණිය' : 'Grade'),
                  items: List.generate(13, (index) => index + 1).map((item) => DropdownMenuItem(value: item, child: Text('Grade $item'))).toList(),
                  onChanged: (value) => setDialogState(() => grade = value ?? grade),
                ),
                if (grade >= 12) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: streamId,
                    decoration: InputDecoration(labelText: state.isSinhala ? 'විෂය ධාරාව' : 'A/L stream'),
                    items: streamOptions.map((stream) => DropdownMenuItem(value: stream.id, child: Text(stream.title(state.isSinhala)))).toList(),
                    onChanged: (value) => setDialogState(() => streamId = value ?? streamId),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(state.isSinhala ? 'අවලංගු කරන්න' : 'Cancel')),
            FilledButton(
              onPressed: () async {
                final updated = StudentProfile(
                  uid: profile.uid,
                  name: nameController.text.trim().isEmpty ? profile.name : nameController.text.trim(),
                  email: profile.email,
                  grade: grade,
                  streamId: grade >= 12 ? streamId : null,
                );
                await state.updateProfile(updated);
                await FirebaseService.saveProfile(updated);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: Text(state.isSinhala ? 'සුරකින්න' : 'Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
  }

  Future<void> _editBackendUrl(BuildContext context, AppState state) async {
    final controller = TextEditingController(text: state.backendUrl);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(state.isSinhala ? 'AI server සම්බන්ධතාවය' : 'AI server connection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(state.isSinhala ? 'EduMate FastAPI public URL එක ඇතුළත් කරන්න. AI API key එකක් app එකට දාන්න අවශ්‍ය නැහැ.' : 'Enter your EduMate FastAPI base URL. Never put an AI provider key in the mobile app.', style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5)),
            const SizedBox(height: 13),
            TextField(controller: controller, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'https://your-api.onrender.com', prefixIcon: Icon(Icons.link_rounded))),
            const SizedBox(height: 8),
            Text('Emulator: http://10.0.2.2:8000 · Phone: use your computer LAN IP or deployed HTTPS URL.', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: EduColors.muted, height: 1.4)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(state.isSinhala ? 'අවලංගු කරන්න' : 'Cancel')),
          FilledButton(
            onPressed: () async {
              await state.setBackendUrl(controller.text);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: Text(state.isSinhala ? 'සුරකින්න' : 'Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _logout(BuildContext context, AppState state) async {
    await FirebaseService.signOut();
    await state.logout();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile!;
    final strings = AppStrings(state.isSinhala);
    final stream = streamName(profile.streamId, sinhala: state.isSinhala);
    return Scaffold(
      appBar: AppBar(title: Text(strings.profile)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 26),
        children: [
          GradientPanel(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.3))), child: Center(child: Text(profile.name.isEmpty ? 'S' : profile.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 27)))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(profile.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(profile.email.isEmpty ? 'Local demo profile' : profile.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)), const SizedBox(height: 7), Text('Grade ${profile.grade}${stream.isEmpty ? '' : ' · $stream'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))])),
                  IconButton(onPressed: () => _editProfile(context, state), color: Colors.white, icon: const Icon(Icons.edit_outlined)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 17),
          EduCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _SettingsRow(icon: Icons.insights_rounded, title: state.isSinhala ? 'ඉගෙනුම් ප්‍රගතිය' : 'Learning progress', subtitle: state.isSinhala ? 'ලකුණු සහ දුර්වල පාඩම්' : 'Scores and study insights', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProgressScreen()))),
              const Divider(height: 1, indent: 54),
              _SettingsRow(icon: Icons.edit_note_rounded, title: state.isSinhala ? 'පැතිකඩ සංස්කරණය' : 'Edit student profile', onTap: () => _editProfile(context, state)),
              const Divider(height: 1, indent: 54),
              _SettingsRow(icon: Icons.cloud_outlined, title: state.isSinhala ? 'AI backend URL' : 'AI backend URL', subtitle: state.backendUrl, onTap: () => _editBackendUrl(context, state)),
            ]),
          ),
          const SizedBox(height: 16),
          Text(strings.settings, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          EduCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              SwitchListTile.adaptive(
                value: state.isDarkMode,
                onChanged: state.setDarkMode,
                secondary: const Icon(Icons.dark_mode_outlined, color: EduColors.purple),
                title: Text(state.isSinhala ? 'Dark mode' : 'Dark mode', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const Divider(height: 1, indent: 54),
              SwitchListTile.adaptive(
                value: state.isSinhala,
                onChanged: state.setLanguage,
                secondary: const Icon(Icons.language_rounded, color: EduColors.purple),
                title: Text(state.isSinhala ? 'භාෂාව · සිංහල' : 'Language · English', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(state.isSinhala ? 'English වෙත මාරු වීමට on කරන්න' : 'Switch back to Sinhala', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: EduColors.muted)),
              ),
              const Divider(height: 1, indent: 54),
              SwitchListTile.adaptive(
                value: state.notificationsEnabled,
                onChanged: state.setNotifications,
                secondary: const Icon(Icons.notifications_none_rounded, color: EduColors.purple),
                title: Text(state.isSinhala ? 'දැනුම්දීම්' : 'Notifications', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          EduCard(
            color: const Color(0xffEEF7FF),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.shield_outlined, color: Color(0xff438FE3)), const SizedBox(width: 10), Expanded(child: Text(FirebaseService.isReady ? 'Firebase connected · Your study data sync is enabled.' : 'Local demo mode · data stays on this device until Firebase is configured.', style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5)))]),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _logout(context, state),
            icon: const Icon(Icons.logout_rounded, color: EduColors.coral),
            label: Text(state.isSinhala ? 'ඉවත් වෙන්න' : 'Log out', style: const TextStyle(color: EduColors.coral, fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), side: BorderSide(color: EduColors.coral.withValues(alpha: 0.35)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          ),
          const SizedBox(height: 12),
          Center(child: Text('EduMate AI · Study better, together 💜', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: EduColors.muted))),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.icon, required this.title, this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: EduColors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 20, color: EduColors.purple)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: EduColors.muted)),
        trailing: const Icon(Icons.chevron_right_rounded),
      );
}
