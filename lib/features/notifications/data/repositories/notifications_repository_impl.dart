import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_remote_datasource.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsRemoteDataSource _remoteDataSource;

  NotificationsRepositoryImpl({NotificationsRemoteDataSource? remoteDataSource})
    : _remoteDataSource =
          remoteDataSource ?? NotificationsRemoteDataSourceImpl();

  @override
  Future<Result<List<NotificationEntity>>> getMyNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final items = await _remoteDataSource.getMyNotifications(
        limit: limit,
        offset: offset,
      );
      return Success(items);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<int>> getUnreadCount() async {
    try {
      final count = await _remoteDataSource.getUnreadCount();
      return Success(count);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> markAsRead(String recipientId) async {
    try {
      await _remoteDataSource.markAsRead(recipientId);
      return const Success(null);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> markAllAsRead() async {
    try {
      await _remoteDataSource.markAllAsRead();
      return const Success(null);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> sendAnnouncement({
    required String title,
    required String body,
    String? groupId,
  }) async {
    try {
      await _remoteDataSource.sendAnnouncement(
        title: title,
        body: body,
        groupId: groupId,
      );
      return const Success(null);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }
}
