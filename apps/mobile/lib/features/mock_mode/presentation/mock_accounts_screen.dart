import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/mock_mode_coordinator.dart';
import '../application/realm_departure.dart';
import '../domain/mock_models.dart';
import '../../settings/application/co_creation_preference_controller.dart';

/// One fixed-persona selector serves first entry and Help. Scenario suggestions
/// never assert current powers after shared-world changes.
class MockAccountsScreen extends ConsumerStatefulWidget {
  const MockAccountsScreen({super.key});
  @override
  ConsumerState<MockAccountsScreen> createState() => _MockAccountsScreenState();
}

class _MockAccountsScreenState extends ConsumerState<MockAccountsScreen>
    with WidgetsBindingObserver {
  List<MockPersona>? _people;
  MockFailureKind? _failure;
  bool _loading = false;
  int _revision = 0;
  String? _catalogRoot;
  String? _catalogNormal;
  StreamSubscription<String?>? _controlSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controlSubscription = ref
        .read(mockModeCoordinatorProvider)
        ?.access
        .normalIdentityChanges
        .listen((id) {
          if (mounted && id != _catalogNormal) {
            _revision++;
            setState(() {
              _people = null;
              _loading = false;
              _failure = MockFailureKind.invalidSession;
            });
          }
          _catalogNormal = id;
        });
    Future<void>.microtask(_load);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(mockModeCoordinatorProvider)?.busy == false) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _revision++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controlSubscription?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    final revision = ++_revision;
    final controller = ref.read(mockModeCoordinatorProvider);
    _catalogNormal = controller?.access.normalIdentity;
    setState(() {
      _loading = true;
      _people = null;
      _failure = null;
    });
    try {
      if (controller == null) {
        throw const MockFailure(MockFailureKind.unavailable);
      }
      final people = await controller.catalog();
      _catalogRoot = controller.access.clientId;
      if (mounted && revision == _revision) setState(() => _people = people);
    } catch (error) {
      if (mounted && revision == _revision) {
        setState(
          () => _failure = error is MockFailure
              ? error.kind
              : MockFailureKind.unavailable,
        );
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  String _scenario(AppLocalizations l10n, String key) => switch (key) {
    'luca' => l10n.mockScenarioLuca,
    'maya' => l10n.mockScenarioMaya,
    'nora' => l10n.mockScenarioNora,
    'teo' => l10n.mockScenarioTeo,
    'iris' => l10n.mockScenarioIris,
    'giulia' => l10n.mockScenarioGiulia,
    'marco' => l10n.mockScenarioMarco,
    'sara' => l10n.mockScenarioSara,
    'dario' => l10n.mockScenarioDario,
    'elena' => l10n.mockScenarioElena,
    _ => l10n.mockScenarioGeneric,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final coordinator = ref.watch(mockModeCoordinatorProvider);
    final dataset = ref.watch(coCreationPreferenceProvider).enabled
        ? 'people'
        : 'activities';
    final people = _people
        ?.where((p) => p.dataset == dataset)
        .toList(growable: false);
    Widget screen() => Scaffold(
      appBar: pageAppBar(context, title: Text(l10n.mockAccountsTitle)),
      body: SafeArea(
        child: ListView(
          key: const Key('mock-accounts-list'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.mockSharedWorld, key: const Key('mock-shared-world')),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_failure != null) ...[
              Text(
                _failure == MockFailureKind.denied
                    ? l10n.mockDenied
                    : l10n.mockRecovery,
              ),
              TextButton(onPressed: _load, child: Text(l10n.retryAction)),
            ],
            if (people?.isEmpty == true) ...[
              Text(l10n.mockAccountsEmpty),
              TextButton(onPressed: _load, child: Text(l10n.retryAction)),
            ],
            for (final person in people ?? <MockPersona>[])
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        person.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(person.email, key: Key('mock-email-${person.key}')),
                      const SizedBox(height: 8),
                      Text(_scenario(l10n, person.key)),
                      const SizedBox(height: 8),
                      if (coordinator?.active?.personaKey == person.key)
                        Text(
                          l10n.mockCurrentAccount,
                          key: Key('mock-current-${person.key}'),
                        ),
                      FilledButton(
                        key: Key('mock-login-${person.key}'),
                        onPressed:
                            coordinator == null ||
                                coordinator.busy ||
                                coordinator.active?.personaKey == person.key ||
                                coordinator.access.clientId != _catalogRoot
                            ? null
                            : () async {
                                await coordinator.select(
                                  person,
                                  prepareDeparture: () =>
                                      prepareRealmDeparture(context, ref),
                                );
                              },
                        child: Text(l10n.mockLogIn),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return coordinator == null
        ? screen()
        : ListenableBuilder(
            listenable: coordinator,
            builder: (_, _) => screen(),
          );
  }
}
