import 'dart:io' show Platform;

bool get isMobile => Platform.isAndroid || Platform.isIOS;
