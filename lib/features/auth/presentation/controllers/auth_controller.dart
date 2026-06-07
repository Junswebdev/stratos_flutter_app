import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/auth_repository.dart';

// Represents the authentication state
import '../../domain/user_model.dart';

class AuthState {
  final bool isAuthenticated;
  final String? error;
  final String? role;

  AuthState({this.isAuthenticated = false, this.error, this.role});
}

// Controller to manage Auth state using AsyncNotifier
class AuthController extends AsyncNotifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<AuthState> build() async {
    final token = await _repository.accessToken();
    if (token != null) {
      try {
        final user = await _repository.fetchMe();
        return AuthState(isAuthenticated: true, role: user.role.name);
      } catch (e) {
        // Token is stale or invalid — clear it so the user is redirected to login
        await _repository.logout();
        return AuthState(isAuthenticated: false, error: 'Session expired');
      }
    }
    return AuthState(isAuthenticated: false);
  }

  Future<bool> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final session = await _repository.login(email: email, password: password);
      final user = session.user ?? await _repository.fetchMe();
      state = AsyncData(AuthState(isAuthenticated: true, role: user.role.name));
      return true;
    } catch (e) {
      state = AsyncData(
        AuthState(isAuthenticated: false, error: _extractMessage(e)),
      );
      return false;
    }
  }

  Future<bool> register(
    String email,
    String password,
    String? fullName, {
    UserRole role = UserRole.student,
  }) async {
    state = const AsyncLoading();
    try {
      await _repository.register(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
      );
      return await login(email, password);
    } catch (e) {
      state = AsyncData(
        AuthState(isAuthenticated: false, error: _extractMessage(e)),
      );
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    state = const AsyncLoading();
    try {
      final googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? '924562664956-n363u9htfvjvr5s49pvjekktgd0s9gbm.apps.googleusercontent.com' : null,
        scopes: ['email', 'profile', 'openid'],
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        state = AsyncData(AuthState(isAuthenticated: false));
        return false;
      }

      final auth = await googleUser.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        state = AsyncData(AuthState(isAuthenticated: false, error: 'Google authentication failed: Missing ID Token'));
        return false;
      }

      final session = await _repository.loginWithGoogle(idToken);
      
      state = AsyncData(AuthState(
        isAuthenticated: true, 
        role: session.user?.role.name ?? 'student',
      ));
      return true;
    } catch (e) {
      state = AsyncData(
        AuthState(isAuthenticated: false, error: _extractMessage(e)),
      );
      return false;
    }
  }

  /// Strips the "Exception: " prefix that [Exception.toString()] adds so that
  /// user-facing error messages are clean (e.g. "Incorrect email or password"
  /// instead of "Exception: Incorrect email or password").
  String _extractMessage(Object e) {
    final raw = e.toString();
    const prefix = 'Exception: ';
    if (raw.startsWith(prefix)) {
      return raw.substring(prefix.length);
    }
    return raw;
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    await _repository.logout();
    state = AsyncData(AuthState(isAuthenticated: false));
  }

  Future<bool> updateProfile({String? fullName, String? email, String? password}) async {
    final currentSession = await _repository.restoreSession();
    if (currentSession?.user?.id == null) return false;

    try {
      await _repository.updateUser(currentSession!.user!.id, {
        'full_name': fullName,
        'email': email,
        'password': password,
      }..removeWhere((_, v) => v == null));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateAvatar({
    required List<int> imageBytes,
    required String fileName,
  }) async {
    final currentSession = await _repository.restoreSession();
    if (currentSession?.user?.id == null) return false;

    try {
      await _repository.updateAvatar(
        userId: currentSession!.user!.id,
        imageBytes: imageBytes,
        fileName: fileName,
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  () {
    return AuthController();
  },
);
