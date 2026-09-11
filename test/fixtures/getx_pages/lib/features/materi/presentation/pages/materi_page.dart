import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/materi_controller.dart';

class MateriPage extends StatelessWidget {
  const MateriPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MateriController());
    return Scaffold(
      body: Obx(() => Text(controller.title.value)),
    );
  }
}
