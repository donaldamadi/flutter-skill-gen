import 'package:hooks_riverpod/hooks_riverpod.dart';

class AuthState {
  const AuthState({this.isAuthenticated = false});
  final bool isAuthenticated;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  void login() => state = const AuthState(isAuthenticated: true);
  void logout() => state = const AuthState();
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
