import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:http/http.dart' as http;

import '../api/devices.dart';
import '../logger.dart';
import 'lan_url.dart';
import 'transfer_worker.dart';

const String kUltrasendServiceType = '_ultrasend._tcp';
const String kAttrDeviceId = 'deviceId';
const String kAttrDeviceName = 'name';
const String kAttrPlatform = 'platform';

final _log = logChat;

/// Parses [host] (IPv4/IPv6, optional `%zone`) for scoring; ignores zone id.
InternetAddress? _tryParseNumericHost(String host) {
  final h = host.trim();
  if (h.isEmpty) return null;
  final zoneIdx = h.indexOf('%');
  final addrPart = zoneIdx >= 0 ? h.substring(0, zoneIdx) : h;
  return InternetAddress.tryParse(addrPart);
}

/// Higher = better for cross-LAN HTTP (prefer routable over link-local).
int _lanReachabilityScore(String host) {
  final addr = _tryParseNumericHost(host);
  if (addr == null) return 1;
  if (addr.isLoopback) return 0;
  if (addr.isLinkLocal) return 0;
  if (addr.type == InternetAddressType.IPv4) return 3;
  return 2;
}

/// Link-local (fe80:: / 169.254.x.x) is unreliable for peer HTTP across OS/zone.
bool _shouldRegisterPeer(String host) {
  final addr = _tryParseNumericHost(host);
  if (addr == null) return true;
  return !addr.isLinkLocal;
}

/// Manages mDNS broadcast (advertise this device) and discovery (find other devices).
/// Use [LanDiscoveryService.instance] to get or create the shared singleton.
class LanDiscoveryService {
  LanDiscoveryService({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
  });

  static LanDiscoveryService? _instance;

  /// Get or create the shared singleton. First call must provide device info.
  static LanDiscoveryService ensureInstance({
    required String deviceId,
    required String deviceName,
    required String platform,
  }) {
    if (_instance == null ||
        _instance!.deviceId != deviceId) {
      _instance = LanDiscoveryService(
        deviceId: deviceId,
        deviceName: deviceName,
        platform: platform,
      );
    }
    return _instance!;
  }

  /// Returns the current singleton instance, or null if not yet created.
  static LanDiscoveryService? get instance => _instance;

  final String deviceId;
  final String deviceName;
  final String platform;

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription? _discoverySubscription;
  final Map<String, DeviceDto> _discoveredByDeviceId = {};
  final _discoveredController = StreamController<List<DeviceDto>>.broadcast();
  final _lostDeviceIdController = StreamController<String>.broadcast();

  Stream<List<DeviceDto>> get discoveredDevices => _discoveredController.stream;

  /// Fires when Bonsoir reports a peer service gone (not when [stopDiscovery] clears the map).
  Stream<String> get lostDiscoveredDeviceIds => _lostDeviceIdController.stream;

  List<DeviceDto> get currentDiscovered => List.unmodifiable(_discoveredByDeviceId.values);

  void addManualDevice(DeviceDto device) {
    _discoveredByDeviceId[device.deviceId] = device;
    _discoveredController.add(currentDiscovered);
  }

  /// Start advertising this device on the LAN (call after HTTP server is up).
  Future<void> startBroadcast(String lanHttpUrl) async {
    await stopBroadcast();
    try {
      final uri = Uri.parse(lanHttpUrl);
      final port = uri.port;
      final service = BonsoirService(
        name: deviceName,
        type: kUltrasendServiceType,
        port: port,
        attributes: {
          kAttrDeviceId: deviceId,
          kAttrDeviceName: deviceName,
          kAttrPlatform: platform,
        },
      );
      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.initialize();
      await _broadcast!.start();
      _log.info('LanDiscovery broadcast started at $lanHttpUrl');
    } catch (e) {
      _log.warning('LanDiscovery startBroadcast failed: $e');
    }
  }

  Future<void> stopBroadcast() async {
    if (_broadcast != null) {
      try {
        await _broadcast!.stop();
      } catch (_) {}
      _broadcast = null;
      _log.info('LanDiscovery broadcast stopped');
    }
  }

