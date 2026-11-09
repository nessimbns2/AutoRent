import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/client.dart';
import '../../repositories/client_repository.dart';

class ClientFormScreen extends StatefulWidget {
  final int? clientId;
  const ClientFormScreen({super.key, this.clientId});

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = ClientRepository();

  final _lastNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _licenseController = TextEditingController();

  Client? _existing;
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.clientId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isEdit) {
      _existing = await _repo.getById(widget.clientId!);
      if (_existing != null) {
        _lastNameController.text = _existing!.lastName;
        _firstNameController.text = _existing!.firstName;
        _phoneController.text = _existing!.phone;
        _emailController.text = _existing!.email ?? '';
        _licenseController.text = _existing!.licenseNumber;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final emailText = _emailController.text.trim();
      final client = Client(
        id: _existing?.id,
        lastName: _lastNameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: emailText.isEmpty ? null : emailText,
        licenseNumber: _licenseController.text.trim(),
        createdAt: _existing?.createdAt ?? DateTime.now(),
      );
      if (_isEdit) {
        await _repo.update(client);
        if (!mounted) return;
        showSnack(context, 'Locataire modifié');
      } else {
        await _repo.insert(client);
        if (!mounted) return;
        showSnack(context, 'Locataire ajouté');
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
        title: Text(_isEdit ? 'Modifier le locataire' : 'Nouveau locataire'),
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
              title: 'Contact',
              icon: Icons.contact_phone_rounded,
              color: AppColors.info,
              children: [
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      prefixIcon: Icon(Icons.phone_rounded),
                      prefixText: '+216 '),
                  validator: Validators.phone,
                  textInputAction: TextInputAction.next,
                ),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email (facultatif)',
                      prefixIcon: Icon(Icons.alternate_email_rounded)),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? null
                      : Validators.email(v),
                  textInputAction: TextInputAction.next,
                ),
              ],
            ),
            FormSection(
              title: 'Permis de conduire',
              icon: Icons.credit_card_rounded,
              color: AppColors.violet,
              children: [
                TextFormField(
                  controller: _licenseController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                      labelText: 'Numéro de permis',
                      prefixIcon: Icon(Icons.numbers_rounded)),
                  validator: (v) =>
                      Validators.required(v, 'Le numéro de permis'),
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: PrimaryButton(
          label: _isEdit ? 'Enregistrer' : 'Ajouter le locataire',
          icon: Icons.check_rounded,
          loading: _saving,
          onPressed: _save,
        ),
      ),
    );
  }
}
