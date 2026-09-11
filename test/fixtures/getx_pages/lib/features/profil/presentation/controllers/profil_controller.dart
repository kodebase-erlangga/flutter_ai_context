import 'package:get/get.dart';

import '../../data/repositories/profil_repository.dart';

class ProfilController extends GetxController {
  ProfilController({ProfilRepository? repository})
      : _repository = repository ?? ProfilRepository();

  final ProfilRepository _repository;
  final title = ' Profil'.obs;

  Future<void> load() async {
    title.value = await _repository.fetchTitle();
  }
}
