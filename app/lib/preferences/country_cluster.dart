import 'service_region.dart';

/// 生产集群：仅中国大陆（ISO CN）走 xiachuan，其余国家/地区走 ShrimpSend 海外集群。
ServiceRegion serviceRegionForCountryCode(String code) {
  final u = code.trim().toUpperCase();
  if (u.isEmpty) return ServiceRegion.international;
  return u == 'CN' ? ServiceRegion.mainlandChina : ServiceRegion.international;
}
