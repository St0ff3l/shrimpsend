// 从 assets/logo.png 生成圆角透明图标，写入 Windows exe 图标与托盘、MSIX logo。
// 用法（在 app 目录）：dart run tool/round_icon_assets.dart

import 'dart:io';
import 'dart:math';

import 'package:image/image.dart';

/// 圆角半径占边长的比例（近似常见桌面图标圆角观感）。
const double _radiusFraction = 0.22;

void main() {
  final root = Directory.current.path;
  final logoPath = '$root${Platform.pathSeparator}assets${Platform.pathSeparator}logo.png';
  final logoFile = File(logoPath);
  if (!logoFile.existsSync()) {
    stderr.writeln('Missing $logoPath — run from app/ directory.');
    exitCode = 1;
    return;
  }

  final src = decodeImage(logoFile.readAsBytesSync());
  if (src == null) {
    stderr.writeln('Could not decode logo.png');
    exitCode = 1;
    return;
  }

  Image roundedSquare(Image frame, int size) {
    final r = max(1, min((size * _radiusFraction).round(), size ~/ 2));
    return copyResizeCropSquare(
      frame,
      size: size,
      interpolation: Interpolation.cubic,
      radius: r.toDouble(),
      antialias: true,
    );
  }

  // --- Windows exe：多尺寸 ICO（PNG 嵌入，Vista+）
  const icoSizes = [16, 24, 32, 48, 64, 128, 256];
  final icoFrames = icoSizes.map((s) => roundedSquare(src, s)).toList();
  final icoOut =
      '$root${Platform.pathSeparator}windows${Platform.pathSeparator}runner${Platform.pathSeparator}resources${Platform.pathSeparator}app_icon.ico';
  File(icoOut).writeAsBytesSync(IcoEncoder().encodeImages(icoFrames));
  print('Wrote $icoOut (${icoFrames.length} sizes)');

  // --- 托盘：较小 ICO
  const traySizes = [16, 24, 32, 48];
  final trayFrames = traySizes.map((s) => roundedSquare(src, s)).toList();
  final trayOut =
      '$root${Platform.pathSeparator}assets${Platform.pathSeparator}tray_icon_windows.ico';
  File(trayOut).writeAsBytesSync(IcoEncoder().encodeImages(trayFrames));
  print('Wrote $trayOut (${trayFrames.length} sizes)');

  // --- 应用内 / MSIX：圆角 PNG（边长不超过 1024，避免过大）
  final side = min(1024, max(src.width, src.height));
  final logoRounded = roundedSquare(src, side);
  File(logoPath).writeAsBytesSync(encodePng(logoRounded));
  print('Wrote $logoPath (${logoRounded.width}x${logoRounded.height})');
}
