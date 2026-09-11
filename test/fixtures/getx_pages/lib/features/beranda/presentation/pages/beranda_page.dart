import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/beranda_controller.dart';

class BerandaPage extends StatelessWidget {
  const BerandaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(BerandaController());
    return Scaffold(
      body: Obx(() => Text(controller.title.value)),
    );
  }
}
