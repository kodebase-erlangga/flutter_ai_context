import 'package:bloc/bloc.dart';

import 'auth_event.dart';
import 'auth_repository.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repository) : super(AuthInitial()) {
    on<AuthLoginRequested>(_onLogin);
  }

  final AuthRepository _repository;

  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    final ok = await _repository.login();
    if (ok) emit(AuthAuthenticated());
  }
}
