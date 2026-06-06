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

class ChattingWithNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void update(String? value) => state = value;
}

final chattingWithProvider = NotifierProvider<ChattingWithNotifier, String?>(() {
  return ChattingWithNotifier();
});

/// Global stream of raw websocket events
final socketEventStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final service = ref.watch(socketServiceProvider);
  return service.eventStream;
});

class SocketService {
  final Ref _ref;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  bool _isConnecting = false;

  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

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

  String? _currentUserId;

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
      _currentUserId = user.id;
      
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
      _eventController.add(json);
      
      final type = json['type'] as String?;

      if (type == 'stats_update') {
        final statsJson = json['data'] as Map<String, dynamic>;
        final stats = DashboardStats.fromJson(statsJson);
        _ref.read(statsProvider.notifier).updateStats(stats);
        
        // Auto-refresh the entire dashboard (enrollments, announcements, courses)
        _ref.invalidate(dashboardProvider);
      } else if (type == 'message') {
        final senderId = json['sender_id'] as String?;
        final senderName = json['sender_name'] ?? 'Someone';
        final content = json['content'] ?? '';
        final courseId = json['course_id'] as String?;

        // Don't notify if I am the sender
        if (senderId == _currentUserId) return;

        // Don't notify if I am currently in the chat with this person/course
        final currentChat = _ref.read(chattingWithProvider);
        if (currentChat != null) {
          if (courseId == currentChat || senderId == currentChat) {
            return;
          }
        }
        
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('New message from $senderName: $content'),
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

  void sendRaw(String data) {
    _channel?.sink.add(data);
  }
}

final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService(ref);
});
