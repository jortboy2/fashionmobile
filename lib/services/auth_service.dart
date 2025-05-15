class AuthService {
  static Map<String, dynamic>? currentUser;

  static bool get isLoggedIn => currentUser != null;

  static void login(Map<String, dynamic> user) {
    currentUser = user;
  }

  static void logout() {
    currentUser = null;
  }
} 