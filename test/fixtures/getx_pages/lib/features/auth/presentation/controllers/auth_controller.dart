import 'package:get/get.dart';

import '../../data/repositories/auth_repository.dart';

class AuthController extends GetxController {
  AuthController({AuthRepository? repository})
      : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;
  final title = ' Auth'.obs;

  Future<void> load() async {
    title.value = await _repository.fetchTitle();
  }
}
