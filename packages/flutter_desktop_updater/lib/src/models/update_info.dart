class UpdateInfo {
  final String version;
  final String buildNumber;
  final String downloadUrl;
  final int fileSize;
  final String releaseNotes;
  final bool? updateRequired;

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.fileSize,
    required this.releaseNotes,
    this.updateRequired = false,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'],
      buildNumber: json['build_number'],
      downloadUrl: json['download_url'],
      fileSize: json['file_size'],
      releaseNotes: json['release_notes'],
      updateRequired: json['update_required'],
    );
  }

  bool isNewerThan(String currentVersion, String currentBuildNumber) {
    final newV = version.split('.').map(int.parse).toList();
    final curV = currentVersion.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      if (newV[i] > curV[i]) return true;
      if (newV[i] < curV[i]) return false;
    }

    return int.parse(buildNumber) > int.parse(currentBuildNumber);
  }
}
