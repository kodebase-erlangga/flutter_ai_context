import 'package:get/get.dart';

import '../../data/repositories/materi_repository.dart';

class MateriController extends GetxController {
  MateriController({MateriRepository? repository})
      : _repository = repository ?? MateriRepository();

  final MateriRepository _repository;
  final title = ' Materi'.obs;

  Future<void> load() async {
    title.value = await _repository.fetchTitle();
  }
}
