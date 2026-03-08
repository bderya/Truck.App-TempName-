import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;

import '../services/background_geolocation_headless_task.dart';

void registerBackgroundGeolocationHeadless() {
  bg.BackgroundGeolocation.registerHeadlessTask(backgroundGeolocationHeadlessTask);
}
