import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:digitalvault_mobile/core/services/content_access_service.dart';
import 'package:digitalvault_mobile/core/services/symmetric_crypto_service.dart';

// Generate mocks
@GenerateMocks([SymmetricCryptoService])
import 'content_access_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContentAccessService', () {
    late ContentAccessService accessService;
    late MockSymmetricCryptoService mockCryptoService;

    setUp(() {
      mockCryptoService = MockSymmetricCryptoService();
      accessService = ContentAccessService(
        cryptoService: mockCryptoService,
      );

      // Clear shared preferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    group('addToLibrary', () {
      test('adds new content to empty library', () async {
        // Arrange
        final content = OwnedContent(
          contentId: '1',
          title: 'Test Content',
          description: 'Test Description',
          ipfsCid: 'QmTest123',
          category: 'art',
          fileSize: BigInt.from(1024),
          acquiredDate: DateTime(2024, 1, 1),
          encryptedKey: '0xkey123',
          isOriginalOwner: true,
        );

        // Act
        await accessService.addToLibrary(content: content);

        // Assert
        final library = await accessService.getOwnedContent();
        expect(library.length, equals(1));
        expect(library.first.contentId, equals('1'));
        expect(library.first.title, equals('Test Content'));
      });

      test('updates existing content in library', () async {
        // Arrange
        final content1 = OwnedContent(
          contentId: '1',
          title: 'Original Title',
          description: 'Original Description',
          ipfsCid: 'QmTest123',
          category: 'art',
          fileSize: BigInt.from(1024),
          acquiredDate: DateTime(2024, 1, 1),
          encryptedKey: '0xkey123',
          isOriginalOwner: true,
        );

        final content2 = OwnedContent(
          contentId: '1',
          title: 'Updated Title',
          description: 'Updated Description',
          ipfsCid: 'QmTest123',
          category: 'art',
          fileSize: BigInt.from(1024),
          acquiredDate: DateTime(2024, 1, 1),
          encryptedKey: '0xkey123',
          isOriginalOwner: true,
        );

        // Act
        await accessService.addToLibrary(content: content1);
        await accessService.addToLibrary(content: content2);

        // Assert
        final library = await accessService.getOwnedContent();
        expect(library.length, equals(1));
        expect(library.first.title, equals('Updated Title'));
      });

      test('adds multiple different content items', () async {
        // Arrange
        final content1 = OwnedContent(
          contentId: '1',
          title: 'Content 1',
          ipfsCid: 'QmTest1',
          category: 'art',
          fileSize: BigInt.from(1024),
          acquiredDate: DateTime(2024, 1, 1),
          encryptedKey: '0xkey1',
          isOriginalOwner: true,
        );

        final content2 = OwnedContent(
          contentId: '2',
          title: 'Content 2',
          ipfsCid: 'QmTest2',
          category: 'music',
          fileSize: BigInt.from(2048),
          acquiredDate: DateTime(2024, 1, 2),
          encryptedKey: '0xkey2',
          isOriginalOwner: false,
        );

        // Act
        await accessService.addToLibrary(content: content1);
        await accessService.addToLibrary(content: content2);

        // Assert
        final library = await accessService.getOwnedContent();
        expect(library.length, equals(2));
      });
    });

    group('getOwnedContent', () {
      test('returns empty list when no content', () async {
        // Act
        final library = await accessService.getOwnedContent();

        // Assert
        expect(library, isEmpty);
      });

      test('returns all stored content', () async {
        // Arrange
        final content1 = OwnedContent(
          contentId: '1',
          title: 'Content 1',
          ipfsCid: 'QmTest1',
          category: 'art',
          fileSize: BigInt.from(1024),
          acquiredDate: DateTime(2024, 1, 1),
          encryptedKey: '0xkey1',
          isOriginalOwner: true,
        );

        final content2 = OwnedContent(
          contentId: '2',
          title: 'Content 2',
          ipfsCid: 'QmTest2',
          category: 'music',
          fileSize: BigInt.from(2048),
          acquiredDate: DateTime(2024, 1, 2),
          encryptedKey: '0xkey2',
          isOriginalOwner: false,
        );

        await accessService.addToLibrary(content: content1);
        await accessService.addToLibrary(content: content2);

        // Act
        final library = await accessService.getOwnedContent();

        // Assert
        expect(library.length, equals(2));
        expect(library.map((c) => c.contentId), containsAll(['1', '2']));
      });
    });

    group('getOwnedContentById', () {
      test('returns content when it exists', () async {
        // Arrange
        final content = OwnedContent(
          contentId: '1',
          title: 'Test Content',
          ipfsCid: 'QmTest123',
          category: 'art',
          fileSize: BigInt.from(1024),
          acquiredDate: DateTime(2024, 1, 1),
          encryptedKey: '0xkey123',
          isOriginalOwner: true,
        );

        await accessService.addToLibrary(content: content);

        // Act
        final result = await accessService.getOwnedContentById('1');

        // Assert
        expect(result, isNotNull);
        expect(result!.contentId, equals('1'));
        expect(result.title, equals('Test Content'));
      });

      test('returns null when content does not exist', () async {
        // Act
        final result = await accessService.getOwnedContentById('999');

        // Assert
        expect(result, isNull);
      });
    });

    group('removeFromLibrary', () {
      test('removes content from library', () async {
        // Arrange
        final content = OwnedContent(
          contentId: '1',
          title: 'Test Content',
          ipfsCid: 'QmTest123',
          category: 'art',
          fileSize: BigInt.from(1024),
          acquiredDate: DateTime(2024, 1, 1),
          encryptedKey: '0xkey123',
          isOriginalOwner: true,
        );

        await accessService.addToLibrary(content: content);

        // Act
        await accessService.removeFromLibrary('1');

        // Assert
        final library = await accessService.getOwnedContent();
        expect(library, isEmpty);
      });

      test('only removes specified content', () async {
        // Arrange
        final content1 = OwnedContent(
          contentId: '1',
          title: 'Content 1',
          ipfsCid: 'QmTest1',
          category: 'art',
          fileSize: BigInt.from(1024),
          acquiredDate: DateTime(2024, 1, 1),
          encryptedKey: '0xkey1',
          isOriginalOwner: true,
        );

        final content2 = OwnedContent(
          contentId: '2',
          title: 'Content 2',
          ipfsCid: 'QmTest2',
          category: 'music',
          fileSize: BigInt.from(2048),
          acquiredDate: DateTime(2024, 1, 2),
          encryptedKey: '0xkey2',
          isOriginalOwner: false,
        );

        await accessService.addToLibrary(content: content1);
        await accessService.addToLibrary(content: content2);

        // Act
        await accessService.removeFromLibrary('1');

        // Assert
        final library = await accessService.getOwnedContent();
        expect(library.length, equals(1));
        expect(library.first.contentId, equals('2'));
      });
    });

    group('getContentByCategory', () {
      test('returns only content matching category', () async {
        // Arrange
        final art1 = OwnedContent(
          contentId: '1',
          title: 'Art 1',
          ipfsCid: 'QmTest1',
          category: 'art',
          fileSize: BigInt.from(1024),
          acquiredDate: DateTime(2024, 1, 1),
          encryptedKey: '0xkey1',
          isOriginalOwner: true,
        );

        final music1 = OwnedContent(
          contentId: '2',
          title: 'Music 1',
          ipfsCid: 'QmTest2',
          category: 'music',
          fileSize: BigInt.from(2048),
          acquiredDate: DateTime(2024, 1, 2),
          encryptedKey: '0xkey2',
          isOriginalOwner: false,
        );

        final art2 = OwnedContent(
          contentId: '3',
          title: 'Art 2',
          ipfsCid: 'QmTest3',
          category: 'art',
          fileSize: BigInt.from(3072),
          acquiredDate: DateTime(2024, 1, 3),
          encryptedKey: '0xkey3',
          isOriginalOwner: true,
        );

        await accessService.addToLibrary(content: art1);
        await accessService.addToLibrary(content: music1);
        await accessService.addToLibrary(content: art2);

        // Act
        final artContent = await accessService.getContentByCategory('art');

        // Assert
        expect(artContent.length, equals(2));
        expect(artContent.every((c) => c.category == 'art'), isTrue);
      });
    });

    group('getContentByOwnership', () {
      test('separates owned and purchased content', () async {
        // Arrange
        final owned = OwnedContent(
          contentId: '1',
          title: 'Owned',
          ipfsCid: 'QmTest1',
          category: 'art',
          fileSize: BigInt.from(1024),
          acquiredDate: DateTime(2024, 1, 1),
          encryptedKey: '0xkey1',
          isOriginalOwner: true,
        );

        final purchased = OwnedContent(
          contentId: '2',
          title: 'Purchased',
          ipfsCid: 'QmTest2',
          category: 'music',
          fileSize: BigInt.from(2048),
          acquiredDate: DateTime(2024, 1, 2),
          encryptedKey: '0xkey2',
          isOriginalOwner: false,
        );

        await accessService.addToLibrary(content: owned);
        await accessService.addToLibrary(content: purchased);

        // Act
        final result = await accessService.getContentByOwnership();

        // Assert
        expect(result['owned']!.length, equals(1));
        expect(result['purchased']!.length, equals(1));
        expect(result['owned']!.first.contentId, equals('1'));
        expect(result['purchased']!.first.contentId, equals('2'));
      });
    });

    group('canAccess', () {
      test('returns true when content exists with key', () async {
        // Arrange
        final content = OwnedContent(
          contentId: '1',
          title: 'Test Content',
          ipfsCid: 'QmTest123',
          category: 'art',
          fileSize: BigInt.from(1024),
          acquiredDate: DateTime(2024, 1, 1),
          encryptedKey: '0xkey123',
          isOriginalOwner: true,
        );

        await accessService.addToLibrary(content: content);

        // Act
        final result = await accessService.canAccess('1');

        // Assert
        expect(result, isTrue);
      });

      test('returns false when content does not exist', () async {
        // Act
        final result = await accessService.canAccess('999');

        // Assert
        expect(result, isFalse);
      });
    });
  });

  group('OwnedContent', () {
    test('formattedFileSize formats bytes correctly', () {
      final content = OwnedContent(
        contentId: '1',
        title: 'Test',
        ipfsCid: 'QmTest',
        category: 'art',
        fileSize: BigInt.from(500),
        acquiredDate: DateTime(2024, 1, 1),
        encryptedKey: '0xkey',
        isOriginalOwner: true,
      );

      expect(content.formattedFileSize, equals('500 B'));
    });

    test('formattedFileSize formats KB correctly', () {
      final content = OwnedContent(
        contentId: '1',
        title: 'Test',
        ipfsCid: 'QmTest',
        category: 'art',
        fileSize: BigInt.from(1536), // 1.5 KB
        acquiredDate: DateTime(2024, 1, 1),
        encryptedKey: '0xkey',
        isOriginalOwner: true,
      );

      expect(content.formattedFileSize, equals('1.5 KB'));
    });

    test('formattedFileSize formats MB correctly', () {
      final content = OwnedContent(
        contentId: '1',
        title: 'Test',
        ipfsCid: 'QmTest',
        category: 'art',
        fileSize: BigInt.from(1572864), // 1.5 MB
        acquiredDate: DateTime(2024, 1, 1),
        encryptedKey: '0xkey',
        isOriginalOwner: true,
      );

      expect(content.formattedFileSize, equals('1.5 MB'));
    });

    test('toJson and fromJson round trip works', () {
      // Arrange
      final original = OwnedContent(
        contentId: '1',
        title: 'Test Content',
        description: 'Test Description',
        ipfsCid: 'QmTest123',
        category: 'art',
        fileSize: BigInt.from(1024),
        acquiredDate: DateTime(2024, 1, 1, 12, 0),
        encryptedKey: '0xkey123',
        isOriginalOwner: true,
        localFilePath: '/path/to/file',
      );

      // Act
      final json = original.toJson();
      final result = OwnedContent.fromJson(json);

      // Assert
      expect(result.contentId, equals(original.contentId));
      expect(result.title, equals(original.title));
      expect(result.description, equals(original.description));
      expect(result.ipfsCid, equals(original.ipfsCid));
      expect(result.category, equals(original.category));
      expect(result.fileSize, equals(original.fileSize));
      expect(result.encryptedKey, equals(original.encryptedKey));
      expect(result.isOriginalOwner, equals(original.isOriginalOwner));
      expect(result.localFilePath, equals(original.localFilePath));
    });
  });
}
