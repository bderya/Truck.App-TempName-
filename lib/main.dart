import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/bg_registrar_stub.dart' if (dart.library.io) 'core/bg_registrar_io.dart' as bg_registrar;
import 'core/crash_reporting_service.dart';
import 'core/locale_helper.dart';
import 'core/offline_banner.dart';
import 'core/providers.dart';
import 'core/supabase_http_client.dart';
import 'core/supabase_service.dart';
import 'admin_app.dart';
import 'features/admin/admin_approval_screen.dart';
import 'features/auth/providers/auth_state_provider.dart';
import 'features/auth/screens/auth_gate.dart';
import 'features/driver/driver_home_screen.dart';
import 'features/legal/legal_document_screen.dart';
import 'features/map/map_view_screen.dart';
import 'services/push_notification_service.dart';

/// Set to your Sentry DSN to enable crash reporting. Empty = disabled.
const String _sentryDsn = '';
/// Set true to enable Firebase Crashlytics (requires Firebase configured).
const bool _enableCrashlytics = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  final startLocale = await LocaleHelper.getStartLocale();

  await CrashReportingService.initialize(
    sentryDsn: _sentryDsn,
    enableCrashlytics: _enableCrashlytics,
  );

  await SupabaseService.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
    httpClient: SupabaseHttpClient(),
  );

  if (!kIsWeb) {
    bg_registrar.registerBackgroundGeolocationHeadless();
  }

  final app = EasyLocalization(
    supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
    path: 'assets/translations',
    startLocale: startLocale,
    fallbackLocale: const Locale('en', 'US'),
    child: const ProviderScope(
      child: _AppRoot(),
    ),
  );

  if (_sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        options.tracesSampleRate = 0.2;
        options.environment = kReleaseMode ? 'production' : 'development';
        options.beforeSend = CrashReportingService.beforeSend;
      },
      appRunner: () {
        CrashReportingService.attachToExistingErrorHandlers();
        runApp(app);
      },
    );
  } else {
    runApp(app);
  }
}

/// Root that picks Admin vs Mobile and provides locale to MaterialApp.
class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    return kIsWeb ? const AdminApp() : const _MobileApp();
  }
}

/// Mobile/desktop: app switcher (Customer, Driver, Admin approval).
class _MobileApp extends ConsumerWidget {
  const _MobileApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'app_title'.tr(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const OfflineBanner(
        child: AuthGate(authenticatedChild: _FcmRegistration(child: _AppSwitcher())),
      ),
    );
  }
}

/// Registers FCM token for push when user is authenticated (e.g. new chat message). Optional: add Firebase.initializeApp in main.
class _FcmRegistration extends ConsumerStatefulWidget {
  const _FcmRegistration({required this.child});

  final Widget child;

  @override
  ConsumerState<_FcmRegistration> createState() => _FcmRegistrationState();
}

class _FcmRegistrationState extends ConsumerState<_FcmRegistration> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _registerFcm());
  }

  Future<void> _registerFcm() async {
    try {
      final user = await ref.read(currentAppUserProvider.future);
      CrashReportingService.setUserId(user?.id.toString());
      if (user != null) await initPushNotifications(userId: user.id);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Allows switching between Customer and Driver app for demo.
class _AppSwitcher extends ConsumerWidget {
  const _AppSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'app_title'.tr(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MapViewScreen(),
                ),
              ),
              icon: const Icon(Icons.person),
              label: Text('customer_app'.tr()),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DriverHomeScreen(),
                ),
              ),
              icon: const Icon(Icons.local_shipping),
              label: Text('driver_app'.tr()),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminApprovalScreen(),
                ),
              ),
              icon: const Icon(Icons.admin_panel_settings),
              label: Text('admin_approval'.tr()),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => LegalDocumentScreen.open(context, assetPath: 'assets/legal/kvkk.html', title: 'Gizlilik Politikası'),
              icon: const Icon(Icons.privacy_tip_outlined, size: 18),
              label: const Text('Gizlilik Politikası'),
            ),
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: () async {
                CrashReportingService.setUserId(null);
                await ref.read(authServiceProvider).signOut();
                ref.invalidate(authStatusProvider);
              },
              icon: const Icon(Icons.logout),
              label: Text('sign_out'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
