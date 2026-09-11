import 'package:flutter_ai_context/src/graph/node.dart';
import 'package:flutter_ai_context/src/graph/project_graph.dart';
import 'package:flutter_ai_context/src/graph/schema.dart';
import 'package:flutter_ai_context/src/inference/state_management_detector.dart';
import 'package:test/test.dart';

ProjectGraph _hybridGraph() {
  return ProjectGraph(
    nodes: [
      GraphNode(
        id: 'class:lib/features/presensi/controllers/presensi_controller.dart#PresensiController',
        type: NodeType.notifier,
        name: 'PresensiController',
        file: 'lib/features/presensi/controllers/presensi_controller.dart',
        metadata: const {'stateManagementFramework': 'getx'},
      ),
      GraphNode(
        id: 'class:lib/features/presensi/controllers/attendance_controller.dart#AttendanceController',
        type: NodeType.notifier,
        name: 'AttendanceController',
        file: 'lib/features/presensi/controllers/attendance_controller.dart',
        metadata: const {'stateManagementFramework': 'getx'},
      ),
      GraphNode(
        id: 'class:lib/features/presensi/providers/session_provider.dart#SessionProvider',
        type: NodeType.provider,
        name: 'SessionProvider',
        file: 'lib/features/presensi/providers/session_provider.dart',
      ),
    ],
    edges: const [],
  );
}

void main() {
  group('StateManagementDetector', () {
    test('prefers graph architecture over Provider usage signals', () {
      final result = StateManagementDetector().detect(
        graph: _hybridGraph(),
        signals: const {
          'provider': 40,
          'getx': 2,
        },
      );

      expect(result.primary, 'GetX');
      expect(result.graphCounts['GetX'], 2);
      expect(result.graphCounts['Provider'], 1);
      expect(result.signalCounts['Provider'], 40);
      expect(result.secondary, 'Provider');
      expect(result.isHybrid, isTrue);
      expect(result.hybridNote, contains('GetX drives feature architecture'));
      expect(result.hybridNote, contains('Provider'));
    });

    test('treats signal-only Provider as DI layer when GetX owns graph', () {
      final graph = ProjectGraph(
        nodes: [
          GraphNode(
            id: 'class:lib/features/home/controllers/home_controller.dart#HomeController',
            type: NodeType.notifier,
            name: 'HomeController',
            file: 'lib/features/home/controllers/home_controller.dart',
            metadata: const {'stateManagementFramework': 'getx'},
          ),
        ],
        edges: const [],
      );

      final result = StateManagementDetector().detect(
        graph: graph,
        signals: const {'provider': 212, 'getx': 22},
      );

      expect(result.primary, 'GetX');
      expect(result.diLayerFramework, 'Provider');
      expect(result.distribution['GetX'], 100);
    });

    test('does not count generic notifiers as Riverpod', () {
      final graph = ProjectGraph(
        nodes: [
          GraphNode(
            id: 'class:lib/core/app_notifier.dart#AppNotifier',
            type: NodeType.notifier,
            name: 'AppNotifier',
            file: 'lib/core/app_notifier.dart',
          ),
        ],
        edges: const [],
      );

      final result = StateManagementDetector().detect(
        graph: graph,
        signals: const {'riverpod': 0, 'provider': 1},
      );

      expect(result.graphCounts['Riverpod'], 0);
      expect(result.primary, 'Provider');
    });

    test('counts bloc and cubit nodes from graph', () {
      final graph = ProjectGraph(
        nodes: [
          GraphNode(
            id: 'class:lib/auth/auth_bloc.dart#AuthBloc',
            type: NodeType.bloc,
            name: 'AuthBloc',
            file: 'lib/auth/auth_bloc.dart',
          ),
          GraphNode(
            id: 'class:lib/auth/auth_cubit.dart#AuthCubit',
            type: NodeType.cubit,
            name: 'AuthCubit',
            file: 'lib/auth/auth_cubit.dart',
          ),
        ],
        edges: const [],
      );

      final result = StateManagementDetector().detect(
        graph: graph,
        signals: const {},
      );

      expect(result.primary, 'Bloc');
      expect(result.graphCounts['Bloc'], 2);
    });
  });
}
