/// 规范化平台字符串（与 [DeviceDto.platform] 一致）。
String normalizeOs(String? raw) {
  if (raw == null || raw.isEmpty) return 'unknown';
  return raw.toLowerCase();
}
