import 'package:flutter/material.dart';

class AsyncStateView extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.child,
    required this.loadingLabel,
    this.errorMessage,
    this.onRetry,
    this.emptyMessage,
    this.emptyIcon = Icons.inbox_outlined,
    this.isLoading = false,
    this.hasError = false,
    this.isEmpty = false,
  });

  final Widget child;
  final String loadingLabel;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final String? emptyMessage;
  final IconData emptyIcon;
  final bool isLoading;
  final bool hasError;
  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _StateCard(
        icon: const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        title: loadingLabel,
        message: 'Please wait while we load your content.',
        action: onRetry == null
            ? null
            : TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
      );
    }

    if (hasError) {
      return _StateCard(
        icon: const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
        title: 'Something went wrong',
        message: errorMessage ?? 'We could not load this section.',
        action: onRetry == null
            ? null
            : OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
      );
    }

    if (isEmpty) {
      return _StateCard(
        icon: Icon(emptyIcon, color: Theme.of(context).colorScheme.primary, size: 36),
        title: 'Nothing here yet',
        message: emptyMessage ?? 'This section is empty.',
      );
    }

    return child;
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final Widget icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (action != null) ...[
                    const SizedBox(height: 16),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}