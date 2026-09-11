import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/profil_controller.dart';

class ProfilPage extends StatelessWidget {
  const ProfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProfilController());
    return Scaffold(
      body: Obx(() => Text(controller.title.value)),
    );
  }
}
