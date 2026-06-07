import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../data/course_repository.dart';
import '../../../../core/theme.dart';
import '../../../../features/home/application/home_providers.dart';

class AIAssistantScreen extends ConsumerStatefulWidget {
  const AIAssistantScreen({super.key, required this.courseId, required this.courseTitle});

  final String courseId;
  final String courseTitle;

  @override
  ConsumerState<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends ConsumerState<AIAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  static const List<String> _suggestions = [
    'Summarize the key ideas',
    'Quiz me on this lesson',
    'Explain it in simple terms',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(
      text: "Hi! I'm your Class IQ AI assistant for **${widget.courseTitle}**. Ask me anything about the course material!",
      isAi: true,
      isStreaming: false,
    ));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isAi: false));
      _controller.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final answer = await ref.read(courseRepositoryProvider).askAI(
        courseId: widget.courseId,
        question: text,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _messages.add(_ChatMessage(text: "", isAi: true, isStreaming: true));
        });
        _scrollToBottom();
        _streamText(answer);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(text: "Sorry, I couldn't process that. Make sure your MISTRAL_API_KEY is set up correctly in the backend .env file.", isAi: true));
          _isLoading = false;
        });
      }
    }
    _scrollToBottom();
  }

  void _streamText(String fullText) async {
    final words = fullText.split(' ');
    String currentText = "";
    final int messageIndex = _messages.length - 1;

    for (var i = 0; i < words.length; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      if (!mounted) return;
      
      currentText += (i == 0 ? "" : " ") + words[i];
      setState(() {
        _messages[messageIndex] = _ChatMessage(
          text: currentText, 
          isAi: true, 
          isStreaming: i < words.length - 1
        );
      });
      _scrollToBottom();
    }
  }

  void _clearChat() {
    setState(() {
      _messages
        ..clear()
        ..add(_ChatMessage(
          text: "Hi! I'm your Class IQ AI assistant for **${widget.courseTitle}**. Ask me anything about the course material!",
          isAi: true,
          isStreaming: false,
        ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accentColor = AppColors.primary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("AI Learning Companion", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            Text(widget.courseTitle, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black45, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reset Session',
            onPressed: _clearChat,
            icon: const Icon(Icons.auto_awesome_motion_rounded, size: 20),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _ChatBubble(message: msg);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(left: 24, bottom: 24),
              child: _ThinkingIndicator(),
            ),
          
          Container(
            padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBackground : AppColors.background,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_messages.length <= 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _suggestions
                            .map(
                              (text) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ActionChip(
                                  label: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  onPressed: () {
                                    _controller.text = text;
                                    _sendMessage();
                                  },
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.attach_file_rounded, size: 20),
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          onSubmitted: (_) => _sendMessage(),
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "How can I help with this course?",
                            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: _sendMessage,
                          icon: const Icon(Icons.arrow_upward_rounded, color: AppColors.primary, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isAi;
  final bool isStreaming;
  _ChatMessage({required this.text, required this.isAi, this.isStreaming = false});
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAi = message.isAi;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isAi) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                  children: [
                    Text(
                      isAi ? "CLASS IQ AI" : "YOU",
                      style: TextStyle(
                        fontSize: 9, 
                        fontWeight: FontWeight.w900, 
                        letterSpacing: 1.2,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isAi 
                          ? (isDark ? AppColors.darkSurface : Colors.white)
                          : AppColors.primary,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isAi ? 4 : 16),
                          bottomRight: Radius.circular(isAi ? 16 : 4),
                        ),
                        border: isAi ? Border.all(color: isDark ? AppColors.darkBorder : AppColors.border) : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isAi 
                        ? MarkdownBody(
                            data: message.text,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 14,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                              code: TextStyle(
                                backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                              ),
                            ),
                          )
                        : Text(
                            message.text,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                    ),
                  ],
                ),
              ),
              if (!isAi) ...[
                const SizedBox(width: 12),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: Colors.black,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator();

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final value = ( (_controller.value + delay) % 1.0 );
            final verticalOffset = -4 * (1.0 - (value - 0.5).abs() * 2);
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, verticalOffset),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
