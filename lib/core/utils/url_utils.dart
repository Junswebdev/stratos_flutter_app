import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/dio_client.dart';

String formatFullUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http')) return path;

  // We try to get the base server URL. 
  // Since we can't easily get the provider value without ref, 
  // we'll re-implement the logic or use a global variable if we had one.
  // For now, we'll use the same logic as in dio_client.dart but for the server root.
  
  String serverBase;
  const envUrl = String.fromEnvironment('API_BASE_URL');
  if (envUrl.isNotEmpty) {
    final uri = Uri.parse(envUrl);
    serverBase = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  } else if (kDebugMode) {
    serverBase = 'http://localhost:8000';
  } else {
    serverBase = 'https://stratos-fastapi-backend.onrender.com';
  }

  // Ensure we don't have double slashes
  final cleanPath = path.startsWith('/') ? path.substring(1) : path;
  final cleanBase = serverBase.endsWith('/') ? serverBase : '$serverBase/';

  return '$cleanBase$cleanPath';
}

final urlFormatterProvider = Provider((ref) {
  return formatFullUrl;
});

