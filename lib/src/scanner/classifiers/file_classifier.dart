import '../../graph/node.dart';
import '../../graph/schema.dart';
import '../../inference/confidence.dart';

/// Classification result for a Dart file/class.
class ClassificationResult {
  ClassificationResult({
    required this.nodeType,
    required this.confidence,
    this.evidence = const [],
    this.featureHint,
    this.stateManagementFramework,
  });

  final NodeType nodeType;
  final double confidence;
  final List<Evidence> evidence;
  final String? featureHint;
  final String? stateManagementFramework;
}

/// Multi-signal file and class classifier.
class FileClassifier {
  ClassificationResult classifyClass({
    required String filePath,
    required String className,
    required String? superClass,
    required List<String> implementedTypes,
    required List<String> mixins,
    required bool hasBuildMethod,
    required List<String> methodNames,
    required List<String> imports,
    bool hasRiverpodAnnotation = false,
  }) {
    final evidence = <Evidence>[];
    var nodeType = NodeType.unknown;
    var featureHint = _extractFeatureHint(filePath, className);
    String? smFramework;

    if (_isScreen(className, superClass, hasBuildMethod, filePath, evidence)) {
      nodeType = NodeType.screen;
    } else if (_isGetxController(
      className,
      superClass,
      imports,
      filePath,
      evidence,
    )) {
      nodeType = NodeType.notifier;
      smFramework = 'getx';
    } else if (_isGetxBinding(className, superClass, filePath, imports, evidence)) {
      nodeType = NodeType.classNode;
      smFramework = 'getx';
    } else if (_isProvider(
      className,
      superClass,
      methodNames,
      filePath,
      evidence,
      imports: imports,
    )) {
      nodeType = NodeType.provider;
    } else if (_isBloc(className, superClass, imports, evidence)) {
      nodeType = NodeType.bloc;
    } else if (_isCubit(className, superClass, imports, evidence)) {
      nodeType = NodeType.cubit;
    } else if (_isRiverpodNotifier(
      className,
      superClass,
      imports,
      evidence,
      hasRiverpodAnnotation: hasRiverpodAnnotation,
    )) {
      nodeType = NodeType.notifier;
      smFramework = 'riverpod';
    } else if (_isService(className, filePath, evidence)) {
      nodeType = NodeType.service;
    } else if (_isRepository(className, filePath, evidence)) {
      nodeType = NodeType.repository;
    } else if (_isApiClient(className, filePath, evidence)) {
      nodeType = NodeType.apiClient;
    } else if (_isModel(className, filePath, methodNames, evidence)) {
      nodeType = NodeType.model;
    } else if (hasBuildMethod && (superClass?.contains('Widget') ?? false)) {
      nodeType = NodeType.widget;
      evidence.add(const Evidence(description: 'extends Widget with build()'));
    } else {
      nodeType = NodeType.classNode;
    }

    return ClassificationResult(
      nodeType: nodeType,
      confidence: ConfidenceEngine.fromEvidence(evidence, base: 0.6),
      evidence: evidence,
      featureHint: featureHint,
      stateManagementFramework: smFramework,
    );
  }

  String? _extractFeatureHint(String filePath, String className) {
    final featureMatch = RegExp(r'features/([^/]+)/').firstMatch(filePath);
    if (featureMatch != null) return _titleCase(featureMatch.group(1)!);

    final moduleMatch = RegExp(r'modules/([^/]+)/').firstMatch(filePath);
    if (moduleMatch != null) return _titleCase(moduleMatch.group(1)!);

    final baseName = className.replaceAll(
        RegExp(
            r'(Screen|Page|Provider|Controller|Service|Repository|Model|Bloc|Cubit|Notifier)$'),
        '');
    if (baseName.isNotEmpty && baseName != className) {
      return baseName;
    }
    return null;
  }

  String _titleCase(String input) =>
      input[0].toUpperCase() + input.substring(1);

  bool _isScreen(
    String className,
    String? superClass,
    bool hasBuild,
    String filePath,
    List<Evidence> evidence,
  ) {
    var score = 0;
    if (className.endsWith('Screen') || className.endsWith('Page')) {
      score++;
      evidence.add(const Evidence(
          description: 'class name ends with Screen/Page', weight: 1.5));
    }
    if (filePath.contains('_screen.dart') ||
        filePath.contains('/screens/') ||
        filePath.contains('_page.dart') ||
        filePath.contains('/pages/')) {
      score++;
      evidence.add(const Evidence(
          description: 'located in screens/pages path', weight: 1.2));
    }
    if (superClass != null &&
        (superClass.contains('StatefulWidget') ||
            superClass.contains('StatelessWidget'))) {
      score++;
      evidence.add(Evidence(description: 'extends $superClass', weight: 1.5));
    }
    if (hasBuild) {
      evidence.add(
          const Evidence(description: 'contains build() method', weight: 1.0));
    }
    return score >= 2;
  }

  bool _isProvider(
    String className,
    String? superClass,
    List<String> methods,
    String filePath,
    List<Evidence> evidence, {
    List<String> imports = const [],
  }) {
    if (className.endsWith('Controller') &&
        (filePath.contains('/controllers/') ||
            filePath.contains('_controller.dart'))) {
      return false;
    }

    var score = 0;
    if (superClass != null && superClass.contains('ChangeNotifier')) {
      score += 2;
      evidence.add(
          const Evidence(description: 'extends ChangeNotifier', weight: 2.0));
    }
    if (methods.contains('notifyListeners')) {
      score++;
      evidence.add(
          const Evidence(description: 'calls notifyListeners()', weight: 1.5));
    }
    if (className.endsWith('Provider') || filePath.contains('_provider.dart')) {
      score++;
      evidence.add(const Evidence(
          description: 'provider naming convention', weight: 1.0));
    }
    return score >= 2;
  }

