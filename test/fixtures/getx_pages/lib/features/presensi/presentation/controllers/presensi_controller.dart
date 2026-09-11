import 'package:get/get.dart';

import '../../data/repositories/presensi_repository.dart';

class PresensiController extends GetxController {
  PresensiController({PresensiRepository? repository})
      : _repository = repository ?? PresensiRepository();

  final PresensiRepository _repository;
  final title = ' Presensi'.obs;

  Future<void> load() async {
    title.value = await _repository.fetchTitle();
  }
}
