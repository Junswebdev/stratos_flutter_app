import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/auth/domain/user_model.dart';
import '../../../../features/home/application/home_providers.dart';
import '../../../../core/theme.dart';
import '../../data/course_repository.dart';

class CreateCourseScreen extends ConsumerStatefulWidget {
  const CreateCourseScreen({super.key});

  @override
  ConsumerState<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends ConsumerState<CreateCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  EduLevel _eduLevel = EduLevel.higherEd;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _imageUrlController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final profile = ref.read(profileProvider).asData?.value;
      await ref.read(courseRepositoryProvider).createCourse(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        eduLevel: _eduLevel,
        instructorId: profile?.id ?? '',
        imageUrl: _imageUrlController.text.trim().isNotEmpty
            ? _imageUrlController.text.trim()
            : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Academy created successfully!')),
      );
      ref.invalidate(coursesProvider);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create academy: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final imageUrl = _imageUrlController.text.trim();
    final hasImage = imageUrl.isNotEmpty && imageUrl.startsWith('http');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Academy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thumbnail preview
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkCard
                      : theme.colorScheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: hasImage
                        ? Colors.transparent
                        : theme.colorScheme.outline,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasImage
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => _buildImagePlaceholder(theme),
                      )
                    : _buildImagePlaceholder(theme),
              ),

              const SizedBox(height: 16),

              // Image URL field
              TextFormField(
                controller: _imageUrlController,
                decoration: InputDecoration(
                  labelText: 'Thumbnail URL (optional)',
                  hintText: 'https://example.com/image.jpg',
                  prefixIcon: Icon(Icons.link_rounded,
                      color: theme.colorScheme.onSurfaceVariant),
                  suffixIcon: hasImage
                      ? Icon(Icons.check_circle_rounded,
                          color: AppColors.success)
                      : null,
                ),
                keyboardType: TextInputType.url,
              ),

              const SizedBox(height: 8),

              Text(
                'Leave blank to auto-generate a thumbnail using AI.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 28),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Academy Title'),
                style: const TextStyle(fontWeight: FontWeight.w700),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),

              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),

              const SizedBox(height: 16),

              // Education level
              DropdownButtonFormField<EduLevel>(
                value: _eduLevel,
                decoration: const InputDecoration(labelText: 'Education Level'),
                items: const [
                  DropdownMenuItem(value: EduLevel.primary, child: Text('Primary')),
                  DropdownMenuItem(value: EduLevel.secondary, child: Text('Secondary')),
                  DropdownMenuItem(value: EduLevel.higherEd, child: Text('Higher Education')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _eduLevel = v);
                },
              ),

              const SizedBox(height: 32),

              // Submit button
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Create Academy',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 48,
          color: theme.colorScheme.primary.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 12),
        Text(
          'Paste an image URL below',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'or leave blank for AI thumbnail',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
