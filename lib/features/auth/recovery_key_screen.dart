import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/routes.dart';
import '../../core/services/recovery_key.dart';
import '../../core/session/session_manager.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../repositories/user_repository.dart';

/// Generates a recovery key, shows it once, and stores only its hash after
/// the user confirms they saved it. If the app is closed before confirming,
/// nothing is stored and the screen appears again next time.
class RecoveryKeyScreen extends StatefulWidget {
  /// First-time setup (cannot be skipped) vs. regenerating from the profile.
  final bool firstTime;
  const RecoveryKeyScreen({super.key, this.firstTime = false});

  @override
  State<RecoveryKeyScreen> createState() => _RecoveryKeyScreenState();
}

class _RecoveryKeyScreenState extends State<RecoveryKeyScreen> {
  final _repo = UserRepository();
  final String _key = RecoveryKey.generate();
  bool _saved = false;
  bool _busy = false;
  String? _status;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _key));
    if (mounted) setState(() => _status = 'Copié dans le presse-papiers.');
  }

  Future<void> _confirm() async {
    final session = SessionManager.instance;
    setState(() => _busy = true);
    try {
      await _repo.setRecoveryKey(session.currentUser!.id!, _key);
      await session.refresh();
      if (!mounted) return;
      if (widget.firstTime) {
        Navigator.pushReplacementNamed(context, Routes.home);
      } else {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    await SessionManager.instance.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, Routes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !widget.firstTime,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Clé de récupération'),
          automaticallyImplyLeading: !widget.firstTime,
        ),
        body: ResponsiveCenter(
          maxWidth: 520,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.key, size: 56, color: scheme.primary),
                const SizedBox(height: 16),
                Text(
                  widget.firstTime
                      ? 'Sauvegardez votre clé de récupération'
                      : 'Nouvelle clé de récupération',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Si vous oubliez votre mot de passe, cette clé est le seul '
                  'moyen de le réinitialiser vous-même, sans connexion internet. '
                  'Elle ne sera plus jamais affichée.'
                  '${widget.firstTime ? '' : '\nElle remplace votre ancienne clé, qui ne fonctionnera plus.'}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    _key,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _copy,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copier'),
                  ),
                ),
                if (_status != null) ...[
                  const SizedBox(height: 8),
                  Text(_status!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: scheme.primary)),
                ],
                const SizedBox(height: 20),
                CheckboxListTile(
                  value: _saved,
                  onChanged: (v) => setState(() => _saved = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text("J'ai conservé cette clé en lieu sûr"),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _saved && !_busy ? _confirm : null,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Continuer'),
                ),
                if (widget.firstTime)
                  TextButton(
                    onPressed: _logout,
                    child: const Text('Se déconnecter'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
