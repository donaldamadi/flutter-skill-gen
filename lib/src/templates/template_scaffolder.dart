import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/logger.dart';

/// Known built-in template identifiers.
class TemplateId {
  const TemplateId._();

  /// Clean Architecture + BLoC.
  static const cleanBloc = 'clean_bloc';

  /// Clean Architecture + Riverpod.
  static const cleanRiverpod = 'clean_riverpod';

  /// All available template identifiers.
  static const all = [cleanBloc, cleanRiverpod];
}

/// Scaffolds a new Flutter project from a built-in template.
///
/// Templates are stored as in-memory file maps so the package
/// remains a pure Dart CLI with no bundled asset directory.
class TemplateScaffolder {
  /// Creates a [TemplateScaffolder].
  TemplateScaffolder({
    required this.templateId,
    required this.projectName,
    required this.outputPath,
    Logger? logger,
  }) : logger = logger ?? const Logger();

  /// The template to scaffold from.
  final String templateId;

  /// Name for the new project (used in pubspec, package imports).
  final String projectName;

  /// Directory where the project will be created.
  final String outputPath;

  /// Logger for output.
  final Logger logger;

  /// Scaffolds the project. Returns `true` on success.
  bool scaffold() {
    final template = _templates[templateId];
    if (template == null) {
      logger.error(
        'Unknown template: $templateId. '
        'Available: ${TemplateId.all.join(', ')}',
      );
      return false;
    }

    final dir = Directory(outputPath);
    if (dir.existsSync() && dir.listSync().isNotEmpty) {
      logger.error('Output directory is not empty: $outputPath');
      return false;
    }

    logger.info('Scaffolding $templateId project: $projectName');

    for (final entry in template.entries) {
      final content = entry.value.replaceAll('__PROJECT_NAME__', projectName);
      final filePath = p.join(
        outputPath,
        entry.key.replaceAll('__PROJECT_NAME__', projectName),
      );
      final file = File(filePath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
      logger.debug('  Created $filePath');
    }

    logger.success('Project scaffolded at $outputPath');
    return true;
  }

  /// Map of templateId -> { relativePath: fileContent }.
  static final _templates = <String, Map<String, String>>{
    TemplateId.cleanBloc: _cleanBlocTemplate,
    TemplateId.cleanRiverpod: _cleanRiverpodTemplate,
  };

  // -------------------------------------------------------------------
  // Clean Architecture + BLoC template
  // -------------------------------------------------------------------

  static final _cleanBlocTemplate = <String, String>{
    'pubspec.yaml': '''
name: __PROJECT_NAME__
description: A Flutter project using Clean Architecture and BLoC.
version: 1.0.0

environment:
  sdk: ^3.8.0

dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^9.0.0
  bloc: ^9.0.0
  equatable: ^2.0.0
  get_it: ^8.0.0
  injectable: ^2.5.0
  go_router: ^14.0.0
  dio: ^5.0.0
  dartz: ^0.10.0
  freezed_annotation: ^2.4.0
  json_annotation: ^4.11.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  lints: ^5.1.0
  build_runner: ^2.4.0
  freezed: ^2.5.0
  json_serializable: ^6.9.0
  injectable_generator: ^2.6.0
  bloc_test: ^9.0.0
  mocktail: ^1.0.0
''',
    'analysis_options.yaml': '''
include: package:lints/recommended.yaml

analyzer:
  exclude:
    - '**/*.g.dart'
    - '**/*.freezed.dart'
''',
    'lib/main.dart': '''
import 'package:flutter/material.dart';

import 'core/di/injection.dart';
import 'core/router/app_router.dart';

void main() {
  configureDependencies();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '__PROJECT_NAME__',
      routerConfig: appRouter,
    );
  }
}
''',
    'lib/core/di/injection.dart': '''
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  // Register your dependencies here or use @injectable annotations
  // with build_runner to auto-generate registrations.
}
''',
    'lib/core/router/app_router.dart': '''
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/pages/home_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
  ],
);
''',
    'lib/core/error/failures.dart': '''
import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  const Failure([this.message = '']);
  final String message;

  @override
  List<Object> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server failure']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Cache failure']);
}
''',
    'lib/core/usecase/usecase.dart': '''
import 'package:dartz/dartz.dart';

import '../error/failures.dart';

abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

class NoParams {
  const NoParams();
}
''',
    'lib/features/home/domain/entities/home_entity.dart': '''
import 'package:equatable/equatable.dart';

class HomeEntity extends Equatable {
  const HomeEntity({required this.title});
  final String title;

  @override
  List<Object?> get props => [title];
}
''',
    'lib/features/home/domain/repositories/home_repository.dart': '''
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/home_entity.dart';

abstract class HomeRepository {
  Future<Either<Failure, List<HomeEntity>>> getItems();
}
''',
    'lib/features/home/data/repositories/home_repository_impl.dart': '''
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/home_entity.dart';
import '../../domain/repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  @override
  Future<Either<Failure, List<HomeEntity>>> getItems() async {
    try {
      // Replace with actual data source call.
      return const Right([
        HomeEntity(title: 'Item 1'),
        HomeEntity(title: 'Item 2'),
      ]);
    } on Exception {
      return const Left(ServerFailure());
    }
  }
}
''',
    'lib/features/home/presentation/bloc/home_event.dart': '''
part of 'home_bloc.dart';

abstract class HomeEvent {
  const HomeEvent();
}

class HomeLoadRequested extends HomeEvent {
  const HomeLoadRequested();
}
''',
    'lib/features/home/presentation/bloc/home_state.dart': '''
part of 'home_bloc.dart';

abstract class HomeState {
  const HomeState();
}

class HomeInitial extends HomeState {
  const HomeInitial();
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeLoaded extends HomeState {
  const HomeLoaded({required this.items});
  final List<String> items;
}

class HomeError extends HomeState {
  const HomeError({required this.message});
  final String message;
}
''',
    'lib/features/home/presentation/bloc/home_bloc.dart': '''
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/home_repository.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({required this.repository}) : super(const HomeInitial()) {
    on<HomeLoadRequested>(_onLoadRequested);
  }

  final HomeRepository repository;

  Future<void> _onLoadRequested(
    HomeLoadRequested event,
    Emitter<HomeState> emit,
  ) async {
    emit(const HomeLoading());
    final result = await repository.getItems();
    result.fold(
      (failure) => emit(HomeError(message: failure.message)),
      (items) => emit(
        HomeLoaded(items: items.map((e) => e.title).toList()),
      ),
    );
  }
}
''',
    'lib/features/home/presentation/pages/home_page.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/home_bloc.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeBloc(
        repository: throw UnimplementedError(
          'Wire up HomeRepository via DI',
        ),
      )..add(const HomeLoadRequested()),
      child: Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            if (state is HomeLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            if (state is HomeLoaded) {
              return ListView.builder(
                itemCount: state.items.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(state.items[i]),
                ),
              );
            }
            if (state is HomeError) {
              return Center(child: Text(state.message));
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
''',
    'test/features/home/presentation/bloc/home_bloc_test.dart': '''
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeBloc', () {
    test('initial state is HomeInitial', () {
      // TODO: Implement test
    });
  });
}
''',
    'test/features/home/domain/entities/home_entity_test.dart': '''
