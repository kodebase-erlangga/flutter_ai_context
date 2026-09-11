import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/nilai_controller.dart';

class NilaiPage extends StatelessWidget {
  const NilaiPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NilaiController());
    return Scaffold(
      body: Obx(() => Text(controller.title.value)),
    );
  }
}
