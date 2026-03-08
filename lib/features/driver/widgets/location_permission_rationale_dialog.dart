import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Shows a custom dialog explaining WHY we need "Always Allow" location permission,
/// then triggers the OS system prompt. Required for App Store / Play Store approval.
Future<bool> showLocationPermissionRationaleDialog(BuildContext context) async {
  final granted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _LocationPermissionRationaleDialog(),
  );
  return granted ?? false;
}

class _LocationPermissionRationaleDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text('location_permission_required'.tr()),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'location_rationale_why'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Text(
              'location_rationale_bullets'.tr(),
              style: const TextStyle(height: 1.4, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              'location_rationale_hint'.tr(),
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('cancel'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('understand_and_allow'.tr()),
        ),
      ],
    );
  }
}

/// Returns true if we have "always" (or whileInUse and we're ok). Calls [showLocationPermissionRationaleDialog] if needed before requesting.
Future<bool> requestLocationPermissionWithRationale(BuildContext context) async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.always) return true;
  if (permission == LocationPermission.deniedForever) {
    await Geolocator.openAppSettings();
    return false;
  }

  final userAccepted = await showLocationPermissionRationaleDialog(context);
  if (!userAccepted) return false;

  permission = await Geolocator.requestPermission();
  if (permission == LocationPermission.whileInUse) {
    permission = await Geolocator.requestPermission();
  }
  return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
}
