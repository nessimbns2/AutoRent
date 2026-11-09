import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/services/image_storage.dart';
import '../../core/services/password_hasher.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/password_policy.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/password_strength_meter.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/user.dart';
import '../../repositories/user_repository.dart';

/// Edit my profile (name, email, photo, password).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userRepo = UserRepository();

  final _lastNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _photoFile;
  bool _saving = false;
  bool _obscure = true;

  User get _currentUser => SessionManager.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    final u = _currentUser;
    _lastNameController.text = u.lastName;
    _firstNameController.text = u.firstName;
    _emailController.text = u.email;
    _photoFile = u.photoFile;
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await pickImageSource(
      context,
      onRemove: _photoFile == null
          ? null
          : () => setState(() => _photoFile = null),
    );
    if (source == null || !mounted) return;
    try {
      final file = await ImageStorage.pickAndSave(source);
      if (file != null && mounted) setState(() => _photoFile = file);
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, kind: SnackKind.error);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final currentPass = _currentPasswordController.text;
    final newPass = _newPasswordController.text;

    if (currentPass.isNotEmpty || newPass.isNotEmpty) {
      if (currentPass.isEmpty) {
        showSnack(context, 'Veuillez saisir votre mot de passe actuel.');
        return;
      }
      if (!PasswordHasher.verify(currentPass, _currentUser.passwordHash)) {
        showSnack(context, 'Mot de passe actuel incorrect.');
        return;
      }
      final policyError = PasswordPolicy.validate(newPass);
      if (policyError != null) {
        showSnack(context, 'Nouveau mot de passe : $policyError.');
        return;
      }
      if (newPass != _confirmPasswordController.text) {
        showSnack(context, 'Veuillez saisir deux mots de passe identiques.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final updatedUser = _currentUser.copyWith(
        lastName: _lastNameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        email: _emailController.text.trim(),
        photoFile: _photoFile,
        clearPhoto: _photoFile == null,
      );
      await _userRepo.update(updatedUser);
      if (newPass.isNotEmpty) {
        await _userRepo.changePassword(updatedUser.id!, newPass);
      }
      await SessionManager.instance.refresh();
      if (!mounted) return;
      showSnack(context, 'Profil mis à jour');
      Navigator.pop(context, true);
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier mon profil')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.brandGradient,
                    ),
                    child: AvatarCircle(
                      initials: user.initials,
                      photoFile: _photoFile,
                      size: 104,
                      color: AppColors.ink3,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: context.colors.surface, width: 3),
                      ),
                      child: const Icon(Icons.photo_camera_rounded,
                          size: 18, color: Colors.white),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _pickPhoto,
                child: const Text('Changer la photo'),
              ),
            ),
            const SizedBox(height: 8),
            FormSection(
              title: 'Informations personnelles',
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
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.alternate_email_rounded)),
                  validator: Validators.email,
                  textInputAction: TextInputAction.next,
                ),
              ],
            ),
            FormSection(
              title: 'Sécurité (facultatif)',
              icon: Icons.lock_rounded,
              color: AppColors.violet,
              children: [
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe actuel',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    prefixIcon: Icon(Icons.key_rounded),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                PasswordStrengthMeter(controller: _newPasswordController),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer le nouveau mot de passe',
                    prefixIcon: Icon(Icons.key_rounded),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: PrimaryButton(
          label: 'Enregistrer',
          icon: Icons.check_rounded,
          loading: _saving,
          onPressed: _save,
        ),
      ),
    );
  }
}
