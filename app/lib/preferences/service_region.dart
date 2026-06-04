/// Maps to production API host cluster (xiachuan vs shrimpsend).
enum ServiceRegion {
  mainlandChina,
  international,
}

extension ServiceRegionStorage on ServiceRegion {
  String get storageValue => switch (this) {
        ServiceRegion.mainlandChina => 'mainland_china',
        ServiceRegion.international => 'international',
      };
}

ServiceRegion? serviceRegionFromStorage(String? raw) {
  switch (raw) {
    case 'mainland_china':
      return ServiceRegion.mainlandChina;
    case 'international':
      return ServiceRegion.international;
    default:
      return null;
  }
}
