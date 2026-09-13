import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openmls/openmls.dart';
import 'package:planets_mobile/features/project_chat/crypto/planets_mls_prototype.dart';

void main() {
  setUpAll(Openmls.init);

  group('PLANETS OpenMLS architecture prototype', () {
    test(
      'enforces join, removal, rejoin-gap, and encrypted restart boundaries',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'planets_mls_prototype_',
        );
        final clients = <PlanetsMlsPrototypeClient>[];
        final identities = <PlanetsMlsPrototypeIdentity>[];

        addTearDown(() async {
          for (final client in clients.reversed) {
            await client.close();
          }
          for (final identity in identities) {
            identity.dispose();
          }
          directory.deleteSync(recursive: true);
        });

        final creatorIdentity = PlanetsMlsPrototypeIdentity.generate(
          profileId: 'c0000000-0000-4000-8000-000000000001',
          installationId: 'c1000000-0000-4000-8000-000000000001',
        );
        final participantAIdentity = PlanetsMlsPrototypeIdentity.generate(
          profileId: 'a0000000-0000-4000-8000-000000000001',
          installationId: 'a1000000-0000-4000-8000-000000000001',
        );
        final participantBIdentity = PlanetsMlsPrototypeIdentity.generate(
          profileId: 'b0000000-0000-4000-8000-000000000001',
          installationId: 'b1000000-0000-4000-8000-000000000001',
        );
        final participantARejoinIdentity = PlanetsMlsPrototypeIdentity.generate(
          profileId: participantAIdentity.profileId,
          installationId: 'a2000000-0000-4000-8000-000000000002',
        );
        identities.addAll([
          creatorIdentity,
          participantAIdentity,
          participantBIdentity,
          participantARejoinIdentity,
        ]);

        expect(
          utf8.decode(creatorIdentity.credentialIdentity),
          allOf(
            contains(creatorIdentity.profileId),
            contains(creatorIdentity.installationId),
            isNot(contains('@')),
          ),
        );

        String databasePath(String clientName) =>
            '${directory.path}${Platform.pathSeparator}$clientName.db';

        final creatorDatabasePath = databasePath('creator');
        final participantADatabasePath = databasePath('participant-a');
        final participantBDatabasePath = databasePath('participant-b');
        final participantARejoinDatabasePath = databasePath(
          'participant-a-rejoin',
        );

        final creatorStorageKey = _randomStorageKey();
        final participantAStorageKey = _randomStorageKey();
        final participantBStorageKey = _randomStorageKey();
        final participantARejoinStorageKey = _randomStorageKey();

        var creator = await PlanetsMlsPrototypeClient.open(
          identity: creatorIdentity,
          databasePath: creatorDatabasePath,
          storageEncryptionKey: creatorStorageKey,
        );
        var participantA = await PlanetsMlsPrototypeClient.open(
          identity: participantAIdentity,
          databasePath: participantADatabasePath,
          storageEncryptionKey: participantAStorageKey,
        );
        final participantB = await PlanetsMlsPrototypeClient.open(
          identity: participantBIdentity,
          databasePath: participantBDatabasePath,
          storageEncryptionKey: participantBStorageKey,
        );
        final participantARejoin = await PlanetsMlsPrototypeClient.open(
          identity: participantARejoinIdentity,
          databasePath: participantARejoinDatabasePath,
          storageEncryptionKey: participantARejoinStorageKey,
        );
        clients.addAll([
          creator,
          participantA,
          participantB,
          participantARejoin,
        ]);

        final group = await creator.createGroup(
          groupId: Uint8List.fromList(
            utf8.encode('planets-project-chat-00000000-0000-4000-8000-1'),
          ),
        );
        final groupId = group.groupId;
        expect(await creator.epoch(groupId: groupId), BigInt.zero);

        final participantAKeyPackage = await participantA.createKeyPackage();
        final addParticipantA = await creator.addClient(
          groupId: groupId,
          keyPackage: participantAKeyPackage.keyPackageBytes,
        );
        final participantAJoin = await participantA.joinFromWelcome(
          welcome: addParticipantA.welcome,
        );
        expect(participantAJoin.groupId, groupId);
        expect(await creator.members(groupId: groupId), hasLength(2));

        await creator.close();
        expect(creator.isClosed, isTrue);
        creator = await PlanetsMlsPrototypeClient.open(
          identity: creatorIdentity,
          databasePath: creatorDatabasePath,
          storageEncryptionKey: creatorStorageKey,
        );
        clients.add(creator);
        expect(await creator.members(groupId: groupId), hasLength(2));

        const firstPlaintext = 'message after A joined';
        final firstMessage = await creator.encryptApplicationMessage(
          groupId: groupId,
          plaintext: utf8.encode(firstPlaintext),
        );
        final firstForA = await participantA.processProtocolMessage(
          groupId: groupId,
          message: firstMessage.ciphertext,
        );
        expect(firstForA.messageType, ProcessedMessageType.application);
        expect(utf8.decode(firstForA.applicationMessage!), firstPlaintext);

        await participantA.close();
        participantA = await PlanetsMlsPrototypeClient.open(
          identity: participantAIdentity,
          databasePath: participantADatabasePath,
          storageEncryptionKey: participantAStorageKey,
        );
        clients.add(participantA);
        final replyAfterReload = await participantA.encryptApplicationMessage(
          groupId: groupId,
          plaintext: utf8.encode('A persisted and reloaded'),
        );
        final replyForCreator = await creator.processProtocolMessage(
          groupId: groupId,
          message: replyAfterReload.ciphertext,
        );
        expect(
          utf8.decode(replyForCreator.applicationMessage!),
          'A persisted and reloaded',
        );

        await expectLater(
          participantB.processProtocolMessage(
            groupId: groupId,
            message: firstMessage.ciphertext,
          ),
          throwsA(isA<Object>()),
        );

        final participantBKeyPackage = await participantB.createKeyPackage();
        final addParticipantB = await creator.addClient(
          groupId: groupId,
          keyPackage: participantBKeyPackage.keyPackageBytes,
        );
        final addParticipantBForA = await participantA.processProtocolMessage(
          groupId: groupId,
          message: addParticipantB.commit,
        );
        expect(
          addParticipantBForA.messageType,
          ProcessedMessageType.stagedCommit,
        );
        await participantB.joinFromWelcome(welcome: addParticipantB.welcome);
        expect(await participantB.members(groupId: groupId), hasLength(3));

        await expectLater(
          participantB.processProtocolMessage(
            groupId: groupId,
            message: firstMessage.ciphertext,
          ),
          throwsA(isA<Object>()),
        );

        const afterBJoinedPlaintext = 'message after B joined';
        final afterBJoined = await creator.encryptApplicationMessage(
          groupId: groupId,
          plaintext: utf8.encode(afterBJoinedPlaintext),
        );
        for (final receiver in [participantA, participantB]) {
          final received = await receiver.processProtocolMessage(
            groupId: groupId,
            message: afterBJoined.ciphertext,
          );
          expect(
            utf8.decode(received.applicationMessage!),
            afterBJoinedPlaintext,
          );
        }

        final removeParticipantA = await creator.removeClient(
          groupId: groupId,
          member: participantAIdentity,
        );
        final removalForA = await participantA.processProtocolMessage(
          groupId: groupId,
          message: removeParticipantA.commit,
        );
        final removalForB = await participantB.processProtocolMessage(
          groupId: groupId,
          message: removeParticipantA.commit,
        );
        expect(removalForA.messageType, ProcessedMessageType.stagedCommit);
        expect(removalForB.messageType, ProcessedMessageType.stagedCommit);
        expect(await participantA.groupIsActive(groupId: groupId), isFalse);

        const removedGapPlaintext = 'message while A is removed';
        final removedGapMessage = await creator.encryptApplicationMessage(
          groupId: groupId,
          plaintext: utf8.encode(removedGapPlaintext),
        );
        final removedGapForB = await participantB.processProtocolMessage(
          groupId: groupId,
          message: removedGapMessage.ciphertext,
        );
        expect(
          utf8.decode(removedGapForB.applicationMessage!),
          removedGapPlaintext,
        );
        await expectLater(
          participantA.processProtocolMessage(
            groupId: groupId,
            message: removedGapMessage.ciphertext,
          ),
          throwsA(isA<Object>()),
        );

        final rejoinKeyPackage = await participantARejoin.createKeyPackage();
        final readdParticipantA = await creator.addClient(
          groupId: groupId,
          keyPackage: rejoinKeyPackage.keyPackageBytes,
        );
        await participantB.processProtocolMessage(
          groupId: groupId,
          message: readdParticipantA.commit,
        );
        await participantARejoin.joinFromWelcome(
          welcome: readdParticipantA.welcome,
        );
        expect(await creator.members(groupId: groupId), hasLength(3));

        await expectLater(
          participantARejoin.processProtocolMessage(
            groupId: groupId,
            message: removedGapMessage.ciphertext,
          ),
          throwsA(isA<Object>()),
        );

        const afterRejoinPlaintext = 'message after A rejoined';
        final afterRejoinMessage = await creator.encryptApplicationMessage(
          groupId: groupId,
          plaintext: utf8.encode(afterRejoinPlaintext),
        );
        for (final receiver in [participantB, participantARejoin]) {
          final received = await receiver.processProtocolMessage(
            groupId: groupId,
            message: afterRejoinMessage.ciphertext,
          );
          expect(
            utf8.decode(received.applicationMessage!),
            afterRejoinPlaintext,
          );
        }
        await expectLater(
          participantA.processProtocolMessage(
            groupId: groupId,
            message: afterRejoinMessage.ciphertext,
          ),
          throwsA(isA<Object>()),
        );

        for (final client in [
          creator,
          participantA,
          participantB,
          participantARejoin,
        ]) {
          await client.close();
        }

        final databaseBytes = [
          creatorDatabasePath,
          participantADatabasePath,
          participantBDatabasePath,
          participantARejoinDatabasePath,
        ].map((path) => File(path).readAsBytesSync()).toList();
        for (final bytes in databaseBytes) {
          expect(bytes, isNotEmpty);
          expect(_contains(bytes, utf8.encode('SQLite format 3')), isFalse);
          expect(_contains(bytes, utf8.encode(firstPlaintext)), isFalse);
          expect(_contains(bytes, utf8.encode(removedGapPlaintext)), isFalse);
          expect(
            _contains(bytes, utf8.encode('planets-mls-basic-v1')),
            isFalse,
          );
        }
        expect(databaseBytes[0], isNot(equals(databaseBytes[1])));
      },
    );
  });
}

Uint8List _randomStorageKey() {
  final random = Random.secure();
  return Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
}

bool _contains(List<int> haystack, List<int> needle) {
  for (var start = 0; start + needle.length <= haystack.length; start++) {
    var matched = true;
    for (var offset = 0; offset < needle.length; offset++) {
      if (haystack[start + offset] != needle[offset]) {
        matched = false;
        break;
      }
    }
    if (matched) {
      return true;
    }
  }
  return false;
}
