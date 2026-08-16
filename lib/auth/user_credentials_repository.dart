import 'app_user.dart';
import 'password_utils.dart';

/// Admin-only static demo login (no network).
class UserCredentialsRepository {
  UserCredentialsRepository();

  static const String _adminEmail = 'admin@bds.com';
  static const String _adminPasswordHash =
      '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9';

  Future<AppUser?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final emailLower = email.trim().toLowerCase();
    final computed = sha256Hex(password);

    if (emailLower != _adminEmail) return null;
    if (computed.toLowerCase() != _adminPasswordHash.toLowerCase()) return null;
    return const AppUser(email: _adminEmail);
  }
}
