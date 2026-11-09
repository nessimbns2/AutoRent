import 'dart:typed_data';

import 'user.dart';
import 'user_activity.dart';

/// Read-only figures about what an agent did in the business modules
/// (rentals they created, incidents they reported).
class BusinessStats {
  final int rentals;
  final int active;
  final int completed;
  final int cancelled;
  final double revenue; // sum of non-cancelled rentals
  final int incidents;

  const BusinessStats({
    this.rentals = 0,
    this.active = 0,
    this.completed = 0,
    this.cancelled = 0,
    this.revenue = 0,
    this.incidents = 0,
  });
}

/// Everything the PDF report needs. Never contains secrets: no password
/// hash, recovery key, or 2FA secret.
class UserReportData {
  final User user;
  final User? generatedBy;
  final DateTime generatedAt;
  final Uint8List? avatar;

  /// Newest first.
  final List<UserActivity> activity;
  final BusinessStats business;

  const UserReportData({
    required this.user,
    required this.generatedAt,
    required this.activity,
    this.generatedBy,
    this.avatar,
    this.business = const BusinessStats(),
  });

  UserReportData withoutAvatar() => UserReportData(
        user: user,
        generatedBy: generatedBy,
        generatedAt: generatedAt,
        activity: activity,
        business: business,
      );
}
