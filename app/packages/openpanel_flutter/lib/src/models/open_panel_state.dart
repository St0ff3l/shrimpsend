import 'package:equatable/equatable.dart';

class OpenpanelState extends Equatable {
  final String? deviceId;
  final String? profileId;
  final bool isCollectionEnabled;
  final Map<String, dynamic> properties;
  final bool isTracingSampled;

  const OpenpanelState({
    this.deviceId,
    this.profileId,
    this.isCollectionEnabled = true,
    this.properties = const {},
    this.isTracingSampled = true,
  });

  @override
  List<Object?> get props =>
      [deviceId, profileId, properties, isCollectionEnabled];

  factory OpenpanelState.fromJson(Map<String, dynamic> json) {
    return OpenpanelState(
      deviceId: json['deviceId'],
      profileId: json['profileId'],
      properties: json['properties'],
      isCollectionEnabled: json['isCollectionEnabled'],
      isTracingSampled: json['isTracingSampled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'profileId': profileId,
      'properties': properties,
      'isCollectionEnabled': isCollectionEnabled,
      'isTracingSampled': isTracingSampled,
    };
  }

  OpenpanelState copyWith(
      {String? deviceId,
      String? profileId,
      Map<String, dynamic>? properties,
      bool? isCollectionEnabled,
      bool? isTracingSampled}) {
    return OpenpanelState(
      profileId: profileId ?? this.profileId,
      deviceId: deviceId ?? this.deviceId,
      properties: properties ?? this.properties,
      isCollectionEnabled: isCollectionEnabled ?? this.isCollectionEnabled,
      isTracingSampled: isTracingSampled ?? this.isTracingSampled,
    );
  }
}
