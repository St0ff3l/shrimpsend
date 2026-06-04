import 'package:equatable/equatable.dart';

class UpdateProfilePayload extends Equatable {
  final String profileId;
  final String? firstName;
  final String? lastName;
  final String? avatar;
  final String? email;
  final Map<String, dynamic> properties;

  const UpdateProfilePayload({
    required this.profileId,
    this.firstName,
    this.lastName,
    this.avatar,
    this.email,
    this.properties = const {},
  });

  factory UpdateProfilePayload.fromJson(Map<String, dynamic> json) {
    return UpdateProfilePayload(
      profileId: json['profileId'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      avatar: json['avatar'],
      email: json['email'],
      properties: json['properties'],
    );
  }

  Map<String, dynamic> toJson() {
    // 自托管 OpenPanel 对 email / avatar 等做 format 校验（email / url）；
    // 仅在调用方提供有效值时再下发，避免空串或 null 被拒绝。
    return {
      'profileId': profileId,
      if (firstName != null && firstName!.isNotEmpty) 'firstName': firstName,
      if (lastName != null && lastName!.isNotEmpty) 'lastName': lastName,
      if (avatar != null && avatar!.isNotEmpty) 'avatar': avatar,
      if (email != null && email!.isNotEmpty) 'email': email,
      'properties': properties,
    };
  }

  @override
  List<Object?> get props =>
      [profileId, firstName, lastName, avatar, email, properties];
}
