import 'package:get/get.dart';

import '../../data/repositories/nilai_repository.dart';

class NilaiController extends GetxController {
  NilaiController({NilaiRepository? repository})
      : _repository = repository ?? NilaiRepository();

  final NilaiRepository _repository;
  final title = ' Nilai'.obs;

  Future<void> load() async {
    title.value = await _repository.fetchTitle();
  }
}
