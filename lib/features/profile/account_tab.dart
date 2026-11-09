import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/services/theme_controller.dart';
import '../../core/database/database_helper.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../repositories/user_repository.dart';

/// "Profil" tab — account card, shortcuts to management screens and settings.
class AccountTab extends StatefulWidget {
  const AccountTab({super.key});

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  final _repo = UserRepository();
  late Future<(int, double, int)> _activity = _load();

  Future<(int, double, int)> _load() {
    final id = SessionManager.instance.currentUser?.id;
    return id == null ? Future.value((0, 0.0, 0)) : _repo.activity(id);
  }

  Future<void> _open(String route) async {
    await Navigator.pushNamed(context, route);
    if (mounted) setState(() { _activity = _load(); });
  }

  /// Bottom sheet listing what is stored in the local SQLite database.
  Future<void> _showDatabaseInfo(BuildContext context) async {
    final counts = await DatabaseHelper.instance.tableCounts();
    final path = await DatabaseHelper.instance.filePath;
    if (!context.mounted) return;
    const labels = {
      'vehicles': ('Véhicules', Icons.directions_car_rounded),
      'rentals': ('Locations', Icons.receipt_long_rounded),
      'clients': ('Locataires', Icons.badge_rounded),
      'users': ('Utilisateurs', Icons.manage_accounts_rounded),
      'maintenances': ('Entretiens', Icons.build_rounded),
      'incidents': ('Incidents', Icons.report_rounded),
      'vehicle_photos': ('Photos véhicules', Icons.photo_library_rounded),
      'incident_photos': ('Photos incidents', Icons.photo_camera_rounded),
    };
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const IconBadge(
                    icon: Icons.storage_rounded, color: AppColors.teal, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Base de données SQLite',
                          style: sheetCtx.text.titleMedium),
                      Text('$total enregistrements · autorent.db',
                          style: sheetCtx.text.bodySmall),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.6,
                children: [
                  for (final e in labels.entries)
                    InfoTile(
                      icon: e.value.$2,
                      label: e.value.$1,
                      value: '${counts[e.key] ?? 0}',
                      color: AppColors.teal,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              InfoBanner(
                icon: Icons.lock_outline_rounded,
                color: AppColors.info,
                text:
                    'Toutes les données restent sur cet appareil, sans serveur ni connexion Internet.\n$path',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(
      context,
      title: 'Déconnexion',
      message: 'Voulez-vous vraiment vous déconnecter ?',
      confirmLabel: 'Se déconnecter',
      icon: Icons.logout_rounded,
    );
    if (ok != true || !mounted) return;
    await SessionManager.instance.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, Routes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionManager.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Profile header ─────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(children: [
                Row(children: [
                  Text('Mon profil',
                      style: context.text.headlineSmall
                          ?.copyWith(color: Colors.white)),
                  const Spacer(),
                  CircleIconButton(
                    icon: Icons.edit_rounded,
                    tooltip: 'Modifier le profil',
                    color: Colors.white,
                    background: Colors.white.withValues(alpha: 0.12),
                    onPressed: () => _open(Routes.profile),
                  ),
                ]),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.brandGradient,
                  ),
                  child: AvatarCircle(
                    initials: user.initials,
                    photoFile: user.photoFile,
                    size: 88,
                    color: AppColors.ink3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(user.fullName,
                    style:
                        context.text.titleLarge?.copyWith(color: Colors.white)),
                Text(user.email,
                    style: context.text.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.65))),
                const SizedBox(height: 10),
                const StatusChip(
                    label: 'Agent de location',
                    color: AppColors.brand,
                    solid: true,
                    icon: Icons.verified_rounded),
                const SizedBox(height: 18),
                FutureBuilder<(int, double, int)>(
                  future: _activity,
                  builder: (context, snap) {
                    final a = snap.data ?? (0, 0.0, 0);
                    return Row(children: [
                      _HeaderStat(value: '${a.$1}', label: 'Locations'),
                      _divider(),
                      _HeaderStat(
                          value: formatMoneyShort(a.$2), label: 'Générés'),
                      _divider(),
                      _HeaderStat(value: '${a.$3}', label: 'Incidents'),
                    ]);
                  },
                ),
              ]),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _group(context, 'Gestion', [
                _MenuTile(
                  icon: Icons.badge_rounded,
                  color: AppColors.info,
                  title: 'Locataires',
                  subtitle: 'Clients, permis et historique',
                  onTap: () => _open(Routes.clients),
                ),
                _MenuTile(
                  icon: Icons.manage_accounts_rounded,
                  color: AppColors.violet,
                  title: 'Utilisateurs',
                  subtitle: "Comptes des agents de l'agence",
                  onTap: () => _open(Routes.users),
                ),
              ]),
              _group(context, 'Données', [
                _MenuTile(
                  icon: Icons.storage_rounded,
                  color: AppColors.teal,
                  title: 'Base de données SQLite',
                  subtitle: 'Stockée sur cet appareil · 100 % hors-ligne',
                  onTap: () => _showDatabaseInfo(context),
                ),
              ]),
              _group(context, 'Préférences', [
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeController.instance.mode,
                  builder: (context, mode, _) => _MenuTile(
                    icon: mode == ThemeMode.dark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: AppColors.warning,
                    title: 'Mode sombre',
                    subtitle: mode == ThemeMode.dark ? 'Activé' : 'Désactivé',
                    trailing: Switch(
                      value: mode == ThemeMode.dark,
                      onChanged: ThemeController.instance.setDark,
                    ),
                    onTap: () => ThemeController.instance
                        .setDark(mode != ThemeMode.dark),
                  ),
                ),
              ]),
              _group(context, 'Compte', [
                _MenuTile(
                  icon: Icons.person_rounded,
                  color: AppColors.brand,
                  title: 'Modifier mon profil',
                  subtitle: 'Nom, email, photo et mot de passe',
                  onTap: () => _open(Routes.profile),
                ),
                _MenuTile(
                  icon: Icons.shield_rounded,
                  color: AppColors.success,
                  title: 'Sécurité du compte',
                  subtitle: 'Clé de récupération, 2FA et activité',
                  onTap: () => _open(Routes.security),
                ),
                _MenuTile(
                  icon: Icons.logout_rounded,
                  color: AppColors.danger,
                  title: 'Se déconnecter',
                  danger: true,
                  onTap: _logout,
                ),
              ]),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'AutoRent 2.0 · 100 % hors-ligne (SQLite)',
                  style: context.text.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 30,
        color: Colors.white.withValues(alpha: 0.15),
      );

  Widget _group(BuildContext context, String title, List<Widget> tiles) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(title.toUpperCase(),
                  style: context.text.labelSmall?.copyWith(
                      color: context.palette.muted, letterSpacing: 1.1)),
            ),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0)
                    Divider(indent: 64, color: context.palette.border),
                  tiles[i],
                ],
              ]),
            ),
          ],
        ),
      );
}

class _HeaderStat extends StatelessWidget {
  final String value;
  final String label;
  const _HeaderStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: context.text.titleMedium?.copyWith(color: Colors.white)),
          ),
          Text(label,
              style: context.text.bodySmall
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.6))),
        ]),
      );
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool danger;
  final VoidCallback onTap;
  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            IconBadge(icon: icon, color: color, size: 38, iconSize: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: context.text.titleSmall?.copyWith(
                          color: danger ? AppColors.danger : null)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: context.text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            trailing ??
                (danger
                    ? const SizedBox.shrink()
                    : Icon(Icons.chevron_right_rounded,
                        color: context.palette.muted)),
          ]),
        ),
      );
}
