import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Thin HTTP client for BDS Nest API (`{ status, message, data }` envelopes).
class BdsApiClient {
  BdsApiClient({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final String baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/') ? path : '/$path';
    final u = Uri.parse('$baseUrl$p');
    if (query == null || query.isEmpty) return u;
    return u.replace(queryParameters: query);
  }

  /// `GET /onboarding` — returns `data.list.users`.
  Future<List<dynamic>> getOnboardingUsersList({
    String? userType,
    int limit = 500,
    int page = 1,
  }) async {
    final q = <String, String>{
      'limit': '$limit',
      'page': '$page',
      if (userType != null) 'userType': userType,
    };
    final r = await http.get(_uri('/onboarding', q), headers: {'Accept': 'application/json'});
    final map = _decodeObj(r.body);
    if (r.statusCode >= 400) {
      throw Exception(map['message']?.toString() ?? r.body);
    }
    final data = map['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid onboarding response');
    }
    final list = data['list'];
    if (list is! Map<String, dynamic>) {
      throw Exception('Invalid list envelope');
    }
    final users = list['users'];
    if (users is List) return users;
    throw Exception('Invalid users list');
  }

  Map<String, dynamic> _decodeObj(String body) {
    final v = jsonDecode(body);
    if (v is Map<String, dynamic>) return v;
    throw FormatException('Expected JSON object');
  }

  /// Clock-in/out rows from [GET /staff-attendance/me] (vendorCode = onboarding id).
  Future<List<dynamic>> getStaffAttendanceList({
    required String vendorCode,
    String? from,
    String? to,
  }) async {
    final q = <String, String>{
      'vendorCode': vendorCode,
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
    };
    final r = await http.get(
      _uri('/staff-attendance/me', q),
      headers: {'Accept': 'application/json'},
    );
    final map = _decodeObj(r.body);
    if (r.statusCode >= 400) {
      throw Exception(map['message']?.toString() ?? r.body);
    }
    final data = map['data'];
    if (data is List) return data;
    throw Exception('Invalid staff attendance response');
  }

  Future<List<dynamic>> getDataList(String path) async {
    final r = await http.get(_uri(path), headers: {'Accept': 'application/json'});
    final map = _decodeObj(r.body);
    if (r.statusCode >= 400) {
      throw Exception(map['message']?.toString() ?? r.body);
    }
    final data = map['data'];
    if (data is List) return data;
    throw Exception('Invalid list response');
  }

  Future<Map<String, dynamic>> getDataMap(String path) async {
    final r = await http.get(_uri(path), headers: {'Accept': 'application/json'});
    final map = _decodeObj(r.body);
    if (r.statusCode >= 400) {
      throw Exception(map['message']?.toString() ?? r.body);
    }
    final data = map['data'];
    if (data is Map<String, dynamic>) return data;
    throw Exception('Invalid map response');
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
    final r = await http.post(
      _uri(path),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode(body),
    );
    final map = _decodeObj(r.body);
    if (r.statusCode >= 400) {
      throw Exception(map['message']?.toString() ?? r.body);
    }
    final data = map['data'];
    if (data is Map<String, dynamic>) return data;
    throw Exception('Invalid create response');
  }

  Future<Map<String, dynamic>> patchJson(String path, Map<String, dynamic> body) async {
    final r = await http.patch(
      _uri(path),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode(body),
    );
    final map = _decodeObj(r.body);
    if (r.statusCode >= 400) {
      throw Exception(map['message']?.toString() ?? r.body);
    }
    final data = map['data'];
    if (data is Map<String, dynamic>) return data;
    throw Exception('Invalid patch response');
  }

  Future<void> delete(String path) async {
    final r = await http.delete(_uri(path), headers: {'Accept': 'application/json'});
    if (r.statusCode >= 400) {
      final map = _tryDecode(r.body);
      throw Exception(map?['message']?.toString() ?? r.body);
    }
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      final v = jsonDecode(body);
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}
    return null;
  }
}