  bool _isBloc(
    String className,
    String? superClass,
    List<String> imports,
    List<Evidence> evidence,
  ) {
    if ((superClass != null && superClass.contains('Bloc')) ||
        className.endsWith('Bloc')) {
      evidence.add(
          const Evidence(description: 'Bloc pattern detected', weight: 2.0));
      return true;
    }
    if (imports.any(
        (i) => i.contains('flutter_bloc') || i.contains('package:bloc/'))) {
      if (className.endsWith('Bloc')) {
        evidence.add(
            const Evidence(description: 'Bloc import and naming', weight: 1.5));
        return true;
      }
    }
    return false;
  }

  bool _isCubit(String className, String? superClass, List<String> imports,
      List<Evidence> evidence) {
    if ((superClass != null && superClass.contains('Cubit')) ||
        className.endsWith('Cubit')) {
      evidence.add(
          const Evidence(description: 'Cubit pattern detected', weight: 2.0));
      return true;
    }
    return false;
  }

  bool _isGetxController(
    String className,
    String? superClass,
    List<String> imports,
    String filePath,
    List<Evidence> evidence,
  ) {
    if (superClass != null &&
        (superClass.contains('GetxController') ||
            superClass.contains('GetxService'))) {
      evidence.add(
        const Evidence(description: 'extends GetxController', weight: 2.0),
      );
      return true;
    }

    final controllerPath = filePath.contains('/controllers/') ||
        filePath.contains('_controller.dart');
    if (!className.endsWith('Controller')) return false;

    if (imports.any((i) => i.contains('package:get/'))) {
      evidence.add(
        const Evidence(description: 'GetX controller naming', weight: 1.5),
      );
      return true;
    }

    if (controllerPath &&
        superClass != null &&
        superClass.contains('ChangeNotifier')) {
      evidence.add(
        const Evidence(
          description: 'GetX hybrid ChangeNotifier controller',
          weight: 1.8,
        ),
      );
      return true;
    }

    return false;
  }

  bool _isGetxBinding(
    String className,
    String? superClass,
    String filePath,
    List<String> imports,
    List<Evidence> evidence,
  ) {
    if (superClass != null && superClass.contains('Bindings')) {
      evidence.add(
        const Evidence(description: 'extends GetX Bindings', weight: 2.0),
      );
      return true;
    }
    if (!className.endsWith('Binding')) return false;
    if (filePath.contains('/bindings/') ||
        filePath.contains('_binding.dart') ||
        imports.any((i) => i.contains('package:get/'))) {
      evidence.add(
        const Evidence(description: 'GetX binding class', weight: 1.5),
      );
      return true;
    }
    return false;
  }

  bool _isRiverpodNotifier(
    String className,
    String? superClass,
    List<String> imports,
    List<Evidence> evidence, {
    bool hasRiverpodAnnotation = false,
  }) {
    if (hasRiverpodAnnotation) {
      evidence.add(
        const Evidence(description: '@riverpod annotation', weight: 2.5),
      );
      return true;
    }
    if (superClass != null &&
        (superClass.contains('Notifier') ||
            superClass.contains('AsyncNotifier') ||
            superClass.contains(r'$Notifier'))) {
      evidence.add(Evidence(description: 'extends $superClass', weight: 2.0));
      return true;
    }
    if (imports.any((i) => i.contains('riverpod'))) {
      if (className.endsWith('Notifier') ||
          className.endsWith('Provider') ||
          className.contains('Provider')) {
        evidence.add(const Evidence(
            description: 'Riverpod notifier pattern', weight: 1.5));
        return true;
      }
    }
    return false;
  }

  bool _isService(String className, String filePath, List<Evidence> evidence) {
    if (className.endsWith('Service') ||
        filePath.contains('_service.dart') ||
        filePath.contains('/services/')) {
      evidence.add(const Evidence(
          description: 'service naming convention', weight: 1.5));
      return true;
    }
    return false;
  }

  bool _isRepository(
      String className, String filePath, List<Evidence> evidence) {
    if (className.endsWith('Repository') ||
        filePath.contains('_repository.dart')) {
      evidence.add(const Evidence(
          description: 'repository naming convention', weight: 1.5));
      return true;
    }
    return false;
  }

  bool _isApiClient(
      String className, String filePath, List<Evidence> evidence) {
    if (className.contains('ApiClient') ||
        className.contains('ApiService') ||
        filePath.contains('api_client')) {
      evidence
          .add(const Evidence(description: 'API client naming', weight: 1.5));
      return true;
    }
    return false;
  }

  bool _isModel(
    String className,
    String filePath,
    List<String> methods,
    List<Evidence> evidence,
  ) {
    if (className.endsWith('Model') ||
        filePath.contains('/models/') ||
        methods.contains('fromJson') ||
        methods.contains('toJson')) {
      evidence
          .add(const Evidence(description: 'model/DTO pattern', weight: 1.2));
      return true;
    }
    return false;
  }
}
