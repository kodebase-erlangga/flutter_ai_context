import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/jadwal_controller.dart';

class JadwalPage extends StatelessWidget {
  const JadwalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(JadwalController());
    return Scaffold(
      body: Obx(() => Text(controller.title.value)),
    );
  }
}
