import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zpevnik/constants.dart' hide red, green, blue;

extension PlatformExtension on TargetPlatform {
  bool get isAndroid => this == TargetPlatform.android;
  bool get isIos => this == TargetPlatform.iOS;
}

extension BrightnessExtension on Brightness {
  bool get isLight => this == Brightness.light;
  bool get isDark => this == Brightness.dark;
}

extension AsyncSnapshotExtension on AsyncSnapshot {
  bool get isDone => connectionState == ConnectionState.done;
}

extension HexColor on Color {
  static Color? fromHex(String? hexColor) {
    if (hexColor == null) return null;

    hexColor = hexColor.toUpperCase().replaceAll("#", "");

    if (hexColor.length == 6) hexColor = "FF$hexColor";

    return Color(int.parse(hexColor, radix: 16));
  }

  String get hex {
    return '#${red.toRadixString(16)}${green.toRadixString(16)}${blue.toRadixString(16)}';
  }
}

extension MediaQueryExtension on MediaQueryData {
  bool get isTablet => size.width > kTabletSizeBreakpoint && size.height > kTabletSizeBreakpoint;
  bool get isLandscape => orientation == Orientation.landscape;
}

extension BuildContextExtension on BuildContext {
  bool get isHome => ModalRoute.of(this)?.settings.name == '/';
  bool get isDisplay => ModalRoute.of(this)?.settings.name == '/display';
  bool get isPlaylist => ModalRoute.of(this)?.settings.name == '/playlist';
  bool get isPlaylists => ModalRoute.of(this)?.settings.name == '/playlists';
  bool get isSearching => ModalRoute.of(this)?.settings.name == '/search';

  ProviderContainer get providers => ProviderScope.containerOf(this, listen: false);

  Future<T?> push<T extends Object?>(String routeName, {Object? arguments}) {
    return Navigator.of(this).pushNamed(routeName, arguments: arguments);
  }

  void pop<T>([T? result]) {
    Navigator.of(this).pop(result);
  }

  void popUntil(String routeName) {
    Navigator.of(this).popUntil((route) => route.settings.name == routeName);
  }

  Future<T?> popAndPush<T extends Object?>(String routeName, {Object? arguments}) {
    return Navigator.of(this).popAndPushNamed(routeName, arguments: arguments);
  }

  void maybePop<T>([T? result]) {
    Navigator.of(this).maybePop(result);
  }

  void replace(String routeName) {
    Navigator.of(this).pushReplacementNamed(routeName);
  }
}
