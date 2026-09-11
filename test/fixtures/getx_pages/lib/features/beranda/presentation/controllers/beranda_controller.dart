import 'package:get/get.dart';

import '../../data/repositories/beranda_repository.dart';

class BerandaController extends GetxController {
  BerandaController({BerandaRepository? repository})
      : _repository = repository ?? BerandaRepository();

  final BerandaRepository _repository;
  final title = ' Beranda'.obs;

  Future<void> load() async {
    title.value = await _repository.fetchTitle();
  }
}
