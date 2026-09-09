import 'package:flutter/foundation.dart';

class LegacyHomeProvider extends ChangeNotifier {
  String title = 'Legacy';

  void refresh() => notifyListeners();
}
