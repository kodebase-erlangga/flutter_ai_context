import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'legacy_home_provider.dart';

class LegacyHomeScreen extends StatelessWidget {
  const LegacyHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final title = context.watch<LegacyHomeProvider>().title;
    return Scaffold(body: Text(title));
  }
}
