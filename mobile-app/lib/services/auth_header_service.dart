import 'package:firebase_auth/firebase_auth.dart';

class AuthHeaderService {
  static Future<Map<String, String>> getAuthHeader() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return <String, String>{};
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      return <String, String>{};
    }

    return {'Authorization': 'Bearer $idToken'};
  }
}
