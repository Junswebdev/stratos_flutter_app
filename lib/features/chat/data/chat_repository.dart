import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/dio_client.dart';
import '../../../data/json_parsing.dart';
import '../../../core/socket_service.dart';

import 'package:stratos_app/features/auth/presentation/controllers/auth_controller.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  // Watch auth state to ensure repository is recreated on logout/login
  ref.watch(authControllerProvider);
  return ChatRepository(
    ref.watch(dioClientProvider),
    ref.watch(socketServiceProvider),
  );
});

class ChatMessage {
  final String id;
  final String senderId;
  final String? senderName;
  final String? senderAvatarUrl;
  final String content;
  final DateTime timestamp;
  final String? courseId;
  final String? recipientId;
  final String? replyToId;
  final ChatMessageReply? replyTo;
  final DateTime? isEdited;
  final DateTime? isDeleted;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentType;
  final List<String> likes;
  final List<String> dislikes;

  const ChatMessage({
    required this.id,
    required this.senderId,
    this.senderName,
    this.senderAvatarUrl,
    required this.content,
    required this.timestamp,
    this.courseId,
    this.recipientId,
    this.replyToId,
    this.replyTo,
    this.isEdited,
    this.isDeleted,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentType,
    this.likes = const [],
    this.dislikes = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final likesList = json['likes'] as List? ?? [];
    final dislikesList = json['dislikes'] as List? ?? [];
    
    return ChatMessage(
      id: readString(json, const ['id', 'message_id']) ?? '',
      senderId: readString(json, const ['sender_id', 'senderId']) ?? '',
      senderName: readString(json, const ['sender_name', 'senderName']),
      senderAvatarUrl: readString(json, const ['sender_avatar_url', 'senderAvatarUrl']),
      content: readString(json, const ['content', 'message', 'text']) ?? '',
      timestamp: readDateTime(json, const ['timestamp', 'created_at', 'sent_at']) ?? DateTime.now(),
      courseId: readString(json, const ['course_id', 'courseId']),
      recipientId: readString(json, const ['recipient_id', 'recipientId']),
      replyToId: readString(json, const ['reply_to_id', 'replyToId']),
      replyTo: json['reply_to'] != null ? ChatMessageReply.fromJson(asJsonMap(json['reply_to'])) : null,
      isEdited: readDateTime(json, const ['is_edited', 'editedAt']),
      isDeleted: readDateTime(json, const ['is_deleted', 'deletedAt']),
      attachmentUrl: readString(json, const ['attachment_url', 'attachmentUrl']),
      attachmentName: readString(json, const ['attachment_name', 'attachmentName']),
      attachmentType: readString(json, const ['attachment_type', 'attachmentType']),
      likes: likesList.map((e) => e.toString()).toList(),
      dislikes: dislikesList.map((e) => e.toString()).toList(),
    );
  }
}

class ChatMessageReply {
  final String id;
  final String senderId;
  final String? senderName;
  final String? senderAvatarUrl;
  final String content;

  const ChatMessageReply({
    required this.id,
    required this.senderId,
    this.senderName,
    this.senderAvatarUrl,
    required this.content,
  });

  factory ChatMessageReply.fromJson(Map<String, dynamic> json) {
    return ChatMessageReply(
      id: readString(json, const ['id', 'message_id']) ?? '',
      senderId: readString(json, const ['sender_id', 'senderId']) ?? '',
      senderName: readString(json, const ['sender_name', 'senderName']),
      senderAvatarUrl: readString(json, const ['sender_avatar_url', 'senderAvatarUrl']),
      content: readString(json, const ['content', 'message', 'text']) ?? '',
    );
  }
}

class ChatHistory {
  final List<ChatMessage> messages;
  final DateTime? peerLastReadAt;

  const ChatHistory({required this.messages, this.peerLastReadAt});
}

class ChatRepository {
  final Dio _dio;
  final SocketService _socketService;

  ChatRepository(this._dio, this._socketService);

  Future<ChatHistory> getDirectMessages(String otherUserId) async {
    final response = await _dio.get<dynamic>('chat/history/direct/$otherUserId');
    final data = unwrapJsonMap(response.data);
    return ChatHistory(
      messages: asJsonMapList(data['messages']).map(ChatMessage.fromJson).toList(),
      peerLastReadAt: readDateTime(data, const ['peer_last_read_at']),
    );
  }

  Future<ChatHistory> getCourseMessages(String courseId) async {
    final response = await _dio.get<dynamic>('chat/history/course/$courseId');
    final data = unwrapJsonMap(response.data);
    return ChatHistory(
      messages: asJsonMapList(data['messages']).map(ChatMessage.fromJson).toList(),
      peerLastReadAt: readDateTime(data, const ['peer_last_read_at']),
    );
  }

  Future<List<Map<String, dynamic>>> getRecentConversations() async {
    final response = await _dio.get<dynamic>('chat/recent');
    return asJsonMapList(response.data);
  }

  Future<List<Map<String, dynamic>>> getContacts({String? query}) async {
    final response = await _dio.get<dynamic>(
      'users/contacts',
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    return asJsonMapList(response.data);
  }

  Future<void> markAsRead(String courseId) async {
    await _dio.post<dynamic>('chat/mark_read/$courseId');
  }

  Future<void> markDirectAsRead(String otherUserId) async {
    await _dio.post<dynamic>('chat/mark_direct_read/$otherUserId');
  }

  Stream<ChatMessage> get messageStream {
    return _socketService.eventStream
        .where((event) {
          final type = event['type'] as String?;
          return type == 'message' || type == 'reaction' || type == 'edit' || type == 'delete';
        })
        .map((event) => ChatMessage.fromJson(event));
  }

  void sendMessage({
    required String content,
    String? courseId,
    String? recipientId,
    String? replyToId,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
  }) {
    final payload = {
      'type': 'message',
      'content': content,
      if (courseId != null) 'course_id': courseId,
      if (recipientId != null) 'recipient_id': recipientId,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      if (attachmentName != null) 'attachment_name': attachmentName,
      if (attachmentType != null) 'attachment_type': attachmentType,
    };
    _socketService.sendRaw(jsonEncode(payload));
  }

  Future<ChatMessage> sendAttachmentMessage({
    required List<int> fileBytes,
    required String fileName,
    String? content,
    String? courseId,
    String? recipientId,
    String? replyToId,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      'content': content ?? '',
      if (courseId != null) 'course_id': courseId,
      if (recipientId != null) 'recipient_id': recipientId,
      if (replyToId != null) 'reply_to_id': replyToId,
    });

    final response = await _dio.post<dynamic>('chat/attachment', data: formData);
    if (response.statusCode == null || response.statusCode! >= 400) {
      throw Exception('Failed to send attachment');
    }
    return ChatMessage.fromJson(asJsonMap(response.data));
  }

  void editMessage({
    required String messageId,
    required String content,
  }) {
    final payload = {
      'type': 'edit',
      'message_id': messageId,
      'content': content,
    };
    _socketService.sendRaw(jsonEncode(payload));
  }

  void deleteMessage(String messageId) {
    final payload = {
      'type': 'delete',
      'message_id': messageId,
    };
    _socketService.sendRaw(jsonEncode(payload));
  }

  void sendReaction({
    required String messageId,
    required String reactionType,
  }) {
    final payload = {
      'type': 'reaction',
      'message_id': messageId,
      'reaction': reactionType,
    };
    _socketService.sendRaw(jsonEncode(payload));
  }
}
