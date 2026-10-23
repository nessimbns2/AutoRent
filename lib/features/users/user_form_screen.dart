import 'package:flutter/material.dart';

import '../../core/constants/strings.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/ui_helpers.dart';
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

        // If editing current logged-in user, refresh session
        if (updated.id == SessionManager.instance.currentUser?.id) {
          await SessionManager.instance.refresh();
        }

        if (!mounted) return;
        showSnack(context, 'Utilisateur modifié');
      } else {
        final newUser = User(
          lastName: _lastNameController.text.trim(),
          firstName: _firstNameController.text.trim(),
          email: _emailController.text.trim(),
          passwordHash: '', // Set by insert
          createdAt: DateTime.now(),
        );
        await _repo.insert(newUser, _passwordController.text);
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
        title: Text(_isEdit ? 'Modifier utilisateur' : 'Nouvel utilisateur'),
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 750,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: (v) => Validators.required(v, 'Le nom'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'Prénom'),
                  validator: (v) => Validators.required(v, 'Le prénom'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: Validators.email,
                  textInputAction:
                      _isEdit ? TextInputAction.done : TextInputAction.next,
                ),
                if (!_isEdit) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe initial',
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Le mot de passe doit comporter au moins 6 caractères'
                        : null,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text(Strings.save),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
