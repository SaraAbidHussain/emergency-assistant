import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  static const String _usersIndexKey = 'users_index'; // list of phone numbers
  static const String _userPrefix = 'user_'; // user_<phone> -> json string

  static String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  static String _sanitizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  static Future<String?> signUp({
    required String fullName,
    required String phoneNumber,
    required String dateOfBirth,
    required String bloodGroup,
    required String homeAddress,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _sanitizePhone(phoneNumber);
    final userKey = '$_userPrefix$key';

    if (prefs.containsKey(userKey)) {
      return 'Account already registered';
    }

    final user = UserModel(
      fullName: fullName.trim(),
      phoneNumber: phoneNumber.trim(),
      dateOfBirth: dateOfBirth.trim(),
      bloodGroup: bloodGroup.trim(),
      homeAddress: homeAddress.trim(),
      passwordHash: _hashPassword(password),
    );

    await prefs.setString(userKey, jsonEncode(user.toJson()));

    // maintain an index of all registered user keys
    final index = prefs.getStringList(_usersIndexKey) ?? [];
    if (!index.contains(key)) {
      index.add(key);
      await prefs.setStringList(_usersIndexKey, index);
    }

    return null; // success
  }

  static Future<UserModel?> login({
    required String fullName,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getStringList(_usersIndexKey) ?? [];
    final hashedInput = _hashPassword(password);

    for (final key in index) {
      final raw = prefs.getString('$_userPrefix$key');
      if (raw == null) continue;

      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final user = UserModel.fromJson(json);

        if (user.fullName.toLowerCase() == fullName.trim().toLowerCase() &&
            user.passwordHash == hashedInput) {
          return user;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}