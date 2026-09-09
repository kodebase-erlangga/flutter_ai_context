import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dio = Dio();
    return Scaffold(body: Text(dio.toString()));
  }
}
