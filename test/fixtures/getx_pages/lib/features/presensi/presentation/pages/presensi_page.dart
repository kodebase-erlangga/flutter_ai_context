import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/presensi_controller.dart';

class PresensiPage extends StatelessWidget {
  const PresensiPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PresensiController());
    return Scaffold(
      body: Obx(() => Text(controller.title.value)),
    );
  }
}
