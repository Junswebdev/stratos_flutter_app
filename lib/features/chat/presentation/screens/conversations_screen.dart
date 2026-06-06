import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/user_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../home/application/home_providers.dart';
import '../../data/chat_repository.dart';

final conversationsProvider = FutureProvider<List<ConversationSummary>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  if (authState.isLoading || authState.value?.isAuthenticated != true) return const [];
  
  final repository = ref.watch(chatRepositoryProvider);
  final rawData = await repository.getRecentConversations();

  return rawData.map((json) => ConversationSummary.fromJson(json)).toList();
});

final contactsProvider = FutureProvider<List<UserModel>>((ref) async {
  final repository = ref.watch(authRepositoryProvider);
  return repository.fetchContacts();
});

class ConversationSummary {
  final String id;
  final String title;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final String? courseId;
  final String? recipientId;
  final String? courseName;
  final String senderName;
  final String conversationType;

  ConversationSummary({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.courseId,
    this.recipientId,
    this.courseName,
    required this.senderName,
    this.conversationType = 'course',
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Conversation',
      lastMessage: json['last_message']?.toString() ?? '',
      lastMessageTime: DateTime.tryParse(json['last_message_time']?.toString() ?? '') ?? DateTime.now(),
      unreadCount: int.tryParse(json['unread_count']?.toString() ?? '0') ?? 0,
      courseId: json['course_id']?.toString(),
      recipientId: json['recipient_id']?.toString(),
      courseName: json['course_name']?.toString() ?? json['title']?.toString(),
      senderName: json['sender_name']?.toString() ?? 'Someone',
      conversationType: json['conversation_type']?.toString() ?? (json['course_id'] == null ? 'direct' : 'course'),
    );
  }

  bool get isDirect => conversationType == 'direct';
}

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'New direct message',
            onPressed: () => _showNewMessageSheet(context, ref),
          ),
        ],
      ),
      body: conversationsAsync.when(
        data: (conversations) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(conversationsProvider),
          child: conversations.isEmpty
              ? _buildEmptyState(context, ref)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final convo = conversations[index];
                    return _ConversationTile(convo: convo, isDark: isDark);
                  },
                ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.25)),
            const SizedBox(height: 16),
            Text('No conversations yet', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Start a course discussion or message someone directly.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _showNewMessageSheet(context, ref),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('New Direct Message'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNewMessageSheet(BuildContext context, WidgetRef ref) async {
    final searchController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Consumer(
            builder: (context, ref, _) {
              final contactsAsync = ref.watch(contactsProvider);
              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start a direct message', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search people',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (_) => ref.invalidate(contactsProvider),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: contactsAsync.when(
                        data: (contacts) {
                          final query = searchController.text.trim().toLowerCase();
                          final filtered = contacts.where((user) {
                            if (query.isEmpty) return true;
                            final name = (user.fullName ?? '').toLowerCase();
                            final email = user.email.toLowerCase();
                            return name.contains(query) || email.contains(query);
                          }).toList();

                          if (filtered.isEmpty) {
                            return const Center(child: Text('No matching users'));
                          }

                          return ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (itemContext, index) {
                              final user = filtered[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  child: Text(_initial(user), style: const TextStyle(fontWeight: FontWeight.w800)),
                                ),
                                title: Text(user.fullName?.isNotEmpty == true ? user.fullName! : user.email),
                                subtitle: Text(user.email),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  context.pushNamed(
                                    'direct_chat',
                                    pathParameters: {'userId': user.id},
                                    extra: user.fullName?.isNotEmpty == true ? user.fullName : user.email,
                                  );
                                },
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Error: $e')),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    searchController.dispose();
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.convo, required this.isDark});

  final ConversationSummary convo;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(convo.lastMessageTime);
    final isUnread = convo.unreadCount > 0;
    final isDirect = convo.isDirect;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Consumer(
        builder: (context, ref, child) {
          return ListTile(
            onTap: () async {
              if (convo.courseId != null) {
                await ref.read(chatRepositoryProvider).markAsRead(convo.courseId!);
                ref.invalidate(conversationsProvider);
                ref.invalidate(statsProvider);
                if (context.mounted) {
                  context.pushNamed('course_chat', pathParameters: {'courseId': convo.courseId!}, extra: convo.courseName);
                }
              } else if (convo.recipientId != null) {
                await ref.read(chatRepositoryProvider).markDirectAsRead(convo.recipientId!);
                ref.invalidate(conversationsProvider);
                ref.invalidate(statsProvider);
                if (context.mounted) {
                  context.pushNamed(
                    'direct_chat',
                    pathParameters: {'userId': convo.recipientId!},
                    extra: convo.title,
                  );
                }
              }
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: (isDirect ? Colors.blueGrey : AppColors.primary).withValues(alpha: 0.1),
                  child: Icon(
                    isDirect ? Icons.person_rounded : Icons.school_rounded,
                    color: isDirect ? Colors.blueGrey : AppColors.primary,
                  ),
                ),
                if (isUnread)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: AppColors.netflixRed, shape: BoxShape.circle),
                      child: Text(
                        '${convo.unreadCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    convo.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.w600, fontSize: 16),
                  ),
                ),
                Text(timeStr, style: TextStyle(fontSize: 12, color: isUnread ? AppColors.primary : Colors.grey)),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${convo.senderName == ref.read(profileProvider).value?.displayName ? 'You' : convo.senderName}: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isUnread ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                          ),
                        ),
                        if (convo.senderName == ref.read(profileProvider).value?.displayName)
                          const WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.only(right: 4.0),
                              child: Icon(Icons.done_all_rounded, size: 12, color: Colors.grey),
                            ),
                          ),
                        TextSpan(
                          text: convo.lastMessage,
                          style: TextStyle(
                            color: isUnread ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      isDirect ? 'Direct Message' : 'Course Group Chat',
                      style: TextStyle(
                        fontSize: 11,
                        color: (isDirect ? Colors.blueGrey : AppColors.primary).withValues(alpha: 0.8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return DateFormat('MMM d').format(dt);
  }
}

String _initial(UserModel user) {
  final name = user.fullName?.trim();
  if (name != null && name.isNotEmpty) return name[0].toUpperCase();
  return user.email.isNotEmpty ? user.email[0].toUpperCase() : 'U';
}
