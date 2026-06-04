import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:super_native_extensions/widget_snapshot.dart'
    as raw_snapshot;

import '../utils/open_directory.dart';
import '../utils/runtime_platform.dart';

/// Filters and normalizes local paths for outbound desktop drag (CF_HDROP / file-url).
List<String> filterExistingDragPaths(Iterable<String> paths) {
  final out = <String>[];
  final seen = <String>{};
  for (final raw in paths) {
    if (raw.isEmpty) continue;
    final normalized = normalizeDragFilePath(raw);
    if (seen.contains(normalized)) continue;
    if (!File(normalized).existsSync()) continue;
    seen.add(normalized);
    out.add(normalized);
  }
  return out;
}

String normalizeDragFilePath(String path) {
  if (Platform.isWindows) {
    return windowsExplorerPath(File(path).absolute.path);
  }
  return File(path).absolute.path;
}

/// Drag paths for a file-manager row: all selected when the row is selected.
List<String> resolveFileManagerDragPaths({
  required String currentPath,
  required bool isSelectionMode,
  required Set<String> selectedFiles,
}) {
  if (isSelectionMode &&
      selectedFiles.isNotEmpty &&
      selectedFiles.contains(currentPath)) {
    return selectedFiles.toList();
  }
  return [currentPath];
}

DragItem _buildFileDragItem(String path) {
  final item = DragItem(suggestedName: p.basename(path));
  item.add(Formats.fileUri(Uri.file(path)));
  return item;
}

/// Wraps [child] so local files can be dragged out to Explorer / Finder, etc.
///
/// Implementation notes:
/// - On Windows the native layer assembles CF_HDROP from one provider per file,
///   so we must emit one [DragItem] per file. Putting multiple `Formats.fileUri`
///   on a single [DragItem] only exposes the first path to Explorer.
/// - The visible [child] backs the dragged snapshot. Additional items reuse
///   that snapshot via [DraggableWidget.onDragConfiguration].
class DesktopFileDragSource extends StatefulWidget {
  final List<String> paths;
  final Widget child;
  final bool enabled;

  const DesktopFileDragSource({
    super.key,
    required this.paths,
    required this.child,
    this.enabled = true,
  });

  @override
  State<DesktopFileDragSource> createState() => _DesktopFileDragSourceState();
}

class _DesktopFileDragSourceState extends State<DesktopFileDragSource> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    if (!RuntimePlatform.isDesktop || !widget.enabled) {
      return widget.child;
    }

    final paths = filterExistingDragPaths(widget.paths);
    if (paths.isEmpty) {
      return widget.child;
    }

    return DragItemWidget(
      allowedOperations: () => [DropOperation.copy],
      dragItemProvider: (request) => _provideFirstItem(request, paths.first),
      child: DraggableWidget(
        onDragConfiguration: (config, session) =>
            _appendAdditionalItems(config, paths),
        child: AnimatedOpacity(
          opacity: _dragging ? 0.5 : 1,
          duration: const Duration(milliseconds: 150),
          child: widget.child,
        ),
      ),
    );
  }

  Future<DragItem?> _provideFirstItem(
    DragItemRequest request,
    String path,
  ) async {
    void updateDragging() {
      if (!mounted) return;
      final value = request.session.dragging.value;
      if (_dragging == value) return;
      setState(() => _dragging = value);
    }

    request.session.dragging.addListener(updateDragging);
    updateDragging();

    return _buildFileDragItem(path);
  }

  Future<DragConfiguration?> _appendAdditionalItems(
    DragConfiguration config,
    List<String> paths,
  ) async {
    if (paths.length <= 1 || config.items.isEmpty) {
      return config;
    }
    final base = config.items.first;
    for (final path in paths.skip(1)) {
      config.items.add(
        DragConfigurationItem(
          item: _buildFileDragItem(path),
          image: _cloneSnapshot(base.image),
          liftImage: base.liftImage == null
              ? null
              : _cloneSnapshot(base.liftImage!),
        ),
      );
    }
    return config;
  }
}

/// Each [DragConfigurationItem] owns its image's dispose lifecycle. Sharing the
/// same [TargetedWidgetSnapshot] across items triggers a double-dispose
/// assertion when the session ends. Clone the underlying `ui.Image` so every
/// additional item has its own snapshot wrapper.
TargetedWidgetSnapshot _cloneSnapshot(TargetedWidgetSnapshot original) {
  final src = original.snapshot;
  if (src.isImage) {
    final clonedImage = src.image.clone();
    return TargetedWidgetSnapshot(
      raw_snapshot.WidgetSnapshot.image(clonedImage),
      original.rect,
    );
  }
  return original.retain();
}
