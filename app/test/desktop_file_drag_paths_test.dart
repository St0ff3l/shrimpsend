import 'dart:io';

import 'package:app/widgets/desktop_file_drag_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('resolveFileManagerDragPaths uses all selected when row is selected', () {
    const a = r'C:\recv\a.txt';
    const b = r'C:\recv\b.txt';
    const c = r'C:\recv\c.txt';

    expect(
      resolveFileManagerDragPaths(
        currentPath: b,
        isSelectionMode: true,
        selectedFiles: {a, b, c},
      ),
      [a, b, c],
    );
  });

  test('resolveFileManagerDragPaths falls back to single row when not selected', () {
    const a = r'C:\recv\a.txt';
    const b = r'C:\recv\b.txt';

    expect(
      resolveFileManagerDragPaths(
        currentPath: b,
        isSelectionMode: true,
        selectedFiles: {a},
      ),
      [b],
    );
  });

  test('filterExistingDragPaths drops missing files and dedupes', () {
    final dir = Directory.systemTemp.createTempSync('ultrasend_drag_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    final existing = File(p.join(dir.path, 'keep.txt'))..writeAsStringSync('x');
    const missing = r'C:\no\such\file.dat';

    expect(
      filterExistingDragPaths([existing.path, missing, existing.path]),
      [existing.absolute.path],
    );
  });
}
