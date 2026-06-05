Map<String, dynamic> asStringKeyedMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, dynamic item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

Map<String, dynamic> asJsonMap(dynamic value) => asStringKeyedMap(value);

Map<String, dynamic> unwrapJsonMap(dynamic value) {
  final map = asStringKeyedMap(value);
  if (map.isEmpty) {
    return map;
  }

  for (final key in const ['data', 'result', 'payload', 'item']) {
    final nested = map[key];
    if (nested is Map) {
      final nestedMap = asStringKeyedMap(nested);
      if (nestedMap.isNotEmpty) {
        return nestedMap;
      }
    }
  }

  return map;
}

List<dynamic> asJsonList(dynamic value) {
  if (value is List) {
    return value;
  }
  final map = asStringKeyedMap(value);
  for (final key in const ['data', 'results', 'items', 'list', 'payload', 'result']) {
    final nested = map[key];
    if (nested is List) {
      return nested;
    }
  }
  return const [];
}

List<Map<String, dynamic>> asJsonMapList(dynamic value) {
  return asJsonList(value)
      .whereType<dynamic>()
      .map(asStringKeyedMap)
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

dynamic readJsonValue(Map<String, dynamic> json, Iterable<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key) && json[key] != null) {
      return json[key];
    }
  }

  for (final envelopeKey in const ['data', 'result', 'payload', 'item']) {
    final nested = json[envelopeKey];
    if (nested is Map) {
      final nestedMap = asStringKeyedMap(nested);
      final nestedValue = readJsonValue(nestedMap, keys);
      if (nestedValue != null) {
        return nestedValue;
      }
    }
  }

  return null;
}

String? readString(Map<String, dynamic> json, Iterable<String> keys) {
  final value = readJsonValue(json, keys);
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  return value.toString();
}

int? readInt(Map<String, dynamic> json, Iterable<String> keys) {
  final value = readJsonValue(json, keys);
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}

double? readDouble(Map<String, dynamic> json, Iterable<String> keys) {
  final value = readJsonValue(json, keys);
  if (value == null) {
    return null;
  }
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

bool? readBool(Map<String, dynamic> json, Iterable<String> keys) {
  final value = readJsonValue(json, keys);
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  final normalized = value.toString().trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }
  if (const ['true', '1', 'yes', 'y'].contains(normalized)) {
    return true;
  }
  if (const ['false', '0', 'no', 'n'].contains(normalized)) {
    return false;
  }
  return null;
}

DateTime? readDateTime(Map<String, dynamic> json, Iterable<String> keys) {
  final value = readJsonValue(json, keys);
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  final text = value.toString().trim();
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
}

Map<String, dynamic> toJsonMap(Map<String, dynamic> json) {
  return Map<String, dynamic>.from(json);
}