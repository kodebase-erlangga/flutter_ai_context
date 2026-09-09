import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/settings/settings_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
