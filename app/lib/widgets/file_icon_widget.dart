import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../ui/app_ui.dart';
import '../utils/file_utils.dart';

class FileIconWidget extends StatelessWidget {
  final FileCategory category;
  final double size;
  final String? filePath;

  const FileIconWidget({
    super.key,
    required this.category,
    this.size = 40,
    this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    final cornerRadius = size < 36 ? 8.0 : AppRadius.sm;

    if (category == FileCategory.image && filePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(cornerRadius),
        child: SizedBox(
          width: size,
          height: size,
          child: Image.file(
            File(filePath!),
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: (size * 2).toInt(),
            errorBuilder: (_, __, ___) => _buildIconFallback(context),
          ),
        ),
      );
    }

    return _buildIconFallback(context);
  }

  Widget _buildIconFallback(BuildContext context) {
    final (IconData icon, Color rawColor) = iconData(category);
    final color = category == FileCategory.other
        ? context.appColors.textSecondary
        : rawColor;
    final cornerRadius = size < 36 ? 8.0 : AppRadius.sm;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(cornerRadius),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 1),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }

  static (IconData, Color) iconData(FileCategory category) {
    return switch (category) {
      FileCategory.image => (LucideIcons.image, const Color(0xFF6FBBE8)),
      FileCategory.video => (LucideIcons.video, const Color(0xFFE88B5A)),
      FileCategory.audio => (
        LucideIcons.music,
        const Color(0xFFEABD3B),
      ),
      FileCategory.pdf => (
        LucideIcons.fileText,
        const Color(0xFFE05252),
      ),
      FileCategory.archive => (
        LucideIcons.fileArchive,
        const Color(0xFFA77BCA),
      ),
      FileCategory.document => (
        LucideIcons.fileText,
        const Color(0xFF45B7AA),
      ),
      FileCategory.code => (LucideIcons.code, const Color(0xFF66C088)),
      FileCategory.other => (
        LucideIcons.file,
        const Color(0xFF8B95A5),
      ),
    };
  }
}
