import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/planets_app.dart';
import '../../../app/router/app_router.dart';
import '../../../app/startup/startup_flow.dart';
import '../../../core/backend/supabase_backend.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/data/auth_gateway.dart';
import '../../auth/application/auth_routes.dart';
import '../../auth/domain/auth_models.dart';
import '../../settings/application/activities_split_preference_controller.dart';
import '../../settings/application/language_preference_controller.dart';
import '../../settings/application/navigation_preference_controller.dart';
import '../../settings/data/activities_split_preference_store.dart';
import '../../settings/data/language_preference_store.dart';
import '../../settings/data/navigation_preference_store.dart';
import '../../settings/domain/activities_split_preference.dart';
import '../../settings/domain/language_preference.dart';
import '../../settings/domain/navigation_preference.dart';
import '../application/mock_mode_coordinator.dart';
import '../data/mock_mode_store.dart';
import '../data/mock_session_access.dart';
import '../domain/mock_models.dart';

class MockRealmHost extends StatefulWidget {
  const MockRealmHost({
    required this.config,
    required this.language,
    required this.navigation,
    required this.activitiesSplit,
    required this.startup,
    super.key,
  });
  final AppConfig config;
  final LanguagePreference language;
  final NavigationPreferenceState navigation;
  final ActivitiesSplitPreferenceState activitiesSplit;
  final StartupPreference startup;
  @override
  State<MockRealmHost> createState() => _MockRealmHostState();
}

