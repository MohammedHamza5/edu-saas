import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/features/students/domain/entities/student_entity.dart';
import 'package:edu_saas/features/students/presentation/dialogs/smart_student_approval_dialog.dart';

void main() {
  group('Student Subscription & Expiration Unit Tests', () {
    test('Unlimited account has no expiration limit', () {
      final student = StudentEntity(
        id: 's-1',
        tenantId: 't-1',
        fullName: 'Omar Aly',
        email: 'omar@example.com',
        status: 'active',
        createdAt: DateTime.now(),
        subscriptionExpiresAt: null,
      );

      expect(student.hasSubscriptionLimit, isFalse);
      expect(student.isSubscriptionExpired, isFalse);
      expect(student.remainingSubscriptionDays, isNull);
    });

    test('Active account with future expiration returns correct days remaining', () {
      final futureDate = DateTime.now().add(const Duration(days: 40));
      final student = StudentEntity(
        id: 's-2',
        tenantId: 't-1',
        fullName: 'Layla Ahmed',
        email: 'layla@example.com',
        status: 'active',
        createdAt: DateTime.now(),
        subscriptionExpiresAt: futureDate,
      );

      expect(student.hasSubscriptionLimit, isTrue);
      expect(student.isSubscriptionExpired, isFalse);
      expect(student.remainingSubscriptionDays, inInclusiveRange(39, 41));
    });

    test('Elapsed subscription date flags isSubscriptionExpired as true', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 1));
      final student = StudentEntity(
        id: 's-3',
        tenantId: 't-1',
        fullName: 'Kareem Tarek',
        email: 'kareem@example.com',
        status: 'active',
        createdAt: DateTime.now(),
        subscriptionExpiresAt: pastDate,
      );

      expect(student.hasSubscriptionLimit, isTrue);
      expect(student.isSubscriptionExpired, isTrue);
      expect(student.remainingSubscriptionDays, isNegative);
    });

    test('StudentApprovalResult bundles groupIds and duration cleanly', () {
      final expires = DateTime.now().add(const Duration(days: 40));
      final result = StudentApprovalResult(
        groupIds: {'group-sat-1', 'group-basics'},
        subscriptionExpiresAt: expires,
      );

      expect(result.groupIds.length, 2);
      expect(result.groupIds.contains('group-sat-1'), isTrue);
      expect(result.subscriptionExpiresAt, equals(expires));
    });
  });
}
