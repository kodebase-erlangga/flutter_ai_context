import 'package:get/get.dart';

import '../../data/repositories/jadwal_repository.dart';

class JadwalController extends GetxController {
  JadwalController({JadwalRepository? repository})
      : _repository = repository ?? JadwalRepository();

  final JadwalRepository _repository;
  final title = ' Jadwal'.obs;

  Future<void> load() async {
    title.value = await _repository.fetchTitle();
  }
}
