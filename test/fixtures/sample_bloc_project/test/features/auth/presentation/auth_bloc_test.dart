import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sample_bloc_app/features/auth/presentation/bloc/auth_bloc.dart';

void main() {
  group('AuthBloc', () {
    test('initial state is AuthInitial', () {
      final bloc = AuthBloc();
      expect(bloc.state, isA<AuthInitial>());
    });
  });
}
