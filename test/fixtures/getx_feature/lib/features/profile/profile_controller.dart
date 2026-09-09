import 'package:get/get.dart';

class ProfileController extends GetxController {
  final name = 'Guest'.obs;

  void updateName(String value) => name.value = value;
}
