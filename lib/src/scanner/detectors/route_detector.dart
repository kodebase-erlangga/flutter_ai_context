import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../graph/edge.dart';
import '../../graph/node.dart';
import '../../graph/project_graph.dart';
import '../../graph/schema.dart';

/// A detected navigation route.
class DetectedRoute {
  DetectedRoute({
    required this.path,
    required this.screenName,
    required this.sourceFile,
    required this.confidence,
    required this.evidence,
    this.routeType = 'go_router',
  });

  final String path;
  final String? screenName;
  final String sourceFile;
  final double confidence;
  final List<String> evidence;
  final String routeType;
}

/// Detects GoRouter, Navigator, and named route patterns.
class RouteDetector {
  List<DetectedRoute> detect(String filePath, CompilationUnit unit) {
    final routes = <DetectedRoute>[];
    unit.accept(_RouteVisitor(filePath, routes));
    return routes;
  }

  void applyToGraph(ProjectGraph graph, List<DetectedRoute> routes) {
    for (final route in routes) {
      final routeId = NodeId.forRoute(route.path);
      graph.addNode(
        GraphNode(
          id: routeId,
          type: NodeType.route,
          name: route.path,
          file: route.sourceFile,
          confidence: route.confidence,
          evidence:
              route.evidence.map((e) => Evidence(description: e)).toList(),
          metadata: {'routeType': route.routeType},
        ),
      );

      if (route.screenName != null) {
        final screenId =
            _findScreenId(graph, route.screenName!, route.sourceFile);
        if (screenId != null) {
          graph.addEdge(
            GraphEdge(
              from: routeId,
              to: screenId,
              type: EdgeType.mapsToRoute,
              confidence: route.confidence,
              evidence: route.evidence,
            ),
          );
        }
      }
    }
  }

  String? _findScreenId(
      ProjectGraph graph, String screenName, String sourceFile) {
    for (final node in graph.nodes) {
      if (node.name == screenName && node.type == NodeType.screen) {
        return node.id;
      }
    }
    return NodeId.forClass(sourceFile, screenName);
  }
}

class _RouteVisitor extends RecursiveAstVisitor<void> {
  _RouteVisitor(this.filePath, this.routes);

  final String filePath;
  final List<DetectedRoute> routes;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name.lexeme;
    if (typeName == 'GoRoute') {
      final path = _extractNamedArg(node.argumentList, 'path');
      final screen = _extractBuilderScreen(node.argumentList);
      if (path != null) {
        routes.add(
          DetectedRoute(
            path: path,
            screenName: screen,
            sourceFile: filePath,
            confidence: 0.95,
            evidence: ['GoRoute(path: $path)'],
            routeType: 'go_router',
          ),
        );
      }
    }

    if (typeName == 'AutoRoute') {
      final path = _extractNamedArg(node.argumentList, 'path');
      final page = _extractNamedArg(node.argumentList, 'page');
      if (path != null) {
        routes.add(
          DetectedRoute(
            path: path,
            screenName: _pageToScreenName(page),
            sourceFile: filePath,
            confidence: 0.92,
            evidence: ['AutoRoute(path: $path)'],
            routeType: 'auto_route',
          ),
        );
      }
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final hasAutoRoute = node.metadata.any((annotation) {
      final name = annotation.name.name;
      return name == 'AutoRoute' ||
          name == 'RoutePage' ||
          name.endsWith('AutoRoute');
    });
    if (hasAutoRoute) {
      final path = _annotationStringArg(node.metadata, 'path') ??
          '/${_classRouteName(node.name.lexeme)}';
      routes.add(
        DetectedRoute(
          path: path,
          screenName: node.name.lexeme,
          sourceFile: filePath,
          confidence: 0.88,
          evidence: ['@${node.metadata.first.name.name} on ${node.name.lexeme}'],
          routeType: 'auto_route',
        ),
      );
    }
    super.visitClassDeclaration(node);
  }

