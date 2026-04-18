import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api_client.dart';
import '../../core/storage.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {}
class AuthUnauthenticated extends AuthState {
  final String? lastNip;
  final bool rememberMe;
  AuthUnauthenticated({this.lastNip, this.rememberMe = false});
}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

class AuthCubit extends Cubit<AuthState> {
  final ApiClient _api = ApiClient();

  AuthCubit() : super(AuthInitial());

  Future<void> checkAuth() async {
    // Check local storage first, don't show loading for simple storage read
    final saved = await AppStorage.getSavedCredentials();
    final lastNip = await AppStorage.getLastNip();
    final rememberMe = await AppStorage.getRememberMe();

    // Only attempt auto-login if remember me is true
    if (saved != null && rememberMe) {
      emit(AuthLoading());
      final result = await _api.login(
        nip: saved['nip']!,
        password: saved['password']!,
      );
      if (result.success) {
        emit(AuthAuthenticated());
      } else {
        emit(AuthUnauthenticated(lastNip: lastNip, rememberMe: rememberMe));
      }
    } else {
      // No saved creds or remember me off - go straight to login form
      emit(AuthUnauthenticated(lastNip: lastNip, rememberMe: rememberMe));
    }
  }

  Future<void> login({
    required String nip,
    required String password,
    required bool rememberMe,
  }) async {
    try {
      emit(AuthLoading());
      if (rememberMe) {
        await AppStorage.saveCredentials(nip: nip, password: password);
        await AppStorage.setRememberMe(true);
      } else {
        await AppStorage.setRememberMe(false);
      }

      final result = await _api.login(nip: nip, password: password);
      if (result.success) {
        emit(AuthAuthenticated());
      } else {
        emit(AuthError(result.error ?? 'Login gagal'));
      }
    } catch (e) {
      emit(AuthError('Terjadi kesalahan: $e'));
    }
  }

  Future<void> logout() async {
    await _api.logout();
    await AppStorage.clearCredentials();
    emit(AuthUnauthenticated());
  }
}
