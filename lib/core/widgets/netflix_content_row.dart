import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/dio_client.dart';
import 'minimalist_widgets.dart';

class NetflixContentRow<T> extends StatelessWidget {
  const NetflixContentRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    required this.itemBuilder,
    this.onSeeAll,
    this.height = 180,
    this.cardWidth = 160,
  });

  final String title;
  final String? subtitle;
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final VoidCallback? onSeeAll;
  final double height;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title, 
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: isDark ? theme.colorScheme.onSurface : Colors.black,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!, 
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'View All', 
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black, 
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: isDark ? Colors.white : Colors.black),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              return SizedBox(
                width: cardWidth,
                child: itemBuilder(context, items[index], index),
              );
            },
          ),
        ),
      ],
    );
  }
}

class NetflixPosterCard extends ConsumerWidget {
  const NetflixPosterCard({
    super.key,
    required this.title,
    this.subtitle,
    this.gradientColors,
    this.imageUrl,
    this.onTap,
    this.topWidget,
    this.bottomWidget,
    this.trailing,
    this.showPlayButton = false,
  });

  final String title;
  final String? subtitle;
  final List<Color>? gradientColors;
  final String? imageUrl;
  final VoidCallback? onTap;
  final Widget? topWidget;
  final Widget? bottomWidget;
  final Widget? trailing;
  final bool showPlayButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = (gradientColors?.isNotEmpty ?? false)
        ? gradientColors!.first
        : theme.colorScheme.primary;

    final serverBaseUrl = ref.watch(serverBaseUrlProvider);
    final fullImageUrl = imageUrl != null && imageUrl!.isNotEmpty
        ? (imageUrl!.startsWith('http') ? imageUrl! : '$serverBaseUrl$imageUrl')
        : null;

    return MinimalContainer(
      borderRadius: 32,
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with image
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: isDark ? Colors.white10 : accent.withValues(alpha: 0.05),
                    ),
                    child: fullImageUrl != null
                        ? Image.network(
                            fullImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, color: accent.withValues(alpha: 0.5)),
                          )
                        : Icon(
                            showPlayButton ? Icons.play_circle_outline : Icons.auto_stories_outlined,
                            color: isDark ? theme.colorScheme.primary : accent,
                            size: 32,
                          ),
                  ),
                  if (topWidget != null)
                    Positioned(left: 16, top: 16, right: 16, child: topWidget!),
                ],
              ),
            ),
            // Content
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? theme.colorScheme.onSurface : Colors.black,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? theme.colorScheme.primary : Colors.black54,
                        ),
                      ),
                    ],
                    if (bottomWidget != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: bottomWidget!,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NetflixStatCard extends StatelessWidget {
  const NetflixStatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = color ?? theme.colorScheme.primary;

    return MinimalContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      borderRadius: 20,
      child: Row(
        children: [
          MinimalContainer(
            padding: const EdgeInsets.all(12),
            borderRadius: 14,
            color: accentColor.withValues(alpha: 0.1),
            showBorder: false,
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
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
