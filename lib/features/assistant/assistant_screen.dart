import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/services/groq_service.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/shared_widgets.dart';
import 'assistant_context.dart';

/// "Assistant AutoRent": a chat with Groq that knows the agency's fleet,
/// prices, pricing grid and activity.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _groq = GroqService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _sending = false;
  bool _hasKey = true;
  String? _error;

  static const _suggestions = [
    'Quelles voitures sont disponibles ?',
    'Combien coûte une Audi Q3 pendant 10 jours ?',
    'Résume l\'activité de l\'agence',
    'Rédige un SMS de rappel de retour pour un client',
  ];

  @override
  void initState() {
    super.initState();
    _checkKey();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _checkKey() async {
    final has = await GroqService.hasApiKey();
    if (mounted) setState(() => _hasKey = has);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    if (!_hasKey) {
      await _openSettings();
      if (!_hasKey) return;
    }
    setState(() {
      _messages.add(ChatMessage('user', text));
      _input.clear();
      _sending = true;
      _error = null;
    });
    _scrollToEnd();
    try {
      final system = await AssistantContext.build();
      final answer = await _groq.reply(
        systemPrompt: system,
        history: _messages,
      );
      if (!mounted) return;
      setState(() => _messages.add(ChatMessage('assistant', answer)));
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  Future<void> _openSettings() async {
    final keyCtrl = TextEditingController();
    final modelCtrl = TextEditingController(text: await GroqService.model());
    final hadKey = await GroqService.hasApiKey();
    if (!mounted) return;
    var obscure = true;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Réglages de l\'assistant', style: ctx.text.titleLarge),
              const SizedBox(height: 6),
              Text(
                'La clé API Groq est enregistrée uniquement sur cet appareil. '
                'Créez-la sur console.groq.com/keys.',
                style: ctx.text.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: keyCtrl,
                obscureText: obscure,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: hadKey
                      ? 'Nouvelle clé (laisser vide pour garder l\'actuelle)'
                      : 'Clé API Groq',
                  hintText: 'gsk_…',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                    onPressed: () => setSheet(() => obscure = !obscure),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelCtrl,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Modèle',
                  helperText: 'Par défaut : ${GroqService.defaultModel}',
                  prefixIcon: Icon(Icons.memory_rounded),
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Enregistrer',
                icon: Icons.check_rounded,
                onPressed: () async {
                  if (keyCtrl.text.trim().isNotEmpty) {
                    await GroqService.saveApiKey(keyCtrl.text);
                  }
                  await GroqService.saveModel(modelCtrl.text);
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx, true);
                },
              ),
              if (hadKey) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () async {
                    await GroqService.saveApiKey(null);
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx, true);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Supprimer la clé de cet appareil'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    keyCtrl.dispose();
    modelCtrl.dispose();
    if (saved == true) {
      await _checkKey();
      if (mounted) {
        showSnack(context, 'Réglages enregistrés', kind: SnackKind.success);
      }
    }
  }

  Future<void> _clear() async {
    if (_messages.isEmpty) return;
    final ok = await confirmDialog(
      context,
      title: 'Nouvelle conversation',
      message: 'Effacer la conversation actuelle ?',
      confirmLabel: 'Effacer',
      destructive: false,
      icon: Icons.refresh_rounded,
    );
    if (ok == true) {
      setState(() {
        _messages.clear();
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: context.brandGlow,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assistant AutoRent', style: context.text.titleMedium),
                Text(
                  _sending ? 'Groq écrit…' : 'Propulsé par Groq',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Nouvelle conversation',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _messages.isEmpty ? null : _clear,
          ),
          IconButton(
            tooltip: 'Réglages (clé API)',
            icon: const Icon(Icons.settings_rounded),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _Welcome(
                    hasKey: _hasKey,
                    suggestions: _suggestions,
                    onSuggestion: _send,
                    onSetup: _openSettings,
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _messages.length + (_sending ? 1 : 0),
                    itemBuilder: (context, i) => i == _messages.length
                        ? const _TypingBubble()
                        : _Bubble(message: _messages[i]),
                  ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: InfoBanner(
                icon: Icons.error_outline_rounded,
                color: AppColors.danger,
                text: _error!,
              ),
            ),
          _Composer(
            controller: _input,
            sending: _sending,
            onSend: () => _send(),
          ),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  final bool hasKey;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;
  final VoidCallback onSetup;
  const _Welcome({
    required this.hasKey,
    required this.suggestions,
    required this.onSuggestion,
    required this.onSetup,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
    children: [
      Center(
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(26),
            boxShadow: context.brandGlow,
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
      const SizedBox(height: 18),
      Text(
        'Comment puis-je vous aider ?',
        textAlign: TextAlign.center,
        style: context.text.headlineSmall,
      ),
      const SizedBox(height: 6),
      Text(
        'Je connais votre flotte, vos tarifs, la grille tarifaire et l\'activité de l\'agence.',
        textAlign: TextAlign.center,
        style: context.text.bodyMedium?.copyWith(color: context.palette.muted),
      ),
      const SizedBox(height: 22),
      if (!hasKey) ...[
        InfoBanner(
          icon: Icons.key_rounded,
          color: AppColors.warning,
          text: 'Ajoutez votre clé API Groq pour commencer.',
          action: TextButton(onPressed: onSetup, child: const Text('Ajouter')),
        ),
        const SizedBox(height: 16),
      ],
      for (final s in suggestions)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => onSuggestion(s),
            child: Row(
              children: [
                const IconBadge(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: AppColors.brand,
                  size: 34,
                  iconSize: 17,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(s, style: context.text.bodyMedium)),
                Icon(
                  Icons.north_east_rounded,
                  size: 18,
                  color: context.palette.muted,
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final user = message.isUser;
    final maxW = MediaQuery.sizeOf(context).width * 0.8;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxW > 560 ? 560 : maxW),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: user ? AppColors.brandGradient : null,
          color: user ? null : context.colors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(user ? 20 : 6),
            bottomRight: Radius.circular(user ? 6 : 20),
          ),
          border: user || !context.isDark
              ? null
              : Border.all(color: context.hairline),
          boxShadow: user ? context.brandGlow : context.softShadow,
        ),
        child: SelectableText(
          message.content,
          style: context.text.bodyMedium?.copyWith(
            color: user ? Colors.white : null,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: context.softShadow,
      ),
      child: const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2.2),
      ),
    ),
  );
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) => BottomActionBar(
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            decoration: const InputDecoration(
              hintText: 'Posez votre question…',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            shape: BoxShape.circle,
            boxShadow: context.brandGlow,
          ),
          child: IconButton(
            tooltip: 'Envoyer',
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}
