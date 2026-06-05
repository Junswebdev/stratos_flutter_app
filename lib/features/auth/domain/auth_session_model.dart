import '../../../data/json_parsing.dart';
import 'user_model.dart';

class AuthSessionModel {
  final String accessToken;
  final String? refreshToken;
  final String? tokenType;
  final UserModel? user;
  final DateTime? expiresAt;

  const AuthSessionModel({
    required this.accessToken,
    this.refreshToken,
    this.tokenType,
    this.user,
    this.expiresAt,
  });

  factory AuthSessionModel.fromJson(dynamic source) {
    final json = unwrapJsonMap(source);

    var userValue = readJsonValue(json, const ['user', 'me', 'current_user', 'currentUser']);
    
    // Fallback: If no explicit user key is found, check if the root object itself 
    // looks like a user (has 'email' and 'id' or 'uuid').
    if (userValue == null && 
        (json.containsKey('email') || json.containsKey('email_address')) && 
        (json.containsKey('id') || json.containsKey('uuid'))) {
      userValue = json;
    }

    return AuthSessionModel(
      accessToken: readString(json, const ['access_token', 'accessToken', 'token']) ?? '',
      refreshToken: readString(json, const ['refresh_token', 'refreshToken']),
      tokenType: readString(json, const ['token_type', 'tokenType']),
      user: userValue == null ? null : UserModel.fromJson(userValue),
      expiresAt: readDateTime(json, const ['expires_at', 'expiresAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'user': user?.toJson(),
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  AuthSessionModel copyWith({
    String? accessToken,
    String? refreshToken,
    String? tokenType,
    UserModel? user,
    DateTime? expiresAt,
  }) {
    return AuthSessionModel(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenType: tokenType ?? this.tokenType,
      user: user ?? this.user,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}