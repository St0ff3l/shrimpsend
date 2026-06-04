import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:video_player/video_player.dart';

import '../typography.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/file_store.dart';
import '../ui/app_ui.dart';
import '../utils/file_utils.dart';
import '../utils/received_file_actions.dart';
import '../utils/text_bytes_decoder.dart';
import '../widgets/received_file_action_bar.dart';

bool isPreviewable(FileCategory category, String fileName) {
  switch (category) {
    case FileCategory.image:
    case FileCategory.video:
    case FileCategory.pdf:
    case FileCategory.code:
      return true;
    case FileCategory.document:
      final ext = fileName.split('.').last.toLowerCase();
      return const {'txt', 'md', 'csv', 'rtf', 'log'}.contains(ext);
    default:
      return false;
  }
}

class FilePreviewScreen extends StatefulWidget {
  final ReceivedFileInfo file;
  final bool forceText;
  final ReceivedFilePreviewCallbacks? callbacks;

  const FilePreviewScreen({
    super.key,
    required this.file,
    this.forceText = false,
    this.callbacks,
  });

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  bool _showActionBar = true;

  bool get _useDarkChrome =>
      !widget.forceText &&
      (widget.file.category == FileCategory.image ||
          widget.file.category == FileCategory.video);

  void _toggleActionBar() {
    setState(() => _showActionBar = !_showActionBar);
  }

