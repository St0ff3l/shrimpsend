import 'package:flutter/widgets.dart';

typedef RouteFilter = bool Function(Route<dynamic>? route);

typedef ScreenNameExtractor = String? Function(RouteSettings settings);
