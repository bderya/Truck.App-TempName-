import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';

/// Result of resolving navigation target from booking status.
class NavigationTarget {
  const NavigationTarget({
    required this.latitude,
    required this.longitude,
    required this.title,
  });
  final double latitude;
  final double longitude;
  final String title;
}

/// Resolves destination for external navigation based on booking status.
/// - [on_the_way] or [accepted]: navigate to pickup.
/// - [picked_up]: navigate to destination (fallback to pickup if destination coords missing).
class ExternalNavigationService {
  /// Returns the target coords and title for the current booking status.
  static NavigationTarget getTargetForBooking(Booking booking) {
    final isTowing = booking.status == 'picked_up';
    final hasDestination = booking.destinationLat != null && booking.destinationLng != null;

    if (isTowing && hasDestination) {
      return NavigationTarget(
        latitude: booking.destinationLat!,
        longitude: booking.destinationLng!,
        title: booking.destinationAddress,
      );
    }
    return NavigationTarget(
      latitude: booking.pickupLat,
      longitude: booking.pickupLng,
      title: booking.pickupAddress,
    );
  }

  /// Shows a BottomSheet with installed map apps (Yandex, Google, Apple, etc.),
  /// then launches the selected app with directions to [target].
  /// If no map app is installed, opens Google Maps in the browser.
  static Future<void> showMapPickerAndNavigate(
    BuildContext context, {
    required NavigationTarget target,
  }) async {
    final maps = await MapLauncher.installedMaps;
    if (!context.mounted) return;

    if (maps.isEmpty) {
      await _openGoogleMapsInBrowser(target);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('no_map_app_found'.tr()),
          ),
        );
      }
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'navigasyonu_baslat'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const Divider(height: 1),
            ...maps.map(
              (map) => ListTile(
                leading: Icon(_iconForMapType(map.mapType), color: Theme.of(context).colorScheme.primary),
                title: Text(_displayName(map.mapType)),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _launchDirections(map, target);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${_displayName(map.mapType)} ${'opening_map'.tr()}')),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static IconData _iconForMapType(MapType type) {
    switch (type) {
      case MapType.apple:
        return Icons.apple;
      case MapType.google:
      case MapType.googleGo:
        return Icons.map;
      case MapType.waze:
        return Icons.directions_car;
      default:
        return Icons.map;
    }
  }

  static String _displayName(MapType type) {
    switch (type) {
      case MapType.apple:
        return 'Apple Haritalar';
      case MapType.google:
        return 'Google Maps';
      case MapType.googleGo:
        return 'Google Maps Go';
      case MapType.yandexMaps:
        return 'Yandex Haritalar';
      case MapType.yandexNavi:
        return 'Yandex Navi';
      case MapType.waze:
        return 'Waze';
      case MapType.doubleGis:
        return '2GIS';
      case MapType.here:
        return 'HERE WeGo';
      case MapType.osmand:
        return 'OsmAnd';
      case MapType.mapswithme:
        return 'Maps.me';
      default:
        return type.name;
    }
  }

  static Future<void> _launchDirections(AvailableMap map, NavigationTarget target) async {
    final coords = Coords(target.latitude, target.longitude);
    await map.showDirections(
      destination: coords,
      destinationTitle: target.title,
      directionsMode: DirectionsMode.driving,
    );
  }

  static Future<void> _openGoogleMapsInBrowser(NavigationTarget target) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${target.latitude},${target.longitude}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

