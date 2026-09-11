import 'package:get/get.dart';

import '../../data/repositories/pengaturan_repository.dart';

class PengaturanController extends GetxController {
  PengaturanController({PengaturanRepository? repository})
      : _repository = repository ?? PengaturanRepository();

  final PengaturanRepository _repository;
  final title = ' Pengaturan'.obs;

  Future<void> load() async {
    title.value = await _repository.fetchTitle();
  }
}
