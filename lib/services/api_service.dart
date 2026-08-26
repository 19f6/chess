import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

/// REST helpers. The realtime gameplay/lobby flow runs entirely over
/// Socket.IO; this is used only for a quick server-reachability check on
/// the username screen so a misconfigured [AppConfig.serverUrl] fails fast
/// with a clear message instead of a silent socket timeout.
class ApiService {
  static Future<bool> isServerReachable() async {
    try {
      final res = await http
          .get(Uri.parse('${AppConfig.serverUrl}/api/health'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['ok'] == true;
    } catch (_) {
      return false;
    }
  }
}
