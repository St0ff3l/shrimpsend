import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../logger.dart';

/// Converts a desktop [PerformDropEvent] into [PlatformFile] entries for the outbox.
Future<List<PlatformFile>> platformFilesFromPerformDrop(
  PerformDropEvent event,
) async {
  final out = <PlatformFile>[];
  final seenPaths = <String>{};

  for (final item in event.session.items) {
    final reader = item.dataReader;
    if (reader == null || !_readerHasFilePath(reader)) continue;
    final suggestedName = await reader.getSuggestedName();
    final paths = await _pathsFromReader(reader, suggestedName: suggestedName);
    for (final file in paths) {
      final path = file.path;
      if (path == null || path.isEmpty) continue;
      if (!seenPaths.add(path)) continue;
      out.add(file);
    }
  }
  return out;
}

bool _readerHasFilePath(DataReader reader) {
  final formats = reader.getFormats(const [...Formats.standardFormats]);
  return formats.contains(Formats.fileUri) || formats.contains(Formats.uri);
}

Future<List<PlatformFile>> _pathsFromReader(
  DataReader reader, {
  String? suggestedName,
}) async {
  final fileUri = await _readValue(reader, Formats.fileUri);
  if (fileUri != null && fileUri.scheme == 'file') {
    return _platformFilesForPath(fileUri.toFilePath(), suggestedName);
  }

  final namedUri = await _readValue(reader, Formats.uri);
  if (namedUri != null && namedUri.uri.scheme == 'file') {
    return _platformFilesForPath(namedUri.uri.toFilePath(), suggestedName);
  }

  return const [];
}

Future<List<PlatformFile>> _platformFilesForPath(
  String rawPath,
  String? suggestedName,
) async {
  final path = File(rawPath).absolute.path;
  final type = FileSystemEntity.typeSync(path, followLinks: false);
  if (type == FileSystemEntityType.notFound) return const [];

  if (type == FileSystemEntityType.directory) {
    return _expandDirectory(path);
  }

  try {
    final file = File(path);
    final size = await file.length();
    if (size <= 0) return const [];
    return [
      PlatformFile(
        name: suggestedName ?? p.basename(path),
        path: path,
        size: size,
      ),
    ];
  } catch (e) {
    logChat.warning('desktop_drop_files skip $path: $e');
    return const [];
  }
}

Future<List<PlatformFile>> _expandDirectory(String dirPath) async {
  final out = <PlatformFile>[];
  try {
    await for (final entity in Directory(dirPath).list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      try {
        final size = await entity.length();
        if (size <= 0) continue;
        out.add(
          PlatformFile(
            name: p.basename(entity.path),
            path: entity.absolute.path,
            size: size,
          ),
        );
      } catch (e) {
        logChat.warning('desktop_drop_files skip ${entity.path}: $e');
      }
    }
  } catch (e) {
    logChat.warning('desktop_drop_files list $dirPath: $e');
  }
  return out;
}

Future<T?> _readValue<T extends Object>(
  DataReader reader,
  ValueFormat<T> format,
) async {
  final c = Completer<T?>();
  final progress = reader.getValue<T>(
    format,
    (value) {
      if (!c.isCompleted) c.complete(value);
    },
    onError: (e) {
      if (!c.isCompleted) c.completeError(e);
    },
  );
  if (progress == null) return null;
  return c.future;
}
