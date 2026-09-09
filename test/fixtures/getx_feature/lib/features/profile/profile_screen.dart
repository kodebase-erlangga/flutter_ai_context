import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'profile_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProfileController());
    return Scaffold(
      body: Obx(() => Text(controller.name.value)),
    );
  }
}
