import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'attendance_provider.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: Text(provider.attendance?.status ?? 'Loading'),
    );
  }
}
