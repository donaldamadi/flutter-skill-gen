import 'package:feature_auth/feature_auth.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  routes: [GoRoute(path: '/', builder: (context, state) => const LoginView())],
);