import 'package:flutter_test/flutter_test.dart';
import 'package:__PROJECT_NAME__/features/home/domain/entities/home_entity.dart';

void main() {
  group('HomeEntity', () {
    test('supports value equality', () {
      const entity = HomeEntity(title: 'test');
      const same = HomeEntity(title: 'test');
      expect(entity, equals(same));
    });
  });
}
''',
    'test/features/home/data/repositories/home_repository_impl_test.dart': '''
import 'package:flutter_test/flutter_test.dart';
import 'package:__PROJECT_NAME__/features/home/data/repositories/home_repository_impl.dart';

void main() {
  group('HomeRepositoryImpl', () {
    test('getItems returns a list of HomeEntity', () async {
      final repo = HomeRepositoryImpl();
      final result = await repo.getItems();
      expect(result.isRight(), isTrue);
    });
  });
}
''',
    'test/core/error/failures_test.dart': '''
import 'package:flutter_test/flutter_test.dart';
import 'package:__PROJECT_NAME__/core/error/failures.dart';

void main() {
  group('Failures', () {
    test('ServerFailure has default message', () {
      const failure = ServerFailure();
      expect(failure.message, 'Server failure');
    });

    test('CacheFailure has default message', () {
      const failure = CacheFailure();
      expect(failure.message, 'Cache failure');
    });
  });
}
''',
    '.skillrc.yaml': '''
# flutter_skill_gen project configuration
# https://pub.dev/packages/flutter_skill_gen

output_targets:
  - format: generic

watch:
  enabled: true
  debounce_ms: 500
''',
  };

  // -------------------------------------------------------------------
  // Clean Architecture + Riverpod template
  // -------------------------------------------------------------------

  static final _cleanRiverpodTemplate = <String, String>{
    'pubspec.yaml': '''
name: __PROJECT_NAME__
description: A Flutter project using Clean Architecture and Riverpod.
version: 1.0.0

environment:
  sdk: ^3.8.0

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.0
  riverpod_annotation: ^2.6.0
  auto_route: ^9.0.0
  dio: ^5.0.0
  fpdart: ^1.1.0
  freezed_annotation: ^2.4.0
  json_annotation: ^4.11.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  lints: ^5.1.0
  build_runner: ^2.4.0
  freezed: ^2.5.0
  json_serializable: ^6.9.0
  riverpod_generator: ^2.6.0
  auto_route_generator: ^9.0.0
  mocktail: ^1.0.0
''',
    'analysis_options.yaml': '''
include: package:lints/recommended.yaml

analyzer:
  exclude:
    - '**/*.g.dart'
    - '**/*.freezed.dart'
    - '**/*.gr.dart'
