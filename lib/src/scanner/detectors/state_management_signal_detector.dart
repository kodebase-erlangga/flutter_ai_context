import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Runtime-usable signals for state management frameworks.
class StateManagementSignals {
  StateManagementSignals({
    this.provider = 0,
    this.bloc = 0,
    this.riverpod = 0,
    this.getx = 0,
    List<String>? evidence,
  }) : evidence = evidence ?? <String>[];

  int provider;
  int bloc;
  int riverpod;
  int getx;
  final List<String> evidence;

  Map<String, int> toMap() => {
        'provider': provider,
        'bloc': bloc,
        'riverpod': riverpod,
        'getx': getx,
      };

  void merge(StateManagementSignals other) {
    provider += other.provider;
    bloc += other.bloc;
    riverpod += other.riverpod;
    getx += other.getx;
    evidence.addAll(other.evidence);
  }
}

/// Detects Provider, Bloc, Riverpod, and GetX usage signals in source.
class StateManagementSignalDetector {
  StateManagementSignals detect(CompilationUnit unit, List<String> imports) {
    final signals = StateManagementSignals();
    final importText = imports.join(' ');

    if (importText.contains('flutter_riverpod') ||
        importText.contains('hooks_riverpod') ||
        importText.contains('package:riverpod/')) {
      signals.evidence.add('Riverpod package import');
    }
    if (importText.contains('package:get/get.dart') ||
        importText.contains('package:get/')) {
      signals.evidence.add('GetX package import');
    }
    if (importText.contains('package:provider/')) {
      signals.evidence.add('Provider package import');
    }
    if (importText.contains('flutter_bloc') || importText.contains('bloc')) {
      signals.evidence.add('Bloc package import');
    }

    unit.accept(_SignalVisitor(signals));
    return signals;
  }
}

class _SignalVisitor extends RecursiveAstVisitor<void> {
  _SignalVisitor(this.signals);

  final StateManagementSignals signals;

  @override
  void visitAnnotation(Annotation node) {
    final name = node.name.name;
    if (name == 'riverpod' || name.endsWith('Riverpod')) {
      signals.riverpod += 2;
      signals.evidence.add('@$name annotation');
    }
    super.visitAnnotation(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final name = node.name.lexeme;
    final superType = node.extendsClause?.superclass.toString() ?? '';

    if (superType.contains('GetxController') ||
        superType.contains('GetxService')) {
      signals.getx += 3;
      signals.evidence.add('$name extends GetxController');
    }
    if (superType.contains('ConsumerWidget') ||
        superType.contains('ConsumerStatefulWidget')) {
      signals.riverpod += 2;
      signals.evidence.add('$name is a Riverpod Consumer widget');
    }
    if (superType.contains('Bloc') && !superType.contains('BlocBuilder')) {
      signals.bloc += 2;
      signals.evidence.add('$name extends Bloc');
    }
    if (superType.contains('Cubit')) {
      signals.bloc += 2;
      signals.evidence.add('$name extends Cubit');
    }

    super.visitClassDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final method = node.methodName.name;
    final target = node.target?.toString() ?? '';

    if (method == 'notifyListeners') {
      signals.provider += 2;
      signals.evidence.add('notifyListeners() call');
    }
    if (target == 'ref' &&
        (method == 'watch' || method == 'read' || method == 'listen')) {
      signals.riverpod += 2;
      signals.evidence.add('ref.$method()');
    }
    if (target.contains('context') && (method == 'watch' || method == 'read')) {
      signals.provider += 1;
      signals.evidence.add('context.$method()');
    }
    if (method == 'BlocProvider' ||
        method == 'BlocBuilder' ||
        method == 'BlocListener') {
      signals.bloc += 2;
      signals.evidence.add('$method usage');
    }
    if (method == 'Get' ||
        method == 'put' ||
        method == 'find' ||
        target == 'Get') {
      if (method == 'put' || method == 'find' || target == 'Get') {
        signals.getx += 2;
        signals.evidence.add('Get.$method usage');
      }
    }
    if (method == 'Obx') {
      signals.getx += 2;
      signals.evidence.add('Obx() usage');
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.name == 'Get' &&
        (node.identifier.name == 'put' || node.identifier.name == 'find')) {
      signals.getx += 2;
      signals.evidence.add('Get.${node.identifier.name}');
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (node.fields.variables.any((v) => v.name.lexeme.endsWith('obs'))) {
      signals.getx += 1;
      signals.evidence.add('.obs reactive property');
    }
    super.visitFieldDeclaration(node);
  }
}
