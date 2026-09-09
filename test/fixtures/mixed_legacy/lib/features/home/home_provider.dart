import 'package:flutter/foundation.dart';

class HomeProvider extends ChangeNotifier {
  void refresh() => notifyListeners();
}
