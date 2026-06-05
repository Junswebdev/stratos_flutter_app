import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../features/chat/presentation/screens/conversations_screen.dart';
import '../features/home/application/home_providers.dart';
import '../features/home/data/home_api_client.dart';
import '../features/home/data/home_models.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/data/auth_repository.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class SocketService {
  final Ref _ref;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  bool _isConnecting = false;

  SocketService(this._ref) {
    // Listen for auth state changes to connect/disconnect
    _ref.listen(authControllerProvider, (previous, next) {
      if (next.isLoading) return;
      
      final state = next.value;
      if (state?.isAuthenticated == true) {
        _connect();
      } else {
        _disconnect();
      }
    });
  }

  Future<void> _connect() async {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;

    try {
      final repository = _ref.read(authRepositoryProvider);
      final token = await repository.accessToken();
      
      if (token == null) {
        _isConnecting = false;
        return;
      }

      final user = await repository.fetchMe();
      
      final dio = _ref.read(apiDioProvider);
      var wsUrl = dio.options.baseUrl
          .replaceFirst('https', 'wss')
          .replaceFirst('http', 'ws');
      
      final uri = Uri.parse(wsUrl);
      final rootWs = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
      final finalUrl = '$rootWs/ws/${user.id}?token=$token';

      _channel = WebSocketChannel.connect(Uri.parse(finalUrl));
      _isConnected = true;
      _isConnecting = false;

      _subscription = _channel!.stream.listen(
        (data) {
          _handleMessage(data as String);
        },
        onError: (error) {
          _reconnect();
        },
        onDone: () {
          _isConnected = false;
          _isConnecting = false;
        },
      );
    } catch (e) {
      _isConnected = false;
      _isConnecting = false;
      
      if (e.toString().contains('401')) {
         return;
      }
      _reconnect();
    }
  }

  void _handleMessage(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'stats_update') {
        final statsJson = json['data'] as Map<String, dynamic>;
        final stats = DashboardStats.fromJson(statsJson);
        _ref.read(statsProvider.notifier).updateStats(stats);
      } else if (type == 'message') {
        final sender = json['sender_name'] ?? 'Someone';
        final content = json['content'] ?? '';
        
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('New message from $sender: $content'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(label: 'VIEW', onPressed: () {}),
          ),
        );

        // Refresh the conversations list
        _ref.invalidate(conversationsProvider);
      }
    } catch (e) {
      // Error handling message
    }
  }

  void _reconnect() {
    _isConnected = false;
    Future.delayed(const Duration(seconds: 5), () {
      final auth = _ref.read(authControllerProvider).value;
      if (auth?.isAuthenticated == true) {
        _connect();
      }
    });
  }

  void _disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
  }
}

final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService(ref);
});
