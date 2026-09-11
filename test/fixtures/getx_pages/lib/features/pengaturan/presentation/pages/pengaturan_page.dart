import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/pengaturan_controller.dart';

class PengaturanPage extends StatelessWidget {
  const PengaturanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PengaturanController());
    return Scaffold(
      body: Obx(() => Text(controller.title.value)),
    );
  }
}
