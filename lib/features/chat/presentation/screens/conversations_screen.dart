import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme.dart';
import '../../../../core/widgets/minimalist_widgets.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/user_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../home/application/home_providers.dart';
import '../../../home/presentation/widgets/async_state_view.dart';
import '../../data/chat_repository.dart';

final conversationsProvider = FutureProvider<List<ConversationSummary>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  if (authState.isLoading || authState.value?.isAuthenticated != true) return const [];
  
  final repository = ref.watch(chatRepositoryProvider);
  final rawData = await repository.getRecentConversations();

  return rawData
      .map((json) => ConversationSummary.fromJson(json))
      .where((convo) {
        final title = convo.title.toLowerCase();
        final sender = convo.senderName.toLowerCase();
        // Filter out placeholder/test conversations
        return !title.contains('test') && 
               !title.contains('example') && 
               title != 'string' &&
               !sender.contains('stratos tester') &&
               sender != 'string';
      })
      .toList();
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_rounded, size: 20),
            onPressed: () => _showNewMessageSheet(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AsyncStateView(
        isLoading: conversationsAsync.isLoading,
        hasError: conversationsAsync.hasError,
        errorMessage: conversationsAsync.error?.toString(),
        onRetry: () => ref.invalidate(conversationsProvider),
        loadingLabel: 'Loading your messages...',
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(conversationsProvider),
          child: (conversationsAsync.value == null || conversationsAsync.value!.isEmpty)
              ? _buildEmptyState(context, ref)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  itemCount: conversationsAsync.value!.length,
                  itemBuilder: (context, index) {
                    final convo = conversationsAsync.value![index];
                    return _ConversationTile(convo: convo);
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.forum_outlined, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const Text('No conversations yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Stay connected with your classmates and instructors.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            MinimalButton(
              width: 220,
              onPressed: () => _showNewMessageSheet(context, ref),
              child: const Text('Start Messaging'),
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
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (ctx, scrollController) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('New Message', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (_) => ref.invalidate(contactsProvider),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final contactsAsync = ref.watch(contactsProvider);
                      return contactsAsync.when(
                        data: (contacts) {
                          final query = searchController.text.trim().toLowerCase();
                          final filtered = contacts.where((user) {
                            // Filter out test/placeholder accounts
                            final email = user.email.toLowerCase();
                            final name = (user.fullName ?? '').toLowerCase();
                            if (email.contains('test.com') || 
                                email.contains('example.com') || 
                                name == 'string' ||
                                name.contains('stratos tester')) {
                              return false;
                            }

                            if (query.isEmpty) return true;
                            return name.contains(query) || email.contains(query);
                          }).toList();

                          if (filtered.isEmpty) return const Center(child: Text('No results found.'));

                          return ListView.builder(
                            controller: scrollController,
                            itemCount: filtered.length,
                            itemBuilder: (itemContext, index) {
                              final user = filtered[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                leading: SafeAvatar(radius: 20, imageUrl: user.avatarUrl, fallbackText: _initial(user)),
                                title: Text(user.fullName ?? user.email, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(user.email, style: const TextStyle(fontSize: 12)),
                                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  context.pushNamed(
                                    'direct_chat',
                                    pathParameters: {'userId': user.id},
                                    extra: user.fullName ?? user.email,
                                  );
                                },
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Error: $e')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    searchController.dispose();
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.convo});

  final ConversationSummary convo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isUnread = convo.unreadCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isUnread ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border)),
      ),
      child: ListTile(
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
                context.pushNamed('direct_chat', pathParameters: {'userId': convo.recipientId!}, extra: convo.title);
              }
            }
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Stack(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: convo.isDirect ? AppColors.primary.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                convo.isDirect ? Icons.person_outline_rounded : Icons.school_outlined,
                color: convo.isDirect ? AppColors.primary : Colors.black54,
              ),
            ),
            if (isUnread)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? AppColors.darkSurface : Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(child: Text(convo.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
            Text(_formatTime(convo.lastMessageTime), style: TextStyle(fontSize: 10, color: isUnread ? AppColors.primary : theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${convo.senderName}: ${convo.lastMessage}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isUnread ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (isUnread)
                Container(
                  margin: const EdgeInsets.only(left: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                  child: Text('${convo.unreadCount}', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  return DateFormat('MMM d').format(dt);
}

String _initial(UserModel user) {
  final name = user.fullName?.trim();
  if (name != null && name.isNotEmpty) return name[0].toUpperCase();
  return user.email.isNotEmpty ? user.email[0].toUpperCase() : 'U';
}
