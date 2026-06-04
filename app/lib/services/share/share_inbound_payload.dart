enum ShareInboundSource {
  flSharedLink,
  shareExtension,
  androidMultiUri,
}

class ShareAttachment {
  const ShareAttachment({
    this.path,
    this.uri,
    required this.displayName,
    this.size,
  });

  final String? path;
  final String? uri;
  final String displayName;
  final int? size;

  bool get hasLocation =>
      (path != null && path!.isNotEmpty) || (uri != null && uri!.isNotEmpty);
}

/// Aligns with lightningvine SharedMedia: content + attachments.
class ShareInboundPayload {
  const ShareInboundPayload({
    this.content,
    this.attachments = const [],
    required this.source,
  });

  final String? content;
  final List<ShareAttachment> attachments;
  final ShareInboundSource source;
}
