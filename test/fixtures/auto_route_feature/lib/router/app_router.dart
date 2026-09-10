import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';

@AutoRoute()
class AppRouter {}

final routes = [
  AutoRoute(
    path: '/home',
    page: HomeRoute.page,
  ),
];

@RoutePage()
class HomeRoute extends StatelessWidget {
  const HomeRoute({super.key});

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
