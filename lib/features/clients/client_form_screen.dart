import 'package:flutter/material.dart';

import '../../core/constants/strings.dart';
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
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                  validator: Validators.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (facultatif)',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return Validators.email(v);
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _licenseController,
                  decoration:
                      const InputDecoration(labelText: 'Numéro de permis'),
                  validator: (v) =>
                      Validators.required(v, 'Le numéro de permis'),
                  textInputAction: TextInputAction.done,
                ),
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
