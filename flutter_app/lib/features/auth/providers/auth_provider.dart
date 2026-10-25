import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/storage/local_store.dart';
import '../models/staff_user.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final bool requiresMfa;
  final String? mfaToken;
  final StaffUser? user;
  final String? errorMessage;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.requiresMfa = false,
    this.mfaToken,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    bool? requiresMfa,
    String? mfaToken,
    StaffUser? user,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      requiresMfa: requiresMfa ?? this.requiresMfa,
      mfaToken: mfaToken ?? this.mfaToken,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.read(apiClientProvider);
  final localStore = ref.read(localStoreProvider);
  return AuthNotifier(apiClient, localStore);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final LocalStore _localStore;

  AuthNotifier(this._apiClient, this._localStore) : super(AuthState()) {
    _initAuth();
  }

  Future<void> _initAuth() async {
    final token = await _localStore.getAccessToken();
    final savedUser = await _localStore.getSavedStaffUser();

    if (token != null && savedUser != null) {
      _apiClient.setTokens(accessToken: token);
      final meRes = await _apiClient.get('/auth/me');
      if (meRes.isSuccess && meRes.data != null) {
        final verifiedUser = StaffUser.fromJson(meRes.data!);
        state = state.copyWith(
          isAuthenticated: true,
          user: verifiedUser,
        );
      } else if (meRes.statusCode == 401 || meRes.statusCode == 403) {
        _apiClient.clearTokens();
        await _localStore.clearAuth();
        state = AuthState();
      } else {
        state = state.copyWith(
          isAuthenticated: true,
          user: StaffUser.fromJson(savedUser),
        );
      }
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final res = await _apiClient.post(
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
      includeAuth: false,
    );

    if (res.isSuccess && res.data != null) {
      final data = res.data!;
      if (data['requires_mfa'] == true) {
        state = state.copyWith(
          isLoading: false,
          requiresMfa: true,
          mfaToken: data['mfa_token'] as String?,
        );
        return false;
      }

      final accessToken = data['access_token'] as String;
      final refreshToken = data['refresh_token'] as String;
      _apiClient.setTokens(accessToken: accessToken, refreshToken: refreshToken);

      // Fetch user profile from /auth/me
      final meRes = await _apiClient.get('/auth/me');
      StaffUser user;
      if (meRes.isSuccess && meRes.data != null) {
        user = StaffUser.fromJson(meRes.data!);
      } else {
        user = StaffUser(
          staffId: 'doctor-current',
          role: 'doctor',
          nameAr: 'طبيب العيادة',
          email: email,
          mfaEnabled: false,
        );
      }

      await _localStore.saveAuth(
        accessToken: accessToken,
        refreshToken: refreshToken,
        staffUser: user.toJson(),
      );

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        requiresMfa: false,
        user: user,
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: res.errorMessage ?? 'فشل تسجيل الدخول. يرجى التحقق من البيانات.',
      );
      return false;
    }
  }

  Future<bool> verifyMfa(String totpCode) async {
    if (state.mfaToken == null) return false;
    state = state.copyWith(isLoading: true, errorMessage: null);

    final res = await _apiClient.post(
      '/auth/mfa/verify',
      body: {
        'mfa_token': state.mfaToken,
        'totp_code': totpCode.trim(),
      },
      includeAuth: false,
    );

    if (res.isSuccess && res.data != null) {
      final data = res.data!;
      final accessToken = data['access_token'] as String;
      final refreshToken = data['refresh_token'] as String;
      _apiClient.setTokens(accessToken: accessToken, refreshToken: refreshToken);

      final meRes = await _apiClient.get('/auth/me');
      final user = meRes.isSuccess && meRes.data != null
          ? StaffUser.fromJson(meRes.data!)
          : StaffUser(
              staffId: 'doctor-current',
              role: 'doctor',
              nameAr: 'طبيب العيادة',
              email: 'doctor@marsa.clinic',
              mfaEnabled: true,
            );

      await _localStore.saveAuth(
        accessToken: accessToken,
        refreshToken: refreshToken,
        staffUser: user.toJson(),
      );

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        requiresMfa: false,
        mfaToken: null,
        user: user,
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: res.errorMessage ?? 'رمز التحقق الثنائي غير صحيح',
      );
      return false;
    }
  }

  /// Offline Doctor Demo Sign-in mode for tablet when offline
  Future<void> signInOffline() async {
    final offlineDoctor = StaffUser(
      staffId: 'offline-dr-01',
      role: 'doctor',
      nameAr: 'د. استشاري الطب النفسي',
      nameEn: 'Dr. Consultant Psychiatrist',
      email: 'doctor@marsa.clinic',
      mfaEnabled: false,
    );

    await _localStore.saveAuth(
      accessToken: 'offline_token_doctor',
      refreshToken: 'offline_refresh',
      staffUser: offlineDoctor.toJson(),
    );

    state = state.copyWith(
      isAuthenticated: true,
      user: offlineDoctor,
      errorMessage: null,
    );
  }

  /// Offline Receptionist Sign-in mode for tablet/phone when offline
  Future<void> signInOfflineReceptionist() async {
    final offlineReceptionist = StaffUser(
      staffId: 'offline-recep-01',
      role: 'receptionist',
      nameAr: 'مسؤول الاستقبال',
      nameEn: 'Receptionist',
      email: 'receptionist@marsa.clinic',
      mfaEnabled: false,
    );

    await _localStore.saveAuth(
      accessToken: 'offline_token_receptionist',
      refreshToken: 'offline_refresh',
      staffUser: offlineReceptionist.toJson(),
    );

    state = state.copyWith(
      isAuthenticated: true,
      user: offlineReceptionist,
      errorMessage: null,
    );
  }

  Future<void> logout() async {
    await _localStore.clearAuth();
    _apiClient.clearTokens();
    state = AuthState();
  }
}
