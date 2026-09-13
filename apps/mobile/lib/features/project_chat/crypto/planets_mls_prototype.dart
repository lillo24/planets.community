import 'dart:convert';
import 'dart:typed_data';

import 'package:openmls/openmls.dart';

/// The RFC 9420 ciphersuite validated by the PLANETS 07B2A prototype.
///
/// This is an IANA-registered classical suite. The wrapper also exposes
/// experimental post-quantum suites, but this prototype deliberately neither
/// selects nor advertises them.
const planetsMlsPrototypeCiphersuite =
    MlsCiphersuite.mls128DhkemX25519Aes128GcmSha256Ed25519;

final _planetsMlsPrototypeCapabilities = MlsCapabilities(
  versions: Uint16List(0),
  ciphersuites: Uint16List.fromList(const [0x0001]),
  extensions: Uint16List(0),
  proposals: Uint16List(0),
  credentials: Uint16List(0),
);

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Per-installation MLS signing identity for the architecture prototype.
///
/// The BasicCredential identity contains only the stable PLANETS profile UUID
/// and a random app-installation UUID. It is a self-assertion inside MLS, not
/// proof of account ownership; 07B2B must Auth-bind published public material
/// to the current profile on the backend. The serialized signer is private and
/// must be encrypted with a platform-keystore/keychain-backed key in production.
class PlanetsMlsPrototypeIdentity {
  PlanetsMlsPrototypeIdentity._({
    required this.profileId,
    required this.installationId,
    required this._signer,
    required this._publicKey,
    required this._credentialIdentity,
  });

  factory PlanetsMlsPrototypeIdentity.generate({
    required String profileId,
    required String installationId,
  }) {
    _requireUuid(profileId, field: 'profileId');
    _requireUuid(installationId, field: 'installationId');

    final keyPair = MlsSignatureKeyPair.generate(
      ciphersuite: planetsMlsPrototypeCiphersuite,
    );
    final publicKey = keyPair.publicKey();
    final privateKey = SecureBytes.wrap(keyPair.privateKey());
    final credentialIdentity = Uint8List.fromList(
      utf8.encode(
        'planets-mls-basic-v1|${profileId.toLowerCase()}|'
        '${installationId.toLowerCase()}',
      ),
    );
    late final SecureBytes signer;
    try {
      signer = SecureBytes.wrap(
        serializeSigner(
          ciphersuite: planetsMlsPrototypeCiphersuite,
          privateKey: privateKey.bytes,
          publicKey: publicKey,
        ),
      );
    } finally {
      privateKey.dispose();
    }

    return PlanetsMlsPrototypeIdentity._(
      profileId: profileId.toLowerCase(),
      installationId: installationId.toLowerCase(),
      signer: signer,
      publicKey: publicKey,
      credentialIdentity: credentialIdentity,
    );
  }

  final String profileId;
  final String installationId;
  final SecureBytes _signer;
  final Uint8List _publicKey;
  final Uint8List _credentialIdentity;

  Uint8List get publicKey => Uint8List.fromList(_publicKey);

  Uint8List get credentialIdentity => Uint8List.fromList(_credentialIdentity);

  Uint8List get serializedBasicCredential =>
      MlsCredential.basic(identity: _credentialIdentity).serialize();

  List<int> get _signerBytes => _signer.bytes;

  void dispose() {
    _signer.dispose();
  }

  static void _requireUuid(String value, {required String field}) {
    if (!_uuidPattern.hasMatch(value)) {
      throw ArgumentError.value(value, field, 'must be an RFC 4122 UUID');
    }
  }
}

/// Thin, non-production adapter used to exercise the reviewed OpenMLS binding.
///
/// It owns no transport, authorization, account switching, secure-key storage,
/// or UI. Each instance must receive its own database path and 32-byte storage
/// key; production lifecycle wiring remains explicit 07B2B work.
class PlanetsMlsPrototypeClient {
  PlanetsMlsPrototypeClient._({required this.identity, required this._engine});

