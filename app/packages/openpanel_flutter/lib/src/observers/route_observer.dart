import 'package:flutter/widgets.dart';
import 'package:openpanel_flutter/openpanel_flutter.dart';
import 'package:openpanel_flutter/src/models/typedefs.dart';

bool defaultRouteFilter(Route<dynamic>? route) => route is PageRoute;

String? defaultNameExtractor(RouteSettings settings) => settings.name;

/// Openpanel route observer
class OpenpanelObserver extends RouteObserver {
  /// Route filter.
  ///
  /// This is used to filter the routes that you want to track.
  ///
  /// By default, it will track all routes that are [PageRoute].
  final RouteFilter routeFilter;

  /// Screen name extractor.
  ///
  /// This is used to extract the screen name from the [RouteSettings].
  ///
  /// By default, it will use the [RouteSettings.name] property.
  final ScreenNameExtractor screenNameExtractor;

  OpenpanelObserver({
    this.routeFilter = defaultRouteFilter,
    this.screenNameExtractor = defaultNameExtractor,
  });

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (routeFilter(route)) {
      _trackScreenView(route);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null && routeFilter(newRoute)) {
      _trackScreenView(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null &&
        routeFilter(previousRoute) &&
        routeFilter(route)) {
      _trackScreenView(previousRoute);
    }
  }

  void _trackScreenView(Route<dynamic> route) {
    final routeName = screenNameExtractor(route.settings);
    if (routeName == null) {
      return;
    }

    Openpanel.instance.event(name: 'screen_view', properties: {
      '__path': routeName,
    });
  }
}
