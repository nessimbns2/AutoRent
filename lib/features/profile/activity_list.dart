import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/user_activity.dart';

/// Renders a user's activity log (loaded from [future]).
class ActivityList extends StatelessWidget {
  final Future<List<UserActivity>> future;
  const ActivityList({super.key, required this.future});

  static final _fmt = DateFormat('dd/MM/yyyy HH:mm');

  static IconData _icon(String action) => switch (action) {
        ActivityAction.login => Icons.login,
        ActivityAction.logout => Icons.logout,
        ActivityAction.loginFailed ||
        ActivityAction.recoveryFailed ||
        ActivityAction.totpFailed =>
          Icons.warning_amber_rounded,
        ActivityAction.accountLocked => Icons.lock_clock,
        ActivityAction.passwordChanged ||
        ActivityAction.passwordResetRecovery ||
        ActivityAction.passwordResetColleague =>
          Icons.lock_reset,
        ActivityAction.recoveryKeySet => Icons.key,
        ActivityAction.reportExported => Icons.picture_as_pdf,
        ActivityAction.totpEnabled ||
        ActivityAction.totpDisabled =>
          Icons.phonelink_lock,
        ActivityAction.profileUpdated => Icons.edit_outlined,
        ActivityAction.accountCreated => Icons.person_add_alt,
        _ => Icons.history,
      };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserActivity>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
                child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        if (snap.hasError) {
          return const Text("Impossible de charger l'activité.");
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) return const Text('Aucune activité enregistrée.');
        return Column(
          children: [
            for (final a in items)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(_icon(a.action), size: 20),
                title: Text(a.label),
                subtitle: a.detail == null ? null : Text(a.detail!),
                trailing: Text(_fmt.format(a.createdAt),
                    style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
        );
      },
    );
  }
}