  /// Start discovering other ultrasend devices on the LAN.
  void startDiscovery() {
    if (_discovery != null) return;
    final discovery = BonsoirDiscovery(type: kUltrasendServiceType);
    _discovery = discovery;
    discovery.initialize().then((_) {
      if (_discovery != discovery) return;
      _discoverySubscription = discovery.eventStream?.listen((event) {
        if (_discovery != discovery) return;
        if (event is BonsoirDiscoveryServiceFoundEvent) {
          event.service.resolve(discovery.serviceResolver).catchError((e) {
            _log.fine('resolve failed: $e');
          });
        } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
          _onServiceResolved(event.service);
        } else if (event is BonsoirDiscoveryServiceUpdatedEvent) {
          _onServiceResolved(event.service);
        } else if (event is BonsoirDiscoveryServiceLostEvent) {
          _onServiceLost(event.service);
        }
      });
      discovery.start();
      _log.info('LanDiscovery discovery started');
    }).catchError((e) {
      _log.warning('LanDiscovery startDiscovery failed: $e');
      if (_discovery == discovery) {
        _discovery = null;
      }
    });
  }

  void _onServiceResolved(BonsoirService service) {
    final host = service.host;
    final port = service.port;
    if (host == null || host.isEmpty || host == '127.0.0.1') return;
    final attrs = service.attributes;
    final rawId = attrs[kAttrDeviceId];
    if (rawId == null || rawId.trim().isEmpty) {
      _log.fine(
        'LanDiscovery skip resolve until TXT has deviceId (host=$host port=$port)',
      );
      return;
    }
    final deviceId = rawId.trim();
    if (deviceId == this.deviceId) return;
    final name = attrs[kAttrDeviceName] ?? service.name;
    final platform = attrs[kAttrPlatform];

    final trimmedHost = host.endsWith('.') ? host.substring(0, host.length - 1) : host;
    if (trimmedHost.endsWith('.local') || trimmedHost.contains('.local.')) {
      _resolveAndAdd(trimmedHost, port, deviceId, name, platform);
    } else {
      _addDiscovered(trimmedHost, port, deviceId, name, platform);
    }
  }

  Future<void> _resolveAndAdd(String host, int port, String deviceId, String name, String? platform) async {
    try {
      final addresses = await InternetAddress.lookup(host);
      final ipv4 = addresses.firstWhere(
        (a) => a.type == InternetAddressType.IPv4,
        orElse: () => addresses.first,
      );
      _addDiscovered(ipv4.address, port, deviceId, name, platform);
    } catch (e) {
      if (Platform.isWindows && host.endsWith('.local')) {
        _log.fine(
          'LanDiscovery failed to resolve $host (common on Windows until Bonsoir provides an IP): $e',
        );
      } else {
        _log.warning('LanDiscovery failed to resolve $host: $e');
      }
    }
  }

  String? _myLanHttpUrl;

  /// Set our own lanHttpUrl so we can announce it to discovered peers.
  void setMyLanHttpUrl(String? url) {
    _myLanHttpUrl = url;
  }

  void _addDiscovered(String host, int port, String deviceId, String name, String? platform) {
    var effectiveHost = host;
    var effectivePort = port;
    final existing = _discoveredByDeviceId[deviceId];
    if (existing != null &&
        existing.lanHttpUrl != null &&
        existing.lanHttpUrl!.isNotEmpty) {
      try {
        final oldUri = Uri.parse(existing.lanHttpUrl!);
        final oldHost = oldUri.host;
        if (_lanReachabilityScore(oldHost) > _lanReachabilityScore(host)) {
          effectiveHost = oldHost;
          effectivePort = oldUri.hasPort ? oldUri.port : port;
        }
      } catch (_) {}
    }

    final lanHttpUrl = buildLanHttpBaseUrl(effectiveHost, effectivePort);
    final dto = DeviceDto(
      deviceId: deviceId,
      name: name,
      platform: platform,
      lanHttpUrl: lanHttpUrl,
      lastSeen: DateTime.now().millisecondsSinceEpoch,
    );
    if (deviceId != 'unknown') {
      _discoveredByDeviceId.remove('unknown');
    }
    _discoveredByDeviceId[deviceId] = dto;
    _discoveredController.add(currentDiscovered);
    _log.fine('LanDiscovery found: $deviceId $lanHttpUrl');

    // Notify the discovered device about our presence so it can register us
    // even if its own mDNS discovery missed us.
    if (_shouldRegisterPeer(effectiveHost)) {
      _registerWithPeer(lanHttpUrl);
    }
  }

  Future<void> _registerWithPeer(String peerLanHttpUrl) async {
    if (_myLanHttpUrl == null || _myLanHttpUrl!.isEmpty) return;
    try {
      final base = Uri.parse(peerLanHttpUrl);
      if (!_shouldRegisterPeer(base.host)) return;
      final uri = base.resolve('register-peer');
      final body = '{"deviceId":"${_escapeJson(deviceId)}",'
          '"name":"${_escapeJson(deviceName)}",'
          '"lanHttpUrl":"${_escapeJson(_myLanHttpUrl!)}",'
          '"platform":"${_escapeJson(platform)}"}';
      await http.post(uri, body: body, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      _log.fine('LanDiscovery registerWithPeer failed: $e');
    }
  }

  static String _escapeJson(String s) {
    return s
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
  }

  void _onServiceLost(BonsoirService service) {
    final attrs = service.attributes;
    final idFromTxt = attrs[kAttrDeviceId];
    if (idFromTxt != null && idFromTxt.isNotEmpty) {
      final id = idFromTxt.trim();
      if (_discoveredByDeviceId.remove(id) != null) {
        if (!_lostDeviceIdController.isClosed) {
          _lostDeviceIdController.add(id);
        }
        _discoveredController.add(currentDiscovered);
        _log.fine('LanDiscovery lost: $id');
      }
      return;
    }
    final svcName = service.name;
    final svcPort = service.port;
    final toRemove = <String>[];
    for (final e in _discoveredByDeviceId.entries) {
      final d = e.value;
      if (d.name != svcName) continue;
      final url = d.lanHttpUrl;
      if (url == null || url.isEmpty) continue;
      try {
        if (Uri.parse(url).port == svcPort) {
          toRemove.add(e.key);
        }
      } catch (_) {}
    }
    for (final k in toRemove) {
      _discoveredByDeviceId.remove(k);
      if (!_lostDeviceIdController.isClosed) {
        _lostDeviceIdController.add(k);
      }
    }
    if (toRemove.isNotEmpty) {
      _discoveredController.add(currentDiscovered);
      _log.fine('LanDiscovery lost (no TXT): ${toRemove.join(", ")}');
    }
  }

  /// Re-announce on mDNS and tear down / recreate the Bonsoir discovery session.
  ///
  /// Call when discovery appears stuck (missed broadcasts, Bonsoir idle, or after
  /// local-network permission). Unlike probing alone, this forces a new browse.
  Future<void> restartLanDiscovery() async {
    _log.info('LanDiscovery restartLanDiscovery');
    if (_myLanHttpUrl != null && _myLanHttpUrl!.isNotEmpty) {
      await startBroadcast(_myLanHttpUrl!);
    }
    await stopDiscovery();
    startDiscovery();
  }

  Future<void> stopDiscovery() async {
    if (_discovery != null) {
      await _discoverySubscription?.cancel();
      _discoverySubscription = null;
      try {
        await _discovery!.stop();
      } catch (_) {}
      _discovery = null;
      _discoveredByDeviceId.clear();
      _discoveredController.add(currentDiscovered);
      _log.info('LanDiscovery discovery stopped');
    }
  }

  Future<void> dispose() async {
    await stopBroadcast();
    await stopDiscovery();
    await _discoveredController.close();
    await _lostDeviceIdController.close();
  }
}

