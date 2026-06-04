import 'package:equatable/equatable.dart';

/// Openpanel event options
///
/// This is used to configure the event options
class OpenpanelEventOptions extends Equatable {
  final String? profileId;

  const OpenpanelEventOptions({this.profileId});

  @override
  List<Object?> get props => [profileId];
}
