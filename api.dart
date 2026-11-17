import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiError implements Exception {
  final String message;
  final String? field;
  final int? status;
  ApiError(this.message, [this.field, this.status]);
  @override
  String toString() => message;
}

String money(num v) {
  final s = v.round().toString();
  final r = s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  return '\$$r';
}

class Product {
  final int id;
  final String name, category, description, image;
  final num price;
  Product(this.id, this.name, this.category, this.description, this.image, this.price);
  factory Product.fromJson(Map<String, dynamic> j) =>
      Product(j['id'], j['name'], j['category'], j['description'], j['image'], j['price']);
}

class User {
  final String id, nombre, apellidos, username, email;
  User(this.id, this.nombre, this.apellidos, this.username, this.email);
  factory User.fromJson(Map<String, dynamic> j) =>
      User(j['id'], j['nombre'], j['apellidos'], j['username'], j['email']);
  String get full => '$nombre $apellidos';
  String get initials =>
      '${nombre.isNotEmpty ? nombre[0] : ''}${apellidos.isNotEmpty ? apellidos[0] : ''}'.toUpperCase();
}

class Api {
  static String? token;

  static Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$apiUrl$path');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    http.Response r;
    try {
      final Future<http.Response> req = method == 'GET'
          ? http.get(uri, headers: headers)
          : method == 'POST'
              ? http.post(uri, headers: headers, body: jsonEncode(body ?? {}))
              : http.put(uri, headers: headers, body: jsonEncode(body ?? {}));
      r = await req.timeout(const Duration(seconds: 60));
    } catch (_) {
      throw ApiError('No se pudo conectar con el servidor');
    }
    final data = r.body.isEmpty ? null : jsonDecode(r.body);
    if (r.statusCode >= 400) {
      final m = data is Map ? data : {};
      throw ApiError((m['error'] ?? 'Error ${r.statusCode}').toString(), m['field']?.toString(), r.statusCode);
    }
    return data;
  }

  static Future<dynamic> get(String p) => _send('GET', p);
  static Future<dynamic> post(String p, Map<String, dynamic> b) => _send('POST', p, b);
  static Future<dynamic> put(String p, Map<String, dynamic> b) => _send('PUT', p, b);
}
