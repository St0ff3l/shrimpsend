# openpanel_flutter（本地补丁）

基于上游 [openpanel_flutter 0.3.0](https://pub.dev/packages/openpanel_flutter)，相对上游的改动：

- `lib/src/services/device_user_agent.dart`：构造 `User-Agent` 时仅使用可打印 ASCII（中文应用名等会回退为包名），避免 `FormatException: Invalid HTTP header field value`。
- `lib/src/models/update_profile_payload.dart`：`identify` 载荷中 `firstName` / `lastName` / `email` / `avatar` 仅在 **非空** 时下发，避免自托管对空串做 `email` / `url` 格式校验返回 400。
- `lib/src/services/openpanel_http_client.dart`：`/track` 成功响应可能是 **JSON 对象**（如含 `deviceId`），不再 `as String`，避免 `_Map<String, dynamic> is not a subtype of String`。

若上游在后续版本合并同类修复，可改回 `pub.dev` 依赖并删除本目录。
