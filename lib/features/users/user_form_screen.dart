import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/utils/password_policy.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/user.dart';
import '../../repositories/user_repository.dart';

class UserFormScreen extends StatefulWidget {
  final int? userId;
  const UserFormScreen({super.key, this.userId});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = UserRepository();

  final _lastNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  User? _existingUser;
  bool _loading = true;
  bool _saving = false;
  bool _obscurePassword = true;

  bool get _isEdit => widget.userId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isEdit) {
      _existingUser = await _repo.getById(widget.userId!);
      if (_existingUser != null) {
        _lastNameController.text = _existingUser!.lastName;
        _firstNameController.text = _existingUser!.firstName;
        _emailController.text = _existingUser!.email;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        final updated = _existingUser!.copyWith(
          lastName: _lastNameController.text.trim(),
          firstName: _firstNameController.text.trim(),
          email: _emailController.text.trim(),
        );
        await _repo.update(updated);
        if (updated.id == SessionManager.instance.currentUser?.id) {
          await SessionManager.instance.refresh();
        }
        if (!mounted) return;
        showSnack(context, 'Utilisateur modifié');
      } else {
        await _repo.insert(
          User(
            lastName: _lastNameController.text.trim(),
            firstName: _firstNameController.text.trim(),
            email: _emailController.text.trim(),
            passwordHash: '', // set by the repository
            createdAt: DateTime.now(),
          ),
          _passwordController.text,
        );
        if (!mounted) return;
        showSnack(context, 'Utilisateur créé');
      }
      Navigator.pop(context, true);
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingView());

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? "Modifier l'utilisateur" : 'Nouvel agent'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            FormSection(
              title: 'Identité',
              icon: Icons.person_rounded,
              children: [
                TextFormField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Prénom',
                      prefixIcon: Icon(Icons.person_outline_rounded)),
                  validator: (v) => Validators.required(v, 'Le prénom'),
                  textInputAction: TextInputAction.next,
                ),
                TextFormField(
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Nom',
                      prefixIcon: Icon(Icons.badge_outlined)),
                  validator: (v) => Validators.required(v, 'Le nom'),
                  textInputAction: TextInputAction.next,
                ),
              ],
            ),
            FormSection(
              title: 'Connexion',
              icon: Icons.lock_rounded,
              color: AppColors.violet,
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.alternate_email_rounded)),
                  validator: Validators.email,
                  textInputAction:
                      _isEdit ? TextInputAction.done : TextInputAction.next,
                ),
                if (!_isEdit)
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe initial',
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: PasswordPolicy.validate,
                  ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: PrimaryButton(
          label: _isEdit ? 'Enregistrer' : 'Créer le compte',
          icon: Icons.check_rounded,
          loading: _saving,
          onPressed: _save,
        ),
      ),
    );
  }
}
