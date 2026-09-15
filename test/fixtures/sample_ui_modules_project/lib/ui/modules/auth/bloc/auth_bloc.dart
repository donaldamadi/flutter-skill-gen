import 'package:flutter_bloc/flutter_bloc.dart';

class AuthEvent {}

class AuthState {}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthState());
}
