import 'package:flutter_test/flutter_test.dart';

import 'package:autorent/core/services/recovery_key.dart';
import 'package:autorent/core/services/totp_service.dart';
import 'package:autorent/core/services/user_report_service.dart';
import 'package:autorent/models/user.dart';
import 'package:autorent/models/user_activity.dart';
import 'package:autorent/models/user_report.dart';
import 'package:autorent/core/utils/auth_messages.dart';
import 'package:autorent/core/utils/password_policy.dart';
import 'package:autorent/repositories/user_repository.dart';

void main() {
  group('RecoveryKey', () {
    test('has XXXX-XXXX-XXXX-XXXX format and no ambiguous characters', () {
      final k = RecoveryKey.generate();
      expect(RegExp(r'^[A-Z2-9]{4}(-[A-Z2-9]{4}){3}$').hasMatch(k), isTrue);
      expect(k.contains(RegExp(r'[01OI]')), isFalse);
    });

    test('is random', () {
      expect(RecoveryKey.generate(), isNot(RecoveryKey.generate()));
    });

    test('normalize accepts lowercase, spaces and missing dashes', () {
      expect(RecoveryKey.normalize('k7m2 9qxa-4tpd 8wnb'), 'K7M29QXA4TPD8WNB');
      expect(RecoveryKey.looksValid('k7m29qxa4tpd8wnb'), isTrue);
      expect(RecoveryKey.looksValid('K7M2-9QXA'), isFalse);
    });

    test('hash/verify round-trip, tolerant to formatting', () {
      final k = RecoveryKey.generate();
      final h = RecoveryKey.hash(k);
      expect(h.contains(k), isFalse);
      expect(RecoveryKey.verify(k.toLowerCase().replaceAll('-', ' '), h), isTrue);
      expect(RecoveryKey.verify(RecoveryKey.generate(), h), isFalse);
    });
  });

  group('PasswordPolicy', () {
    test('validate', () {
      expect(PasswordPolicy.validate('abc1'), isNotNull);
      expect(PasswordPolicy.validate('abcdefgh'), isNotNull);
      expect(PasswordPolicy.validate('12345678'), isNotNull);
      expect(PasswordPolicy.validate('abcdefg1'), isNull);
    });

    test('strength', () {
      expect(PasswordPolicy.strength('abc'), PasswordStrength.weak);
      expect(PasswordPolicy.strength('abcdefg1'), PasswordStrength.fair);
      expect(PasswordPolicy.strength('Abcdefg1'), PasswordStrength.good);
      expect(PasswordPolicy.strength('Abcdefghij1!'), PasswordStrength.strong);
    });
  });

  group('Lockout', () {
    test('durations', () {
      expect(UserRepository.lockDurationFor(4), Duration.zero);
      expect(UserRepository.lockDurationFor(5), const Duration(seconds: 60));
      expect(UserRepository.lockDurationFor(6), const Duration(seconds: 120));
      expect(UserRepository.lockDurationFor(7), const Duration(seconds: 240));
      expect(UserRepository.lockDurationFor(9), const Duration(minutes: 15));
      expect(UserRepository.lockDurationFor(50), const Duration(minutes: 15));
    });

    test('message', () {
      expect(lockMessage(const Duration(seconds: 80)), contains('1 min 20 s'));
      expect(lockMessage(const Duration(seconds: 45)), contains('45 s'));
      expect(lockMessage(const Duration(minutes: 2)), contains('2 min'));
    });
  });

  group('Totp (RFC 6238 / RFC 4648 vectors)', () {
    final ascii = '12345678901234567890'.codeUnits;

    test('RFC 6238 SHA-1 test vectors (8 digits)', () {
      const vectors = {
        59: '94287082',
        1111111109: '07081804',
        1111111111: '14050471',
        1234567890: '89005924',
        2000000000: '69279037',
        20000000000: '65353130',
      };
      vectors.forEach((t, expected) {
        expect(Totp.codeForStep(ascii, t ~/ 30, digits: 8), expected);
      });
      expect(Totp.codeForStep(ascii, 59 ~/ 30), '287082');
    });

    test('base32', () {
      expect(Totp.base32Encode(ascii), 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
      expect(Totp.base32Decode('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'), ascii);
      expect(Totp.base32Encode('foobar'.codeUnits), 'MZXW6YTBOI');
      expect(Totp.base32Decode('abc1'), isNull);
      expect(RegExp(r'^[A-Z2-7]{32}$').hasMatch(Totp.generateSecret()), isTrue);
    });

    test('verify: drift window, bad input, replay protection', () {
      const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
      final t0 = DateTime.fromMillisecondsSinceEpoch(1111111109 * 1000,
          isUtc: true);
      final step = Totp.stepAt(t0);
      final key = Totp.base32Decode(secret)!;
      final cur = Totp.codeForStep(key, step);
      final next = Totp.codeForStep(key, step + 1);
      final far = Totp.codeForStep(key, step + 3);

      expect(Totp.verify(secret, cur, now: t0), step);
      expect(Totp.verify(secret, next, now: t0), step + 1);
      expect(Totp.verify(secret, far, now: t0), isNull);
      expect(Totp.verify(secret, '12a456', now: t0), isNull);
      expect(Totp.verify(secret, '12345', now: t0), isNull);
      expect(Totp.verify(secret, cur, now: t0, lastStep: step), isNull);
    });

    test('otpauth URI', () {
      expect(
        Totp.otpauthUri(secret: 'ABC', account: 'a@b.tn'),
        'otpauth://totp/AutoRent:a%40b.tn?secret=ABC&issuer=AutoRent'
        '&algorithm=SHA1&digits=6&period=30',
      );
    });
  });

  group('UserReportService (PDF)', () {
    final now = DateTime(2026, 11, 9, 14, 32);
    final user = User(
      id: 3,
      lastName: 'Ben Salah',
      firstName: 'Élodie',
      email: 'elodie@autorent.tn',
      passwordHash: 'salt:hash',
      createdAt: DateTime(2026, 9, 2),
      recoveryKeyHash: 'h',
      totpSecret: 'SECRET',
    );

    test('money format matches the app (1,234.500 DT)', () {
      expect(UserReportService.money(0), '0.000 DT');
      expect(UserReportService.money(999.9), '999.900 DT');
      expect(UserReportService.money(1234.5), '1,234.500 DT');
      expect(UserReportService.money(1234567.891), '1,234,567.891 DT');
    });

    test('recentStats counts only the last 30 days', () {
      UserActivity a(String action, int daysAgo) => UserActivity(
            userId: 3,
            action: action,
            createdAt: now.subtract(Duration(days: daysAgo)),
          );
      final stats = UserReportService.recentStats([
        a(ActivityAction.login, 1),
        a(ActivityAction.loginFailed, 2),
        a(ActivityAction.totpFailed, 3),
        a(ActivityAction.passwordChanged, 4),
        a(ActivityAction.login, 40), // too old
        a(ActivityAction.loginFailed, 45), // too old
      ], now);
      expect(stats.logins, 1);
      expect(stats.failures, 2);
      expect(stats.passwordChanges, 1);
      expect(stats.lastLogin, now.subtract(const Duration(days: 1)));
    });

    test('builds a valid PDF, with or without activity', () async {
      final empty = await UserReportService.build(
          UserReportData(user: user, generatedAt: now, activity: const []));
      expect(String.fromCharCodes(empty.take(5)), '%PDF-');

      final many = [
        for (var i = 0; i < 60; i++)
          UserActivity(
            userId: 3,
            action: ActivityAction.login,
            detail: 'Par Karim',
            createdAt: now.subtract(Duration(hours: i)),
          ),
      ];
      final full = await UserReportService.build(UserReportData(
        user: user,
        generatedAt: now,
        activity: many,
        business: const BusinessStats(rentals: 4, revenue: 430.5),
      ));
      expect(String.fromCharCodes(full.take(5)), '%PDF-');
      expect(full.length, greaterThan(empty.length));
    });
  });
}