  static Future<PlanetsMlsPrototypeClient> open({
    required PlanetsMlsPrototypeIdentity identity,
    required String databasePath,
    required List<int> storageEncryptionKey,
  }) async {
    if (storageEncryptionKey.length != 32) {
      throw ArgumentError.value(
        storageEncryptionKey.length,
        'storageEncryptionKey',
        'must contain exactly 32 bytes',
      );
    }

    return PlanetsMlsPrototypeClient._(
      identity: identity,
      engine: await MlsEngine.create(
        dbPath: databasePath,
        encryptionKey: storageEncryptionKey,
      ),
    );
  }

  final PlanetsMlsPrototypeIdentity identity;
  final MlsEngine _engine;

  bool get isClosed => _engine.isClosed();

  MlsGroupConfig get _groupConfig =>
      MlsGroupConfig.defaultConfig(ciphersuite: planetsMlsPrototypeCiphersuite);

  Future<CreateGroupResult> createGroup({Uint8List? groupId}) {
    return _engine.createGroupWithBuilder(
      config: _groupConfig,
      signerBytes: identity._signerBytes,
      credentialIdentity: identity._credentialIdentity,
      signerPublicKey: identity._publicKey,
      groupId: groupId,
      capabilities: _planetsMlsPrototypeCapabilities,
    );
  }

  Future<KeyPackageResult> createKeyPackage() {
    return _engine.createKeyPackageWithOptions(
      ciphersuite: planetsMlsPrototypeCiphersuite,
      signerBytes: identity._signerBytes,
      credentialIdentity: identity._credentialIdentity,
      signerPublicKey: identity._publicKey,
      options: KeyPackageOptions(
        lastResort: false,
        capabilities: _planetsMlsPrototypeCapabilities,
      ),
    );
  }

  Future<AddMembersResult> addClient({
    required List<int> groupId,
    required List<int> keyPackage,
  }) {
    return _engine.addMembers(
      groupIdBytes: groupId,
      signerBytes: identity._signerBytes,
      keyPackagesBytes: [Uint8List.fromList(keyPackage)],
    );
  }

  Future<JoinGroupResult> joinFromWelcome({required List<int> welcome}) {
    return _engine.joinGroupFromWelcome(
      config: _groupConfig,
      welcomeBytes: welcome,
      signerBytes: identity._signerBytes,
    );
  }

  Future<CreateMessageResult> encryptApplicationMessage({
    required List<int> groupId,
    required List<int> plaintext,
  }) {
    return _engine.createMessage(
      groupIdBytes: groupId,
      signerBytes: identity._signerBytes,
      message: plaintext,
    );
  }

  Future<ProcessedMessageResult> processProtocolMessage({
    required List<int> groupId,
    required List<int> message,
  }) {
    return _engine.processMessage(groupIdBytes: groupId, messageBytes: message);
  }

  Future<CommitResult> removeClient({
    required List<int> groupId,
    required PlanetsMlsPrototypeIdentity member,
  }) async {
    final memberIndex = await _engine.groupMemberLeafIndex(
      groupIdBytes: groupId,
      credentialBytes: member.serializedBasicCredential,
    );
    if (memberIndex == null) {
      throw StateError(
        'MLS client ${member.installationId} is not a current group leaf.',
      );
    }

    return _engine.removeMembers(
      groupIdBytes: groupId,
      signerBytes: identity._signerBytes,
      memberIndices: [memberIndex],
    );
  }

  Future<List<MlsMemberInfo>> members({required List<int> groupId}) {
    return _engine.groupMembers(groupIdBytes: groupId);
  }

  Future<BigInt> epoch({required List<int> groupId}) {
    return _engine.groupEpoch(groupIdBytes: groupId);
  }

  Future<bool> groupIsActive({required List<int> groupId}) {
    return _engine.groupIsActive(groupIdBytes: groupId);
  }

  Future<Uint8List> exportGroupInfo({required List<int> groupId}) {
    return _engine.exportGroupInfo(
      groupIdBytes: groupId,
      signerBytes: identity._signerBytes,
    );
  }

  Future<void> close() {
    return _engine.close();
  }
}
