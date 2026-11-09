import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/services/pricing_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/price_breakdown.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/pricing_settings.dart';
import '../../models/vehicle.dart';
import '../../repositories/pricing_repository.dart';
import '../../repositories/vehicle_repository.dart';

/// "Grille tarifaire": long-stay discounts, high season and weekend rate,
/// with a live simulator. Applies to every new rental.
class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = PricingRepository();

  PricingSettings _saved = PricingSettings.defaults;
  bool _loading = true;
  bool _saving = false;

  bool _longStay = true;
  bool _season = true;
  bool _weekend = true;
  int _seasonStartMonth = 7, _seasonStartDay = 1;
  int _seasonEndMonth = 8, _seasonEndDay = 31;

  final _tier1Days = TextEditingController();
  final _tier1Pct = TextEditingController();
  final _tier2Days = TextEditingController();
  final _tier2Pct = TextEditingController();
  final _seasonPct = TextEditingController();
  final _weekendPct = TextEditingController();

  // Simulator
  List<Vehicle> _vehicles = [];
  int? _simVehicleId;
  late DateTime _simStart = _nextFriday();
  int _simDays = 7;
  static const _simDurations = [2, 5, 7, 14, 30];

  static DateTime _nextFriday() {
    final today = DateUtils.dateOnly(DateTime.now());
    final delta = (DateTime.friday - today.weekday) % 7;
    return today.add(Duration(days: delta == 0 ? 7 : delta));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _tier1Days, _tier1Pct, _tier2Days, _tier2Pct, _seasonPct, _weekendPct,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await _repo.get();
    final vehicles = await VehicleRepository().getAll(includeArchived: false);
    if (!mounted) return;
    setState(() {
      _saved = settings;
      _vehicles = vehicles;
      _simVehicleId = vehicles.isEmpty ? null : vehicles.first.id;
      _fill(settings);
      _loading = false;
    });
  }

  static String _num(double v) => PricingService.percent(v);

  void _fill(PricingSettings s) {
    _longStay = s.longStayEnabled;
    _season = s.seasonEnabled;
    _weekend = s.weekendEnabled;
    _seasonStartMonth = s.seasonStartMonth;
    _seasonStartDay = s.seasonStartDay;
    _seasonEndMonth = s.seasonEndMonth;
    _seasonEndDay = s.seasonEndDay;
    _tier1Days.text = '${s.tier1Days}';
    _tier1Pct.text = _num(s.tier1Percent);
    _tier2Days.text = '${s.tier2Days}';
    _tier2Pct.text = _num(s.tier2Percent);
    _seasonPct.text = _num(s.seasonPercent);
    _weekendPct.text = _num(s.weekendPercent);
  }

  static double? _parsePct(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.').replaceAll('−', '-'));

  /// Grid currently typed in the form (invalid fields keep the saved value).
  PricingSettings get _draft => _saved.copyWith(
        longStayEnabled: _longStay,
        tier1Days: int.tryParse(_tier1Days.text.trim()),
        tier1Percent: _parsePct(_tier1Pct.text),
        tier2Days: int.tryParse(_tier2Days.text.trim()),
        tier2Percent: _parsePct(_tier2Pct.text),
        seasonEnabled: _season,
        seasonStartMonth: _seasonStartMonth,
        seasonStartDay: _seasonStartDay,
        seasonEndMonth: _seasonEndMonth,
        seasonEndDay: _seasonEndDay,
        seasonPercent: _parsePct(_seasonPct.text),
        weekendEnabled: _weekend,
        weekendPercent: _parsePct(_weekendPct.text),
      );

  Vehicle? get _simVehicle =>
      _vehicles.where((v) => v.id == _simVehicleId).firstOrNull;

  // ── Validation ─────────────────────────────────────────────────────────────

  String? _validateDays(String? v, {int? greaterThan}) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null || n < 2 || n > 365) return 'Entre 2 et 365 jours';
    if (greaterThan != null && n <= greaterThan) {
      return 'Doit dépasser $greaterThan jours';
    }
    return null;
  }

  String? _validatePct(String? v, double min, double max) {
    final n = _parsePct(v ?? '');
    if (n == null || n < min || n > max) {
      return 'Entre ${_num(min)} et ${_num(max)} %';
    }
    return null;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _pickSeasonBound({required bool start}) async {
    var month = start ? _seasonStartMonth : _seasonEndMonth;
    var day = start ? _seasonStartDay : _seasonEndDay;
    final picked = await showDialog<(int, int)>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          // 29 February is allowed: it simply never matches in other years.
          final maxDay = DateUtils.getDaysInMonth(2024, month);
          if (day > maxDay) day = maxDay;
          return AlertDialog(
            title: Text(start ? 'Début de la haute saison' : 'Fin de la haute saison'),
            content: Row(children: [
              SizedBox(
                width: 84,
                child: DropdownButtonFormField<int>(
                  initialValue: day,
                  decoration: const InputDecoration(labelText: 'Jour'),
                  items: [
                    for (var d = 1; d <= maxDay; d++)
                      DropdownMenuItem(value: d, child: Text('$d')),
                  ],
                  onChanged: (v) => setDialog(() => day = v ?? day),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: month,
                  decoration: const InputDecoration(labelText: 'Mois'),
                  items: [
                    for (var m = 1; m <= 12; m++)
                      DropdownMenuItem(value: m, child: Text(monthLongLabel(m))),
                  ],
                  onChanged: (v) => setDialog(() => month = v ?? month),
                ),
              ),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Annuler')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialogCtx, (month, day)),
                  child: const Text('Valider')),
            ],
          );
        },
      ),
    );
    if (picked == null) return;
    final (m, d) = picked;
    setState(() {
      if (start) {
        _seasonStartMonth = m;
        _seasonStartDay = d;
      } else {
        _seasonEndMonth = m;
        _seasonEndDay = d;
      }
    });
  }

  void _setSeason(int sm, int sd, int em, int ed) => setState(() {
        _season = true;
        _seasonStartMonth = sm;
        _seasonStartDay = sd;
        _seasonEndMonth = em;
        _seasonEndDay = ed;
      });

  Future<void> _pickSimStart() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _simStart,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 730)),
      helpText: 'Date de départ',
    );
    if (picked != null) setState(() => _simStart = picked);
  }

  Future<void> _resetDefaults() async {
    final ok = await confirmDialog(
      context,
      title: 'Valeurs par défaut',
      message:
          '−10 % dès 7 jours, −25 % dès 30 jours, haute saison +20 % du 1er juillet '
          'au 31 août et week-end +10 %. Rien n\'est enregistré avant « Enregistrer ».',
      confirmLabel: 'Rétablir',
      destructive: false,
      icon: Icons.restart_alt_rounded,
    );
    if (ok == true) setState(() => _fill(PricingSettings.defaults));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      showSnack(context, 'Corrigez les valeurs en rouge', kind: SnackKind.error);
      return;
    }
    setState(() => _saving = true);
    try {
      await _repo.save(_draft);
      if (!mounted) return;
      showSnack(context, 'Grille tarifaire enregistrée',
          kind: SnackKind.success);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'Enregistrement impossible : $e',
          kind: SnackKind.error);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingView());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grille tarifaire'),
        actions: [
          IconButton(
            tooltip: 'Valeurs par défaut',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: _resetDefaults,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InfoBanner(
                icon: Icons.info_outline_rounded,
                text:
                    'Le prix des nouvelles locations est calculé avec ces règles. '
                    'Les contrats déjà créés gardent leur montant.'
                    '${_saved.updatedAt == null ? '' : '\nModifiée ${timeAgo(_saved.updatedAt!)}.'}',
              ),
            ),

            // ── Long stay ────────────────────────────────────────────────
            FormSection(
              title: 'Remises longue durée',
              icon: Icons.savings_rounded,
              color: AppColors.success,
              children: [
                _RuleSwitch(
                  value: _longStay,
                  title: 'Remise selon la durée',
                  subtitle: 'Seul le palier le plus élevé atteint s\'applique.',
                  onChanged: (v) => setState(() => _longStay = v),
                ),
                _TierRow(
                  enabled: _longStay,
                  days: _tier1Days,
                  percent: _tier1Pct,
                  daysValidator: (v) => _longStay ? _validateDays(v) : null,
                  percentValidator: (v) =>
                      _longStay ? _validatePct(v, 0, 90) : null,
                  onChanged: () => setState(() {}),
                ),
                _TierRow(
                  enabled: _longStay,
                  days: _tier2Days,
                  percent: _tier2Pct,
                  daysValidator: (v) => _longStay
                      ? _validateDays(v,
                          greaterThan: int.tryParse(_tier1Days.text.trim()))
                      : null,
                  percentValidator: (v) =>
                      _longStay ? _validatePct(v, 0, 90) : null,
                  onChanged: () => setState(() {}),
                ),
              ],
            ),

            // ── High season ──────────────────────────────────────────────
            FormSection(
              title: 'Haute saison',
              icon: Icons.wb_sunny_rounded,
              color: AppColors.warning,
              children: [
                _RuleSwitch(
                  value: _season,
                  title: 'Majoration haute saison',
                  subtitle: 'Appliquée à chaque jour loué dans la période.',
                  onChanged: (v) => setState(() => _season = v),
                ),
                Row(children: [
                  Expanded(
                    child: _BoundButton(
                      label: 'Du',
                      value: formatMonthDay(_seasonStartMonth, _seasonStartDay),
                      enabled: _season,
                      onTap: () => _pickSeasonBound(start: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BoundButton(
                      label: 'Au',
                      value: formatMonthDay(_seasonEndMonth, _seasonEndDay),
                      enabled: _season,
                      onTap: () => _pickSeasonBound(start: false),
                    ),
                  ),
                ]),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  ActionChip(
                    label: const Text('Juillet – août'),
                    visualDensity: VisualDensity.compact,
                    onPressed: _season ? () => _setSeason(7, 1, 8, 31) : null,
                  ),
                  ActionChip(
                    label: const Text('15 juin – 15 sept.'),
                    visualDensity: VisualDensity.compact,
                    onPressed: _season ? () => _setSeason(6, 15, 9, 15) : null,
                  ),
                ]),
                TextFormField(
                  controller: _seasonPct,
                  enabled: _season,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Majoration',
                    prefixText: '+ ',
                    suffixText: '%',
                    prefixIcon: Icon(Icons.trending_up_rounded),
                  ),
                  validator: (v) => _season ? _validatePct(v, 0, 100) : null,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),

            // ── Weekend ──────────────────────────────────────────────────
            FormSection(
              title: 'Tarif week-end',
              icon: Icons.weekend_rounded,
              color: AppColors.violet,
              children: [
                _RuleSwitch(
                  value: _weekend,
                  title: 'Tarif spécial samedi et dimanche',
                  subtitle: 'Valeur négative = remise le week-end.',
                  onChanged: (v) => setState(() => _weekend = v),
                ),
                TextFormField(
                  controller: _weekendPct,
                  enabled: _weekend,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: const InputDecoration(
                    labelText: 'Variation par jour de week-end',
                    suffixText: '%',
                    prefixIcon: Icon(Icons.percent_rounded),
                  ),
                  validator: (v) =>
                      _weekend ? _validatePct(v, -50, 100) : null,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),

            // ── Simulator ────────────────────────────────────────────────
            _buildSimulator(context),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: PrimaryButton(
          label: 'Enregistrer la grille',
          icon: Icons.check_rounded,
          loading: _saving,
          onPressed: _save,
        ),
      ),
    );
  }

  Widget _buildSimulator(BuildContext context) {
    final vehicle = _simVehicle;
    final rate = vehicle?.pricePerDay ?? 100;
    final end = _simStart.add(Duration(days: _simDays));
    final quote = PricingService.quote(
        dailyRate: rate, start: _simStart, end: end, settings: _draft);

    return FormSection(
      title: 'Simulateur',
      icon: Icons.calculate_rounded,
      color: AppColors.info,
      children: [
        if (_vehicles.isNotEmpty)
          DropdownButtonFormField<int>(
            initialValue: _simVehicleId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Véhicule',
              prefixIcon: Icon(Icons.directions_car_outlined),
            ),
            items: [
              for (final v in _vehicles)
                DropdownMenuItem(
                  value: v.id,
                  child: Text(
                    '${v.brand} ${v.model} · ${v.pricePerDay.toStringAsFixed(0)} DT/j',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) => setState(() => _simVehicleId = id),
          ),
        _BoundButton(
          label: 'Départ',
          value: formatLongDay(_simStart),
          enabled: true,
          icon: Icons.event_rounded,
          onTap: _pickSimStart,
        ),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final d in _simDurations)
            ChoiceChip(
              label: Text('$d jours'),
              selected: _simDays == d,
              showCheckmark: false,
              selectedColor: AppColors.info.withValues(alpha: 0.15),
              labelStyle: context.text.labelMedium?.copyWith(
                  color: _simDays == d ? AppColors.info : null),
              onSelected: (_) => setState(() => _simDays = d),
            ),
        ]),
        Text(
          'Retour le ${formatLongDay(end)}',
          style: context.text.bodySmall,
        ),
        PriceBreakdown(quote: quote),
      ],
    );
  }
}

