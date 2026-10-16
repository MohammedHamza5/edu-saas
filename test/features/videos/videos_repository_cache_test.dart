import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/features/videos/data/datasources/videos_remote_datasource.dart';
import 'package:edu_saas/features/videos/data/repositories/videos_repository_impl.dart';

class _FakeVideosRemoteDataSource implements VideosRemoteDataSource {
  int getSignedFileUrlCallCount = 0;
  String returnedUrl = 'https://example.com/test.pdf?token=abc';

  @override
  Future<String> getSignedFileUrl({
    required String storagePath,
    int expiresInSeconds = 3600,
  }) async {
    getSignedFileUrlCallCount++;
    return returnedUrl;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('VideosRepositoryImpl Signed URL Caching', () {
    late _FakeVideosRemoteDataSource fakeRemoteDataSource;
    late VideosRepositoryImpl repository;

    setUp(() {
      VideosRepositoryImpl.clearSignedUrlCache();
      fakeRemoteDataSource = _FakeVideosRemoteDataSource();
      repository = VideosRepositoryImpl(remoteDataSource: fakeRemoteDataSource);
    });

    tearDown(() {
      VideosRepositoryImpl.clearSignedUrlCache();
    });

    test('returns cached URL on second call without invoking remote datasource', () async {
      const storagePath = 'groups/123/lesson1.pdf';

      final firstResult = await repository.getSignedFileUrl(storagePath);
      expect(firstResult.isSuccess, isTrue);
      expect(firstResult.dataOrNull, 'https://example.com/test.pdf?token=abc');
      expect(fakeRemoteDataSource.getSignedFileUrlCallCount, 1);

      // Second call should return immediately from cache
      final secondResult = await repository.getSignedFileUrl(storagePath);
      expect(secondResult.isSuccess, isTrue);
      expect(secondResult.dataOrNull, 'https://example.com/test.pdf?token=abc');
      expect(fakeRemoteDataSource.getSignedFileUrlCallCount, 1);
    });

    test('clearSignedUrlCache forces fresh remote fetch on subsequent call', () async {
      const storagePath = 'groups/123/lesson1.pdf';

      await repository.getSignedFileUrl(storagePath);
      expect(fakeRemoteDataSource.getSignedFileUrlCallCount, 1);

      VideosRepositoryImpl.clearSignedUrlCache();

      await repository.getSignedFileUrl(storagePath);
      expect(fakeRemoteDataSource.getSignedFileUrlCallCount, 2);
    });
  });
}
