import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_provider.dart';
import 'error_messages_tr.dart';

/// Wraps [child] and shows a persistent top banner when offline.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(connectivityStatusProvider);
    return Stack(
      children: [
        child,
        connected.when(
          data: (isConnected) {
            if (isConnected) return const SizedBox.shrink();
            return Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Material(
                elevation: 4,
                color: Colors.orange.shade800,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.wifi_off, color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ErrorMessagesTr.offline,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
