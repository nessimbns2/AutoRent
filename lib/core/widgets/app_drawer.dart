import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/ui_helpers.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = SessionManager.instance.currentUser;
    if (user == null) return const Drawer();

    void open(String route) {
      Navigator.pop(context); // close drawer first
      Navigator.pushNamed(context, route);
    }

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          InkWell(
            onTap: () => open(Routes.profile),
            child: UserAccountsDrawerHeader(
              accountName: Text(user.fullName),
              accountEmail: Text(user.email),
              currentAccountPicture: CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                child: Text(
                  user.initials,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Mon profil'),
            onTap: () => open(Routes.profile),
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Locataires'),
            onTap: () => open(Routes.clients),
          ),
          ListTile(
            leading: const Icon(Icons.group_outlined),
            title: const Text('Utilisateurs'),
            onTap: () => open(Routes.users),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Déconnexion'),
            onTap: () async {
              Navigator.pop(context);
              final ok = await confirmDialog(
                context,
                title: 'Déconnexion',
                message: 'Voulez-vous vraiment vous déconnecter ?',
              );
              if (ok != true || !context.mounted) return;
              await SessionManager.instance.logout();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                Routes.login,
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
