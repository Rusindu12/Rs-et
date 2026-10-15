import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'screens/app_gate.dart';
import 'services/firebase_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final box = await Hive.openBox<dynamic>('edumate_local');
  await FirebaseService.initialize();
  final appState = AppState(box);
  await appState.restore();
  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const EduMateApp(),
    ),
  );
}

class EduMateApp extends StatelessWidget {
  const EduMateApp({super.key});

  @override
  Widget build(BuildContext context) => Consumer<AppState>(
        builder: (context, appState, _) => MaterialApp(
          title: 'EduMate AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const AppGate(),
        ),
      );
}