class _MockRealmHostState extends State<MockRealmHost>
    with WidgetsBindingObserver {
  MockModeCoordinator? _coordinator;
  SupabaseMockSessionAccess? _access;
  Widget? _product;
  int _productRevision = -1;
  bool _scopeLoading = false;
  bool _unconfiguredLoading = true;
  bool _unconfiguredRecovery = false;
  int _unconfiguredRevision = 0;
  late LanguagePreference _language = widget.language;
  late NavigationPreferenceState _navigation = widget.navigation;
  late ActivitiesSplitPreferenceState _split = widget.activitiesSplit;
  late StartupPreference _startup = widget.startup;
  final _store = PreferencesMockModeStore();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final config = widget.config.mockEnvironment;
    if (config == null) {
      unawaited(_startUnavailable());
      return;
    }
    final normal = normalBackendRuntime;
    _access = SupabaseMockSessionAccess(
      config: config,
      normal: normal.client,
      normalTransport: normal.transport,
      credentials: normal.credentials,
    );
    _coordinator = MockModeCoordinator(
      config: config,
      access: _access!,
      store: _store,
    )..addListener(_changed);
    unawaited(_coordinator!.start());
  }

  Future<void> _startUnavailable() async {
    try {
      final raw = await SharedPreferencesAsync().getString(
        PreferencesMockModeStore.key,
      );
      if (raw != null) {
        final value = jsonDecode(raw);
        if (value is Map<String, dynamic> && value['format'] == 1) {
          _unconfiguredRecovery =
              value['active'] != null || value['pending'] != null;
          if (value['revision'] is int) {
            _unconfiguredRevision = value['revision'] as int;
          }
        }
      }
    } on FormatException {
      /* Corrupt mode metadata defaults No. */
    } on Exception {
      _unconfiguredRecovery = true;
    }
    if (!mounted) return;
    setState(() {
      _unconfiguredLoading = false;
      if (!_unconfiguredRecovery) _product = _scope(0);
    });
  }

  Future<void> _changed() async {
    final coordinator = _coordinator!;
    if (!mounted) return;
    if (coordinator.phase == MockModePhase.recovery &&
        [
          MockFailureKind.denied,
          MockFailureKind.controlLoginRequired,
          MockFailureKind.invalidSession,
        ].contains(coordinator.failure)) {
      _product = null;
      _productRevision = -1;
    }
    if (coordinator.showProduct &&
        coordinator.scopeRevision != _productRevision &&
        !_scopeLoading) {
      _scopeLoading = true;
      final revision = coordinator.scopeRevision;
      if (_productRevision != -1) {
        _language = await restoreLanguagePreference(
          SharedPreferencesLanguagePreferenceStore(),
        );
        _navigation = await restoreNavigationPreference(
          SharedPreferencesNavigationPreferenceStore(),
        );
        _split = await restoreActivitiesSplitPreference(
          SharedPreferencesActivitiesSplitPreferenceStore(),
        );
        _startup = await restoreStartupPreference(
          SharedPreferencesStartupStore(),
        );
      }
      if (!mounted) return;
      if (coordinator.showProduct && revision == coordinator.scopeRevision) {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        _product = _scope(revision);
        _productRevision = revision;
      }
      _scopeLoading = false;
    }
    if (mounted) setState(() {});
  }

  Widget _scope(int revision) {
    final coordinator = _coordinator;
    final mock = coordinator?.isMock ?? false;
    final client = _access?.activeClient ?? normalBackendRuntime.client;
    final config = mock ? widget.config.forMockDataRealm() : widget.config;
    final namespace = mock
        ? 'mock:${config.supabaseUrl.origin}:${coordinator!.active!.rootId}:'
        : 'normal:${config.supabaseUrl.origin}:';
    return ProviderScope(
      key: ValueKey('realm:$namespace:$revision'),
      overrides: [
        appConfigProvider.overrideWithValue(config),
        initialAppLocationProvider.overrideWithValue(
          !mock && coordinator?.requiresNormalLogin == true
              ? AuthRoutes.entry
              : '/',
        ),
        supabaseClientProvider.overrideWithValue(client),
        initialLanguagePreferenceProvider.overrideWithValue(_language),
        initialNavigationPreferenceProvider.overrideWithValue(_navigation),
        initialActivitiesSplitPreferenceProvider.overrideWithValue(_split),
        initialStartupPreferenceProvider.overrideWithValue(_startup),
        closedTestMockCapabilityProvider.overrideWithValue(true),
        activeMockRealmProvider.overrideWithValue(mock),
        mockModeCoordinatorProvider.overrideWithValue(coordinator),
        realmPreferenceNamespaceProvider.overrideWithValue(namespace),
        if (coordinator != null)
          authGatewayProvider.overrideWithValue(
            _RealmAuthGateway(client, coordinator, mock),
          ),
      ],
      child: const PlanetsApp(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final coordinator = _coordinator;
    if (state == AppLifecycleState.resumed) {
      unawaited(coordinator?.validateOnResume() ?? Future<void>.value());
    } else if (state == AppLifecycleState.paused &&
        coordinator?.isMock == true) {
      _access?.activeClient.auth.stopAutoRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _coordinator?.removeListener(_changed);
    _coordinator?.dispose();
    unawaited(_access?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = _coordinator;
    final blocked = coordinator == null
        ? _unconfiguredLoading || _unconfiguredRecovery
        : _scopeLoading ||
              (!coordinator.showProduct &&
                  (coordinator.phase != MockModePhase.switching ||
                      coordinator.fencing));
    return Stack(
      alignment: Alignment.center,
      fit: StackFit.expand,
      children: [
        if (_product != null) Offstage(offstage: blocked, child: _product!),
        if (blocked)
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            locale: _language.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                final recovering =
                    coordinator?.phase == MockModePhase.recovery ||
                    (coordinator == null && _unconfiguredRecovery);
                return Scaffold(
                  body: SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!recovering)
                                const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                recovering
                                    ? (coordinator?.failure ==
                                              MockFailureKind.denied
                                          ? l10n.mockDenied
                                          : l10n.mockRecovery)
                                    : coordinator?.phase ==
                                          MockModePhase.switching
                                    ? l10n.mockSwitching
                                    : l10n.mockRestoring,
                                textAlign: TextAlign.center,
                              ),
                              if (recovering) ...[
                                const SizedBox(height: 16),
                                if (coordinator != null)
                                  FilledButton(
                                    onPressed: () => coordinator.retry(),
                                    child: Text(l10n.retryAction),
                                  ),
                                TextButton(
                                  onPressed: () async {
                                    if (coordinator != null) {
                                      await coordinator.leave(
                                        prepareDeparture: () async => true,
                                      );
                                    } else {
                                      try {
                                        await _store.write(
                                          MockModeRecord(
                                            revision: ++_unconfiguredRevision,
                                          ),
                                        );
                                        if (mounted) {
                                          setState(() {
                                            _unconfiguredRecovery = false;
                                            _product = _scope(
                                              _unconfiguredRevision,
                                            );
                                          });
                                        }
                                      } on Exception {
                                        /* Keep the isolated recovery screen. */
                                      }
                                    }
                                  },
                                  child: Text(l10n.mockReturnNormal),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _RealmAuthGateway extends SupabaseAuthGateway {
  const _RealmAuthGateway(super.client, this.coordinator, this.mock);
  final MockModeCoordinator coordinator;
  final bool mock;
  @override
  Future<void> requestEmailOtp(String email) {
    if (mock) {
      throw const AuthException(
        'Account credentials cannot be changed in Mock Mode.',
      );
    }
    return super.requestEmailOtp(email);
  }

  @override
  Future<AuthIdentity> verifyEmailOtp({
    required String email,
    required String token,
  }) {
    if (mock) {
      throw const AuthException(
        'Account credentials cannot be changed in Mock Mode.',
      );
    }
    return super.verifyEmailOtp(email: email, token: token);
  }

  @override
  Future<void> signOut() async {
    await coordinator.fullLogout();
    if (coordinator.phase != MockModePhase.normal ||
        coordinator.access.controlId != null) {
      throw const AuthException('Sign-out could not be completed.');
    }
  }
}