''',
    'lib/main.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';

void main() {
  runApp(
    const ProviderScope(child: App()),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '__PROJECT_NAME__',
      routerConfig: appRouter,
    );
  }
}
''',
    'lib/core/router/app_router.dart': '''
import 'package:auto_route/auto_route.dart';

import '../../features/home/presentation/pages/home_page.dart';

// Run `dart run build_runner build` to generate the router.
// For now, using a simple GoRouter-style setup as a placeholder.
// Replace with @AutoRouterConfig after running code generation.

import 'package:flutter/material.dart';

final appRouter = _SimpleRouter();

class _SimpleRouter extends RouterConfig<Object> {
  _SimpleRouter()
      : super(
          routeInformationParser: _parser,
          routerDelegate: _delegate,
          routeInformationProvider: PlatformRouteInformationProvider(
            initialRouteInformation: RouteInformation(
              uri: Uri.parse('/'),
            ),
          ),
        );

  static final _parser = _SimpleParser();
  static final _delegate = _SimpleDelegate();
}

class _SimpleParser extends RouteInformationParser<String> {
  @override
  Future<String> parseRouteInformation(
    RouteInformation routeInformation,
  ) async =>
      routeInformation.uri.path;
}

class _SimpleDelegate extends RouterDelegate<String>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {
  @override
  final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => Navigator(
        key: navigatorKey,
        pages: const [
          MaterialPage(child: HomePage()),
        ],
        onPopPage: (route, result) => route.didPop(result),
      );

  @override
  Future<void> setNewRoutePath(String configuration) async {}
}
''',
    'lib/core/error/failures.dart': '''
import 'package:fpdart/fpdart.dart';

typedef AppEither<T> = Either<Failure, T>;

sealed class Failure {
  const Failure(this.message);
  final String message;
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server failure']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Cache failure']);
}
''',
    'lib/features/home/domain/entities/home_entity.dart': '''
class HomeEntity {
  const HomeEntity({required this.title});
  final String title;
}
''',
    'lib/features/home/domain/repositories/home_repository.dart': '''
import '../../../../core/error/failures.dart';
import '../entities/home_entity.dart';

abstract class HomeRepository {
  Future<AppEither<List<HomeEntity>>> getItems();
}
''',
    'lib/features/home/data/repositories/home_repository_impl.dart': '''
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/home_entity.dart';
import '../../domain/repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  @override
  Future<AppEither<List<HomeEntity>>> getItems() async {
    try {
      // Replace with actual data source call.
      return const Right([
        HomeEntity(title: 'Item 1'),
        HomeEntity(title: 'Item 2'),
      ]);
    } on Exception {
      return const Left(ServerFailure());
    }
  }
}
''',
    'lib/features/home/presentation/providers/home_providers.dart': '''
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/home_repository_impl.dart';
import '../../domain/repositories/home_repository.dart';

final homeRepositoryProvider = Provider<HomeRepository>(
  (_) => HomeRepositoryImpl(),
);

final homeItemsProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(homeRepositoryProvider);
  final result = await repo.getItems();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (items) => items.map((e) => e.title).toList(),
  );
});
''',
    'lib/features/home/presentation/pages/home_page.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(homeItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: items.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) => ListTile(
            title: Text(list[i]),
          ),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, _) => Center(
          child: Text(err.toString()),
        ),
      ),
    );
  }
}
''',
    'test/features/home/presentation/providers/home_providers_test.dart': '''
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('homeItemsProvider', () {
    test('fetches items from repository', () {
      // TODO: Implement test
    });
  });
}
''',
    'test/features/home/domain/entities/home_entity_test.dart': '''
import 'package:flutter_test/flutter_test.dart';
import 'package:__PROJECT_NAME__/features/home/domain/entities/home_entity.dart';

void main() {
  group('HomeEntity', () {
    test('creates instance with title', () {
      const entity = HomeEntity(title: 'test');
      expect(entity.title, 'test');
    });
  });
}
''',
    'test/features/home/data/repositories/home_repository_impl_test.dart': '''
import 'package:flutter_test/flutter_test.dart';
import 'package:__PROJECT_NAME__/features/home/data/repositories/home_repository_impl.dart';

void main() {
  group('HomeRepositoryImpl', () {
    test('getItems returns a list of HomeEntity', () async {
      final repo = HomeRepositoryImpl();
      final result = await repo.getItems();
      expect(result.isRight(), isTrue);
    });
  });
}
''',
    'test/core/error/failures_test.dart': '''
import 'package:flutter_test/flutter_test.dart';
import 'package:__PROJECT_NAME__/core/error/failures.dart';

void main() {
  group('Failures', () {
    test('ServerFailure has default message', () {
      const failure = ServerFailure();
      expect(failure.message, 'Server failure');
    });

    test('CacheFailure has default message', () {
      const failure = CacheFailure();
      expect(failure.message, 'Cache failure');
    });
  });
}
''',
    '.skillrc.yaml': '''
# flutter_skill_gen project configuration
# https://pub.dev/packages/flutter_skill_gen

output_targets:
  - format: generic

watch:
  enabled: true
  debounce_ms: 500
''',
  };
}
