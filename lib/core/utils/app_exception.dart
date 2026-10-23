import 'package:sqflite/sqflite.dart';

/// Application exception thrown by repositories and caught by screens.
/// Message is always in French, ready to show in a SnackBar.
class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => 'AppException: $message';
}

extension AutoRentDatabaseExceptionExt on DatabaseException {
  bool isForeignKeyConstraintError() {
    final msg = toString().toLowerCase();
    return msg.contains('foreign key') || (msg.contains('constraint') && msg.contains('787'));
  }
}
