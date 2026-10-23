# Screen patterns (shared)

## Shared helpers (`core/utils/ui_helpers.dart`, `core/widgets/`)

```dart
void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool?> confirmDialog(BuildContext context,
    {required String title, required String message, String confirmLabel = 'Confirmer'}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmLabel)),
      ],
    ),
  );
}
```

Widgets (all `StatelessWidget`): `LoadingView()`, `ErrorView(error, onRetry)`, `EmptyState(message, {actionLabel, onAction})`, `StatusChip(label, color)`, `SearchField(hint, onChanged)`, `SectionCard(title, children)`, `PhotoStrip(fileNames, onTap(index))` (horizontal `ListView`, tap → `photoViewer`), `LabeledRow(label, value)` for detail screens, `CarImage(fileName?, {fit})` (`Image.file` with `errorBuilder`; `Image.asset('assets/images/car_placeholder.png')` when null). `PhotoPickerField` is a `StatefulWidget`: shows thumbnails with a remove (×) button and an "Ajouter" tile that calls `pickPhotoSource` (bottom sheet) then `ImageStorage.pickAndSave`; props `fileNames`, `maxPhotos`, `onChanged(List<String>)`.

## Validators (`core/utils/validators.dart`)

```dart
class Validators {
  static String? required(String? v, [String field = 'Ce champ']) =>
      (v == null || v.trim().isEmpty) ? '$field est obligatoire' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email obligatoire';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'Email invalide';
  }

  static String? password(String? v) =>
      (v == null || v.length < 6) ? 'Mot de passe invalide (6 caractères minimum)' : null;

  static String? Function(String?) confirm(TextEditingController original) =>
      (v) => v == original.text ? null : 'Les mots de passe ne correspondent pas';

  static String? phone(String? v) {
    final digits = (v ?? '').replaceAll(RegExp(r'[\s+]'), '');
    return RegExp(r'^\d{8,15}$').hasMatch(digits) ? null : 'Numéro de téléphone invalide';
  }

  static String? plate(String? v) =>
      (v == null || v.trim().length < 4) ? 'Immatriculation invalide' : null;

  static String? positiveNumber(String? v, [String field = 'Valeur']) {
    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
    return (n == null || n <= 0) ? '$field doit être supérieure à 0' : null;
  }
}
```

## Formatters (`core/utils/formatters.dart`, uses `intl`)

```dart
final _date = DateFormat('dd/MM/yyyy');
String formatDate(DateTime d) => _date.format(d);
String toIsoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);   // stored in SQLite
DateTime fromIsoDate(String s) => DateTime.parse(s);
String formatMoney(double v) => '${NumberFormat('#,##0.000', 'fr_FR').format(v)} DT';
```
(Call `initializeDateFormatting('fr_FR')` in `main()` if a locale-specific format is used; otherwise stick to the default locale.)

## List pattern (FutureBuilder + reload)

```dart
class _ClientListScreenState extends State<ClientListScreen> {
  final _repo = ClientRepository();
  final _searchController = TextEditingController();
  late Future<List<Client>> _future = _repo.getAll();

  void _reload() => setState(() => _future = _repo.getAll(search: _searchController.text));

  Future<void> _openForm({int? id}) async {
    final saved = await Navigator.pushNamed<bool>(context, Routes.clientForm,
        arguments: id == null ? null : ClientFormArgs(clientId: id));
    if (saved == true && mounted) _reload();
  }

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Locataires')),
      floatingActionButton: FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)),
      body: Column(children: [
        SearchField(hint: 'Rechercher un locataire', onChanged: (t) => _reload()),
        Expanded(
          child: FutureBuilder<List<Client>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const LoadingView();
              if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
              final items = snap.data!;
              if (items.isEmpty) return const EmptyState(message: 'Aucun locataire.');
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) => ClientCard(client: items[i], onTap: () async {
                  final changed = await Navigator.pushNamed<bool>(context, Routes.clientDetail,
                      arguments: IdArgs(items[i].id!));
                  if (changed == true && mounted) _reload();
                }),
              );
            },
          ),
        ),
      ]),
    );
  }
}
```

## Form pattern (create + edit in one screen)

```dart
class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = ClientRepository();
  final _lastName = TextEditingController();
  final _firstName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _license = TextEditingController();
  Client? _existing;
  bool _loading = true, _saving = false;

  bool get _isEdit => widget.clientId != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (_isEdit) {
      _existing = await _repo.getById(widget.clientId!);
      if (_existing != null) {
        _lastName.text = _existing!.lastName; /* … other controllers … */
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final client = Client(id: _existing?.id, lastName: _lastName.text.trim(), /* … */ createdAt: _existing?.createdAt ?? DateTime.now());
      _isEdit ? await _repo.update(client) : await _repo.insert(client);
      if (!mounted) return;
      showSnack(context, _isEdit ? 'Locataire modifié' : 'Locataire ajouté');
      Navigator.pop(context, true);
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() { /* dispose every controller */ super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingView());
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Modifier le locataire' : 'Nouveau locataire')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(children: [
              TextFormField(controller: _lastName, textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: (v) => Validators.required(v, 'Le nom')),
              const SizedBox(height: 12),
              /* … */
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enregistrer'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
```

If the user leaves a dirty form with Back, asking for confirmation is optional (nice touch: `PopScope` + `confirmDialog("Abandonner les modifications ?")`).

## Dropdown and pickers

```dart
DropdownButtonFormField<int>(
  initialValue: _vehicleId,   // Flutter ≥ 3.33; on older SDKs use `value:`
  decoration: const InputDecoration(labelText: 'Véhicule'),
  items: [for (final v in _vehicles) DropdownMenuItem(value: v.id, child: Text(v.label))],
  onChanged: (id) => setState(() => _vehicleId = id),
  validator: (v) => v == null ? 'Choisissez un véhicule' : null,
)

final picked = await showDatePicker(
  context: context,
  initialDate: _date ?? DateTime.now(),
  firstDate: DateTime(2020),
  lastDate: DateTime(2100),
  locale: const Locale('fr'),   // needs flutter_localizations delegates; omit locale otherwise
);

final range = await showDateRangePicker(context: context, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime(2100));
```

Date fields are read-only `TextFormField`s (`readOnly: true`, `onTap: _pickDate`, `validator` checking non-empty) so they integrate with `Form.validate()`.

Check Flutter's current API before using `initialValue` vs `value` on `DropdownButtonFormField`, and run `flutter analyze` — fix deprecations rather than suppressing them.

## Delete pattern

```dart
Future<void> _delete() async {
  final ok = await confirmDialog(context,
      title: 'Supprimer', message: 'Cette action est définitive.', confirmLabel: 'Supprimer');
  if (ok != true || !mounted) return;
  try {
    await _repo.delete(widget.clientId);
    if (!mounted) return;
    showSnack(context, 'Locataire supprimé');
    Navigator.pop(context, true);
  } on AppException catch (e) {
    if (mounted) showSnack(context, e.message);
  }
}
```

## Vehicle card (GridView.builder item)

`Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: …, child: Column(crossAxisAlignment: start, children: [Expanded(child: CarImage(fileName: vehicle.photos.firstOrNull, fit: BoxFit.cover, width: double.infinity)), Padding(…, child: Column(…brand + model (bold), plate, price/day, availability StatusChip))])))`.
