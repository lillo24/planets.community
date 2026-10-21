import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/page_app_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/mock_mode_coordinator.dart';
import '../application/realm_departure.dart';
import '../domain/mock_models.dart';

/// Minimal real-session adapter for MOCK02. MOCK03 completes the account-picker
/// presentation; all selection already uses the single coordinator and broker.
class MockAccountsScreen extends ConsumerStatefulWidget {
  const MockAccountsScreen({super.key});
  @override
  ConsumerState<MockAccountsScreen> createState() => _MockAccountsScreenState();
}

class _MockAccountsScreenState extends ConsumerState<MockAccountsScreen> {
  List<MockPersona>? _people;
  MockFailureKind? _failure;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _people = null;
      _failure = null;
    });
    try {
      final controller = ref.read(mockModeCoordinatorProvider);
      if (controller == null) {
        throw const MockFailure(MockFailureKind.unavailable);
      }
      final people = await controller.catalog();
      if (mounted) setState(() => _people = people);
    } catch (error) {
      if (mounted) {
        setState(
          () => _failure = error is MockFailure
              ? error.kind
              : MockFailureKind.unavailable,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final coordinator = ref.watch(mockModeCoordinatorProvider);
    return Scaffold(
      appBar: pageAppBar(context, title: Text(l10n.mockAccountsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_failure != null) ...[
              Text(
                _failure == MockFailureKind.denied
                    ? l10n.mockDenied
                    : _failure == MockFailureKind.controlLoginRequired
                    ? l10n.mockControlLogin
                    : l10n.mockRecovery,
              ),
              TextButton(onPressed: _load, child: Text(l10n.retryAction)),
            ],
            if (_people?.isEmpty == true) Text(l10n.mockAccountsEmpty),
            for (final person in _people ?? <MockPersona>[])
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(person.name),
                      Text(person.email),
                      FilledButton(
                        key: Key('mock-login-${person.key}'),
                        onPressed: coordinator == null
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
  }
}
