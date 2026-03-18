import 'package:hive_flutter/hive_flutter.dart';

class CredentialsStore {
  static const String _boxName = 'tickify_credentials';
  static const String _kEmail = 'email';
  static const String _kPassword = 'password';

  static Future<Box> _box() => Hive.openBox(_boxName);

  static Future<void> save({
    required String email,
    required String password,
  }) async {
    final box = await _box();
    await box.put(_kEmail, email);
    await box.put(_kPassword, password);
  }

  static Future<({String email, String password})?> read() async {
    final box = await _box();
    final email = box.get(_kEmail) as String?;
    final password = box.get(_kPassword) as String?;
    if (email == null || password == null) return null;
    return (email: email, password: password);
  }
}