/// Switch inside a tinted rounded box (ListTile needs a Material ancestor).
class _RuleSwitch extends StatelessWidget {
  final bool value;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;
  const _RuleSwitch({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: context.palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          title: Text(title, style: context.text.titleSmall),
          subtitle: Text(subtitle, style: context.text.bodySmall),
        ),
      );
}

/// "Dès [7] jours  →  − [10] %" row of a long-stay tier.
class _TierRow extends StatelessWidget {
  final bool enabled;
  final TextEditingController days;
  final TextEditingController percent;
  final FormFieldValidator<String> daysValidator;
  final FormFieldValidator<String> percentValidator;
  final VoidCallback onChanged;
  const _TierRow({
    required this.enabled,
    required this.days,
    required this.percent,
    required this.daysValidator,
    required this.percentValidator,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: days,
              enabled: enabled,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Dès',
                suffixText: 'jours',
                prefixIcon: Icon(Icons.date_range_rounded),
              ),
              validator: daysValidator,
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: percent,
              enabled: enabled,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Remise',
                prefixText: '− ',
                suffixText: '%',
                prefixIcon: Icon(Icons.sell_outlined),
              ),
              validator: percentValidator,
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      );
}

/// Tappable box showing a date bound ("Du 1 juillet").
class _BoundButton extends StatelessWidget {
  final String label;
  final String value;
  final bool enabled;
  final IconData icon;
  final VoidCallback onTap;
  const _BoundButton({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
    this.icon = Icons.calendar_month_rounded,
  });

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: context.palette.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(icon, size: 20, color: context.palette.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: context.text.bodySmall),
                      Text(value,
                          style: context.text.titleSmall,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}
