import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _isConnected(List<ConnectivityResult> results) {
  if (results.isEmpty) return false;
  return results.any((r) =>
      r == ConnectivityResult.mobile ||
      r == ConnectivityResult.wifi ||
      r == ConnectivityResult.ethernet ||
      r == ConnectivityResult.vpn);
}

/// true = connected, false = offline (none or bluetooth only).
final connectivityStatusProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(_isConnected);
});

/// One-shot: current connectivity (connected = true).
Future<bool> checkConnectivity() async {
  final results = await Connectivity().checkConnectivity();
  return _isConnected(results);
}
