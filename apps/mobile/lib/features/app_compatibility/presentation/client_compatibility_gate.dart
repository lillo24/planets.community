import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../settings/application/language_preference_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/client_compatibility_controller.dart';
import '../data/client_compatibility_gateway.dart';
import '../domain/client_compatibility.dart';

/// Mounted outside PlanetsApp so unsupported startup/deep links cannot start
/// domain navigation or authentication/profile loading through that widget.
class ClientCompatibilityGate extends ConsumerStatefulWidget {
  const ClientCompatibilityGate({
    required this.child,
    this.enabled = true,
    super.key,
  });
  final Widget child;
  final bool enabled;

  @override
  ConsumerState<ClientCompatibilityGate> createState() =>
      _ClientCompatibilityGateState();
}

class _ClientCompatibilityGateState
    extends ConsumerState<ClientCompatibilityGate>
    with WidgetsBindingObserver {
  bool get _enabled =>
      widget.enabled && ref.read(clientPlatformProvider) != null;

  Timer? _unverifiedRetry;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_enabled) {
      _unverifiedRetry = Timer.periodic(const Duration(seconds: 45), (_) {
        if (!mounted || !_foreground) return;
        if (ref.read(clientCompatibilityProvider).phase ==
            ClientCompatibilityPhase.unverified) {
          unawaited(ref.read(clientCompatibilityProvider.notifier).check());
        }
      });
      Future<void>.microtask(() {
        if (mounted) {
          unawaited(ref.read(clientCompatibilityProvider.notifier).check());
        }
      });
    }
  }

  @override
  void dispose() {
    _unverifiedRetry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _foreground = false;
    }
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      if (_enabled &&
          ref.read(clientCompatibilityProvider).phase !=
              ClientCompatibilityPhase.supported) {
        unawaited(ref.read(clientCompatibilityProvider.notifier).check());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    final state = ref.watch(clientCompatibilityProvider);
    if (state.phase == ClientCompatibilityPhase.supported ||
        state.phase == ClientCompatibilityPhase.unverified) {
      return widget.child;
    }
    final android = ref.watch(clientPlatformProvider) == ClientPlatform.android;
    final controller = ref.read(clientCompatibilityProvider.notifier);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: ref.watch(languagePreferenceProvider).locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final l = AppLocalizations.of(context);
          final checking = state.phase == ClientCompatibilityPhase.checking;
          final failed = state.phase == ClientCompatibilityPhase.failed;
          return PopScope(
            canPop: false,
            child: Scaffold(
              body: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (checking || state.updating)
                            const Center(child: CircularProgressIndicator())
                          else
                            const Icon(Icons.system_update, size: 48),
                          const SizedBox(height: 24),
                          Text(
                            checking
                                ? l.appCompatibilityChecking
                                : failed
                                ? l.appCompatibilityFailedTitle
                                : l.appUpdateRequiredTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 12),
                          if (!checking)
                            Text(
                              failed
                                  ? l.appCompatibilityFailedBody
                                  : l.appUpdateRequiredBody,
                              textAlign: TextAlign.center,
                            ),
                          if (state.updateFailed) ...[
                            const SizedBox(height: 12),
                            Text(
                              l.appUpdateNotCompleted,
                              textAlign: TextAlign.center,
                            ),
                          ],
                          if (state.storeFailed) ...[
                            const SizedBox(height: 12),
                            Text(
                              l.appUpdateStoreFailed,
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 24),
                          if (failed)
                            FilledButton(
                              key: const Key('compatibility-retry'),
                              onPressed: controller.check,
                              child: Text(l.retryAction),
                            ),
                          if (!checking && !failed) ...[
                            if (android)
                              FilledButton(
                                key: const Key(
                                  'compatibility-immediate-update',
                                ),
                                onPressed: state.updating
                                    ? null
                                    : controller.startImmediateUpdate,
                                child: Text(l.appUpdateAndroidAction),
                              ),
                            if (state.policy?.updateUrl != null)
                              TextButton(
                                key: const Key('compatibility-open-store'),
                                onPressed: state.updating
                                    ? null
                                    : controller.openStore,
                                child: Text(
                                  android
                                      ? l.appUpdateGooglePlay
                                      : l.appUpdateAppStore,
                                ),
                              ),
                            TextButton(
                              key: const Key('compatibility-recheck'),
                              onPressed: state.updating
                                  ? null
                                  : controller.check,
                              child: Text(l.appUpdateRecheck),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
