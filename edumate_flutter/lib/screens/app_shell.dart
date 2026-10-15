import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_strings.dart';
import '../providers/app_state.dart';
import 'chat_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'quiz_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(context.watch<AppState>().isSinhala);
    final pages = <Widget>[
      HomeScreen(onSelectTab: (index) => setState(() => _selectedIndex = index)),
      const ChatScreen(),
      const LibraryScreen(),
      QuizScreen(active: _selectedIndex == 3),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: strings.home),
          NavigationDestination(icon: const Icon(Icons.auto_awesome_outlined), selectedIcon: const Icon(Icons.auto_awesome_rounded), label: strings.chat),
          NavigationDestination(icon: const Icon(Icons.menu_book_outlined), selectedIcon: const Icon(Icons.menu_book_rounded), label: strings.library),
          NavigationDestination(icon: const Icon(Icons.quiz_outlined), selectedIcon: const Icon(Icons.quiz_rounded), label: strings.quiz),
          NavigationDestination(icon: const Icon(Icons.person_outline_rounded), selectedIcon: const Icon(Icons.person_rounded), label: strings.profile),
        ],
      ),
    );
  }
}
