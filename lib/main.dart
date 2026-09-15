import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/home/home_screen.dart';
import 'state/settings_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait everywhere by default; the game screen opts into landscape while
  // it is on top and hands portrait back when it closes.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ProviderScope(child: PodWiseApp()));
}

class PodWiseApp extends ConsumerWidget {
  const PodWiseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Falls back to the default theme while settings load, so the first frame
    // is never unstyled.
    final settings = ref.watch(settingsProvider).valueOrNull;
    final theme = buildPodWiseTheme(
      settings?.theme ?? const AppSettings().theme,
    );

    // Re-applied on every build so the system bars follow the chosen theme.
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: PodWiseColors.surface,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return MaterialApp(
      title: 'PodWise',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const HomeScreen(),
    );
  }
}