  String _classRouteName(String className) {
    var name = className;
    if (name.endsWith('Route')) {
      name = name.substring(0, name.length - 5);
    }
    if (name.endsWith('Page')) {
      name = name.substring(0, name.length - 4);
    }
    return name.toLowerCase();
  }

  String? _pageToScreenName(String? page) {
    if (page == null) return null;
    final cleaned = page.replaceAll('.page', '').replaceAll('Route', '');
    return cleaned.isEmpty ? null : cleaned;
  }

  String? _annotationStringArg(
    NodeList<Annotation> annotations,
    String argName,
  ) {
    for (final annotation in annotations) {
      final args = annotation.arguments;
      if (args == null) continue;
      for (final arg in args.arguments) {
        if (arg is NamedExpression && arg.name.label.name == argName) {
          return _stringValue(arg.expression);
        }
      }
    }
    return null;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final method = node.methodName.name;
    final target = node.target?.toString() ?? '';

    if (method == 'AutoRoute') {
      final path = _extractNamedArg(node.argumentList, 'path');
      final page = _extractNamedArg(node.argumentList, 'page');
      if (path != null) {
        routes.add(
          DetectedRoute(
            path: path,
            screenName: _pageToScreenName(page),
            sourceFile: filePath,
            confidence: 0.9,
            evidence: ['AutoRoute(path: $path)'],
            routeType: 'auto_route',
          ),
        );
      }
    }

    if (method == 'GoRoute') {
      final path = _extractNamedArg(node.argumentList, 'path');
      if (path != null) {
        routes.add(
          DetectedRoute(
            path: path,
            screenName: _extractBuilderScreen(node.argumentList),
            sourceFile: filePath,
            confidence: 0.9,
            evidence: ['GoRoute(path: $path)'],
            routeType: 'go_router',
          ),
        );
      }
    }

    if (method == 'go' || method == 'push' || method == 'pushNamed') {
      final path = _extractFirstStringArg(node.argumentList);
      if (path != null && path.startsWith('/')) {
        routes.add(
          DetectedRoute(
            path: path,
            screenName: null,
            sourceFile: filePath,
            confidence: 0.85,
            evidence: ['$target.$method($path)'],
            routeType: target.contains('GoRouter') ? 'go_router' : 'navigator',
          ),
        );
      }
    }

    if (method == 'pushNamed' && node.argumentList.arguments.isNotEmpty) {
      final path = _extractFirstStringArg(node.argumentList);
      if (path != null) {
        routes.add(
          DetectedRoute(
            path: path,
            screenName: null,
            sourceFile: filePath,
            confidence: 0.8,
            evidence: ['Navigator.pushNamed($path)'],
            routeType: 'navigator',
          ),
        );
      }
    }

    super.visitMethodInvocation(node);
  }

  String? _extractNamedArg(ArgumentList args, String name) {
    for (final arg in args.arguments) {
      if (arg is NamedExpression && arg.name.label.name == name) {
        return _stringValue(arg.expression);
      }
    }
    return null;
  }

  String? _extractBuilderScreen(ArgumentList args) {
    for (final arg in args.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'builder') {
        final expr = arg.expression;
        if (expr is FunctionExpression) {
          final body = expr.body;
          if (body is ExpressionFunctionBody) {
            return _extractTypeFromExpression(body.expression);
          }
          if (body is BlockFunctionBody) {
            for (final stmt in body.block.statements) {
              if (stmt is ReturnStatement && stmt.expression != null) {
                return _extractTypeFromExpression(stmt.expression!);
              }
            }
          }
        }
      }
    }
    return null;
  }

  String? _extractTypeFromExpression(Expression expr) {
    if (expr is InstanceCreationExpression) {
      return expr.constructorName.type.name.lexeme;
    }
    return null;
  }

  String? _extractFirstStringArg(ArgumentList args) {
    for (final arg in args.arguments) {
      final value = _stringValue(arg is NamedExpression ? arg.expression : arg);
      if (value != null) return value;
    }
    return null;
  }

  String? _stringValue(Expression expr) {
    if (expr is SimpleStringLiteral) return expr.value;
    return null;
  }
}