/// Add a device by manual IP (and optional port). Probes /probe then fetches /device-info.
Future<DeviceDto?> addDeviceByAddress(String address, {int defaultPort = 9080}) async {
  int? port = defaultPort;
  String host = address;
  if (address.contains(':')) {
    final parts = address.split(':');
    host = parts[0].trim();
    if (parts.length > 1) {
      port = int.tryParse(parts[1].trim());
    }
  }
  if (port == null || port < 1 || port > 65535) port = defaultPort;
  final baseUrl = buildLanHttpBaseUrl(host, port);
  final ok = await probeHttp(baseUrl, timeout: const Duration(seconds: 3));
  if (!ok) return null;
  try {
    final r = await http.get(Uri.parse('$baseUrl/device-info'))
        .timeout(const Duration(seconds: 3));
    if (r.statusCode != 200) return null;
    final j = r.body;
    final deviceId = _extractJsonString(j, 'deviceId');
    final name = _extractJsonString(j, 'name');
    final platform = _extractJsonString(j, 'platform');
    if (deviceId == null || deviceId.isEmpty) return null;
    return DeviceDto(
      deviceId: deviceId,
      name: name ?? host,
      platform: platform,
      lanHttpUrl: baseUrl,
      lastSeen: DateTime.now().millisecondsSinceEpoch,
    );
  } catch (_) {
    return null;
  }
}

String? _extractJsonString(String body, String key) {
  final pattern = RegExp('"$key"\\s*:\\s*"([^"]*)"');
  final m = pattern.firstMatch(body);
  return m?.group(1);
}