  double _actionBarBottomInset(BuildContext context) {
    if (!_showActionBar) return 0;
    return kFilePreviewActionBarInset + MediaQuery.paddingOf(context).bottom;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    final isImage = widget.file.category == FileCategory.image;

    return Scaffold(
      backgroundColor: isImage ? Colors.black : null,
      appBar: AppBar(
        backgroundColor: isImage ? Colors.black : null,
        foregroundColor: isImage ? Colors.white : null,
        title: Text(
          widget.file.displayName,
          style: TextStyle(
            fontSize: 14,
            color: isImage ? Colors.white : colors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleActionBar,
              behavior: HitTestBehavior.translucent,
              child: _buildBody(context, l10n),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedSlide(
                    offset: _showActionBar ? Offset.zero : const Offset(0, 1.5),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: AnimatedOpacity(
                      opacity: _showActionBar ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: IgnorePointer(
                        ignoring: !_showActionBar,
                        child: ReceivedFileActionBar(
                          file: widget.file,
                          forceText: widget.forceText,
                          useDarkChrome: _useDarkChrome,
                          callbacks: widget.callbacks,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    final bottomInset = _actionBarBottomInset(context);

    if (widget.forceText) {
      return _TextPreview(filePath: widget.file.path, bottomInset: bottomInset);
    }

    switch (widget.file.category) {
      case FileCategory.image:
        return _ImagePreview(filePath: widget.file.path, l10n: l10n);
      case FileCategory.video:
        return _VideoPreview(
          filePath: widget.file.path,
          l10n: l10n,
          showOverlay: _showActionBar,
          bottomInset: bottomInset,
        );
      case FileCategory.pdf:
        return _PdfPreview(filePath: widget.file.path, bottomInset: bottomInset);
      case FileCategory.code:
        return _TextPreview(filePath: widget.file.path, bottomInset: bottomInset);
      case FileCategory.document:
        return _TextPreview(filePath: widget.file.path, bottomInset: bottomInset);
      default:
        return _TextPreview(filePath: widget.file.path, bottomInset: bottomInset);
    }
  }
}

// ---------------------------------------------------------------------------
// Image Preview
// ---------------------------------------------------------------------------

class _ImagePreview extends StatelessWidget {
  final String filePath;
  final AppLocalizations l10n;
  const _ImagePreview({required this.filePath, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5.0,
      child: Center(
        child: Image.file(
          File(filePath),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              _ErrorPlaceholder(message: l10n.filePreviewImageLoadError),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Video Preview
// ---------------------------------------------------------------------------

class _VideoPreview extends StatefulWidget {
  final String filePath;
  final AppLocalizations l10n;
  final bool showOverlay;
  final double bottomInset;

  const _VideoPreview({
    required this.filePath,
    required this.l10n,
    required this.showOverlay,
    required this.bottomInset,
  });

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.filePath))
      ..initialize()
          .then((_) {
            if (mounted) setState(() => _initialized = true);
          })
          .catchError((e) {
            if (mounted) {
              setState(() => _error = widget.l10n.filePreviewVideoError);
            }
          });
    _controller.addListener(_onPlayerUpdate);
  }

  void _onPlayerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      if (_controller.value.position >= _controller.value.duration) {
        _controller.seekTo(Duration.zero);
      }
      _controller.play();
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _ErrorPlaceholder(message: _error!);
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final value = _controller.value;
    final position = value.position;
    final duration = value.duration;

    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          if (widget.showOverlay) ...[
            GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  value.isPlaying ? LucideIcons.pause : LucideIcons.play,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: widget.bottomInset,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _formatDuration(position),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14,
                            ),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white.withValues(
                              alpha: 0.3,
                            ),
                            thumbColor: Colors.white,
                            overlayColor: Colors.white.withValues(
                              alpha: 0.15,
                            ),
                          ),
                          child: Slider(
                            value: duration.inMilliseconds > 0
                                ? position.inMilliseconds.toDouble().clamp(
                                    0,
                                    duration.inMilliseconds.toDouble(),
                                  )
                                : 0,
                            max: duration.inMilliseconds > 0
                                ? duration.inMilliseconds.toDouble()
                                : 1,
                            onChanged: (v) {
                              _controller.seekTo(
                                Duration(milliseconds: v.toInt()),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        _formatDuration(duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
  }
}

// ---------------------------------------------------------------------------
// PDF Preview
// ---------------------------------------------------------------------------

class _PdfPreview extends StatelessWidget {
  final String filePath;
  final double bottomInset;

  const _PdfPreview({required this.filePath, required this.bottomInset});

  @override
  Widget build(BuildContext context) {
    final extraPadding = bottomInset > 0 ? bottomInset + AppSpacing.sm : 0.0;
    return Padding(
      padding: EdgeInsets.only(bottom: extraPadding),
      child: PdfViewer.file(
        filePath,
        params: const PdfViewerParams(enableTextSelection: true),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Text / Code Preview
// ---------------------------------------------------------------------------

class _TextPreview extends StatefulWidget {
  final String filePath;
  final double bottomInset;

  const _TextPreview({required this.filePath, required this.bottomInset});

  @override
  State<_TextPreview> createState() => _TextPreviewState();
}

class _TextPreviewState extends State<_TextPreview> {
  Future<String>? _contentFuture;
  Locale? _loadLocale;

  static const _maxBytes = 2 * 1024 * 1024; // 2 MB

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (_loadLocale != locale) {
      _loadLocale = locale;
      _contentFuture = _loadContent(AppLocalizations.of(context));
    }
  }

  Future<String> _loadContent(AppLocalizations l10n) async {
    final file = File(widget.filePath);
    final stat = await file.stat();
    final truncated = stat.size > _maxBytes;
    final bytes = await readTextFileBytes(
      widget.filePath,
      maxBytes: _maxBytes,
    );
    final text = decodeTextBytes(bytes);
    return truncated ? l10n.filePreviewTextTruncated(text) : text;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    final extraPadding =
        widget.bottomInset > 0 ? widget.bottomInset + AppSpacing.sm : 0.0;
    return FutureBuilder<String>(
      future: _contentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorPlaceholder(message: l10n.filePreviewReadError);
        }
        final content = snapshot.data ?? '';
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md + extraPadding,
          ),
          child: SelectableText(
            content,
            style: withAppFont(
              const TextStyle(
                fontSize: 13,
                height: 1.6,
              ),
              baseWght: context.appBaseWght,
            ).copyWith(
              color: colors.textPrimary,
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Error placeholder
// ---------------------------------------------------------------------------

class _ErrorPlaceholder extends StatelessWidget {
  final String message;
  const _ErrorPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.circleAlert,
            size: 48,
            color: colors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
