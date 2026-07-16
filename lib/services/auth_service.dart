import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  AuthService._internal() {
    _loadLocalSession();
  }

  // Active session notifier
  final ValueNotifier<UserModel?> currentUser = ValueNotifier<UserModel?>(null);

  // Google sign in removed temporarily

  // Register a new user
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await ApiClient.post('/auth/register', body: {
        'fullName': fullName,
        'email': email,
        'password': password,
      });

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        if (data['success'] == true) {
          final profile = UserModel.fromMap(data['user']);
          currentUser.value = profile;
          await _saveLocalSession(profile, data['token']);
          return {'success': true, 'message': 'Đăng ký tài khoản thành công!'};
        }
      }
      return {'success': false, 'message': data['message'] ?? 'Đăng ký thất bại. Vui lòng thử lại.'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  // Send 6-digit verification code to register email
  Future<Map<String, dynamic>> sendRegisterCode({required String email}) async {
    try {
      final response = await ApiClient.post('/auth/register/send-code', body: {
        'email': email,
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['success'] == true) {
          return {'success': true, 'message': data['message'] ?? 'Mã xác thực đã được gửi!'};
        }
      }
      return {'success': false, 'message': data['message'] ?? 'Gửi mã xác thực thất bại.'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  // Verify 6-digit registration code to create account
  Future<Map<String, dynamic>> verifyRegisterCode({
    required String email,
    required String fullName,
    required String password,
    required String code,
  }) async {
    try {
      final response = await ApiClient.post('/auth/register/verify-code', body: {
        'email': email,
        'fullName': fullName,
        'password': password,
        'code': code,
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['success'] == true) {
          final profile = UserModel.fromMap(data['user']);
          currentUser.value = profile;
          await _saveLocalSession(profile, data['token']);
          return {'success': true, 'message': 'Đăng ký tài khoản thành công!'};
        }
      }
      return {'success': false, 'message': data['message'] ?? 'Xác thực mã thất bại.'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  // Send 6-digit verification code for forgot password
  Future<Map<String, dynamic>> sendForgotPasswordCode({required String email}) async {
    try {
      final response = await ApiClient.post('/auth/forgot-password/send-code', body: {
        'email': email,
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['success'] == true) {
          return {'success': true, 'message': data['message'] ?? 'Mã xác thực đã được gửi!'};
        }
      }
      return {'success': false, 'message': data['message'] ?? 'Gửi mã xác thực thất bại.'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  // Reset password using email, code, and new password
  Future<Map<String, dynamic>> resetForgotPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await ApiClient.post('/auth/forgot-password/reset', body: {
        'email': email,
        'code': code,
        'newPassword': newPassword,
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['success'] == true) {
          return {'success': true, 'message': data['message'] ?? 'Đặt lại mật khẩu thành công!'};
        }
      }
      return {'success': false, 'message': data['message'] ?? 'Đổi mật khẩu thất bại.'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  // Login with email and password
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await ApiClient.post('/auth/login', body: {
        'email': email,
        'password': password,
      });

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['success'] == true) {
          final profile = UserModel.fromMap(data['user']);
          currentUser.value = profile;
          await _saveLocalSession(profile, data['token']);
          return {'success': true, 'message': 'Đăng nhập thành công!'};
        }
      }
      return {'success': false, 'message': data['message'] ?? 'Email hoặc mật khẩu không chính xác.'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  // Google Sign-In
  Future<Map<String, dynamic>> loginWithGoogle({
    required String email,
    required String fullName,
    String? avatarUrl,
    String? token,
  }) async {
    try {
      final response = await ApiClient.post('/auth/social-login', body: {
        'email': email,
        'fullName': fullName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        'provider': 'google.com',
        'token': token ?? 'mock-google-token-${DateTime.now().millisecondsSinceEpoch}',
      });

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['success'] == true) {
          final profile = UserModel.fromMap(data['user']);
          currentUser.value = profile;
          await _saveLocalSession(profile, data['token']);
          return {'success': true, 'message': data['message'] ?? 'Đăng nhập Google thành công!'};
        }
      }
      return {'success': false, 'message': data['message'] ?? 'Đăng nhập Google thất bại.'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  // Facebook Sign-In
  Future<Map<String, dynamic>> loginWithFacebook({
    required String email,
    required String fullName,
    String? avatarUrl,
    String? token,
  }) async {
    try {
      final response = await ApiClient.post('/auth/social-login', body: {
        'email': email,
        'fullName': fullName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        'provider': 'facebook.com',
        'token': token ?? 'mock-facebook-token-${DateTime.now().millisecondsSinceEpoch}',
      });

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['success'] == true) {
          final profile = UserModel.fromMap(data['user']);
          currentUser.value = profile;
          await _saveLocalSession(profile, data['token']);
          return {'success': true, 'message': data['message'] ?? 'Đăng nhập Facebook thành công!'};
        }
      }
      return {'success': false, 'message': data['message'] ?? 'Đăng nhập Facebook thất bại.'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  // Update user profile
  Future<bool> updateProfile({
    required String fullName,
    required String avatarUrl,
  }) async {
    if (currentUser.value == null) return false;

    try {
      final response = await ApiClient.put('/auth/profile', body: {
        'fullName': fullName,
        'avatarUrl': avatarUrl,
      });

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final updatedUser = UserModel.fromMap(data['user']);
        currentUser.value = updatedUser;
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('jwt_token');
        if (token != null) {
          await _saveLocalSession(updatedUser, token);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  // Change password
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentUser.value == null) {
      return {'success': false, 'message': 'Chưa đăng nhập.'};
    }

    try {
      final response = await ApiClient.put('/auth/password', body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        // Update local user model if needed
        return {'success': true, 'message': 'Đổi mật khẩu thành công!'};
      }
      return {'success': false, 'message': data['message'] ?? 'Lỗi đổi mật khẩu.'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi đổi mật khẩu: $e'};
    }
  }

  static const String _sessionKey = 'logged_in_user';
  static const String _tokenKey = 'jwt_token';

  // Save session to local storage
  Future<void> _saveLocalSession(UserModel user, String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = jsonEncode(user.toMap());
      await prefs.setString(_sessionKey, userJson);
      await prefs.setString(_tokenKey, token);
    } catch (e) {
      debugPrint('Error saving local session: $e');
    }
  }

  // Load session from local storage
  Future<void> _loadLocalSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_sessionKey);
      if (userJson != null) {
        final Map<String, dynamic> userMap = jsonDecode(userJson);
        currentUser.value = UserModel.fromMap(userMap);
      }
    } catch (e) {
      debugPrint('Error loading local session: $e');
    }
  }

  // Clear local session from storage
  Future<void> _clearLocalSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      await prefs.remove(_tokenKey);
    } catch (e) {
      debugPrint('Error clearing local session: $e');
    }
  }

  // Logout session
  Future<void> logout() async {
    try {
      // await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Error logging out from Google: $e');
    }
    await _clearLocalSession();
    currentUser.value = null;
  }
}
