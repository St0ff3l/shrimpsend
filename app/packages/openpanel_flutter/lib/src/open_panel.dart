import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/web.dart';

import 'package:openpanel_flutter/src/models/open_panel_event_options.dart';
import 'package:openpanel_flutter/src/models/open_panel_options.dart';
import 'package:openpanel_flutter/src/models/open_panel_state.dart';
import 'package:openpanel_flutter/src/models/post_event_payload.dart';
import 'package:openpanel_flutter/src/models/update_profile_payload.dart';
import 'package:openpanel_flutter/src/observers/referrer_observer.dart';
import 'package:openpanel_flutter/src/services/openpanel_http_client.dart';
import 'package:openpanel_flutter/src/services/preferences_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class Openpanel {
  /// Openpanel instance
  ///
  /// Example:
  /// ```dart
  /// Openpanel.instance.event(name: 'screen_view', properties: {
  ///   'my_event': eventName,
  ///})
  ///```
  static final Openpanel instance = Openpanel._internal();

  factory Openpanel() => instance;

  Openpanel._internal();

  final Logger _logger = Logger();

  late final OpenpanelOptions options;
  late final PreferencesService _preferencesService;

  late final OpenpanelHttpClient _httpClient;

  bool _isClientInitialised = false;

  OpenpanelState _state = const OpenpanelState();

  /// Initialise Openpanel.
  /// This must be called before using Openpanel.
  ///
  ///  - [options]
  ///    - [url] - Openpanel url
  ///    - [clientId] - Openpanel client id
  ///    - [clientSecret] - Openpanel client secret
  ///    - [verbose] - Enable verbose logging
  ///
  /// Example:
  /// ```dart
  /// Openpanel.instance.initialize(
  ///   options: OpenpanelOptions(
  ///     url: <YOUR_OPENPANEL_URL>, // optional
  ///     clientId: <YOUR_CLIENT_ID>,
  ///     clientSecret: <YOUR_CLIENT_SECRET>,
  ///     verbose: true, // optional, defaults to false
  ///   ),
  ///)
  ///```
  Future<void> initialize({required OpenpanelOptions options}) async {
    if (_isClientInitialised) {
      return;
    }
    this.options = options;

    _preferencesService =
        PreferencesService(await SharedPreferences.getInstance());

    final OpenpanelState? savedState =
        await _preferencesService.getSavedState();
    if (savedState != null) {
      _state = savedState;
    } else {
      final deviceData = await _getTrackedDeviceData();

      double rate = options.tracingSampleRate;
      bool sampled = rate >= 1.0 || Random().nextDouble() < rate;

      if (deviceData.isNotEmpty) {
        setGlobalProperties(deviceData);
        _state = _state.copyWith(
          profileId: const Uuid().v4(),
          deviceId: deviceData['deviceId'] ?? const Uuid().v4(),
          isTracingSampled: sampled,
        );
      } else {
        _state = _state.copyWith(isTracingSampled: sampled);
      }

      _preferencesService.persistState(_state);
    }
    // HTTP CLient

    _httpClient = OpenpanelHttpClient(
      verbose: options.verbose,
      logger: _logger,
    );

    await _httpClient.init(options);

    WidgetsBinding.instance.addObserver(ReferrerObserver());

    _isClientInitialised = true;
  }

  /// Enable or disable collection. Enabled by default.
  void setCollectionEnabled(bool enabled) =>
      _state = _state.copyWith(isCollectionEnabled: enabled);

  /// Set profile id
  ///
  /// Profile ids are automatically generated if not set and never change unless you
  /// call [clear] to reset them, use this method or reinstall the app.
  void setProfileId(String profileId) =>
      _state = _state.copyWith(profileId: profileId);

  /// Update profile
  ///
  /// Update an existing profile to add additional infos
  void updateProfile({required UpdateProfilePayload payload}) {
    _execute(() {
      setProfileId(payload.profileId);
      _httpClient.updateProfile(
        payload: payload,
        stateProperties: _state.properties,
      );
    });
  }

  /// Increment a property.
  ///
  /// Ex. You may want to increment the amount of time a user opened the app
  void increment({
    required String property,
    required int value,
    OpenpanelEventOptions? eventOptions,
  }) {
    _execute(() {
      final profileId = eventOptions?.profileId ?? _state.profileId;
      if (profileId == null) {
        return;
      }

      _httpClient.increment(
        profileId: profileId,
        property: property,
        value: value,
      );
    });
  }

  /// Decrement property
  ///
  /// Ex. Decrease the number of credits the user has
  void decrement({
    required String property,
    required int value,
    OpenpanelEventOptions? eventOptions,
  }) {
    _execute(() {
      final profileId = eventOptions?.profileId ?? _state.profileId;
      if (profileId == null) {
        return;
      }

      _httpClient.decrement(
        profileId: profileId,
        property: property,
        value: value,
      );
    });
  }

  /// Send an event
  ///
  /// You can send events with any name and any properties. By default, the device
  /// infos such as id, branch, model, etc... will be sent.
  void event({
    required String name,
    Map<String, dynamic> properties = const {},
  }) {
    _execute(() async {
      final profileId = properties['profileId'] ?? _state.profileId;

      _httpClient.event(
        payload: PostEventPayload(
          name: name,
          timestamp: DateTime.timestamp().toIso8601String(),
          deviceId: _state.deviceId,
          properties: {
            ..._state.properties,
            ...{...properties}..removeWhere((key, value) => key == 'profileId'),
          },
          profileId: profileId,
        ),
      );
    });
  }

  /// Set global properties
  /// These properties will be sent every time an event is sent
  void setGlobalProperties(Map<String, dynamic> properties) {
    _state = _state.copyWith(properties: {
      ..._state.properties,
      ...properties,
    });
  }

  /// Clear all properties
  /// Use this method if you want to reset the global properties
  Future<void> clear() async {
    _state = const OpenpanelState();
    await _preferencesService.persistState(_state);
  }

  void _execute<T>(T Function() action) {
    if (!_isClientInitialised) {
      throw Exception(
          'Openpanel is not initialised. You must initialize Openpanel before using Openpanel.instance.');
    }

    if (!_state.isCollectionEnabled) {
      return;
    }

    if (!_state.isTracingSampled) return;

    action();

    _preferencesService.persistState(_state);
  }

  Future<Map<String, dynamic>> _getTrackedDeviceData() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    Map<String, dynamic> properties = {
      'appVersion': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
      'installerStore': packageInfo.installerStore,
    };

    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      properties.addAll({
        'deviceId': androidInfo.id,
        'brand': androidInfo.brand,
        'model': androidInfo.model,
        'manufacturer': androidInfo.manufacturer,
        'osVersion': androidInfo.version.release,
      });
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final IosDeviceInfo iosDeviceInfo = await deviceInfo.iosInfo;
      properties.addAll({
        'deviceId': iosDeviceInfo.identifierForVendor,
        'brand': iosDeviceInfo.name,
        'model': iosDeviceInfo.model,
        'osVersion': iosDeviceInfo.systemVersion,
      });
    }

    return properties;
  }
}
