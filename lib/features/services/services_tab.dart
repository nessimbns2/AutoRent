import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/widgets/shared_widgets.dart';
import '../incidents/incidents_tab.dart';
import '../maintenances/maintenances_tab.dart';

enum ServicesSegment { maintenances, incidents }

/// "Suivi" tab — maintenance planning and incident follow-up in one place.
class ServicesTab extends StatefulWidget {
  final ServicesSegment initialSegment;
  const ServicesTab(
      {super.key, this.initialSegment = ServicesSegment.maintenances});

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  late ServicesSegment _segment = widget.initialSegment;
  int _refresh = 0;

  bool get _isMaint => _segment == ServicesSegment.maintenances;

  Future<void> _add() async {
    final saved = await Navigator.pushNamed(
        context, _isMaint ? Routes.maintenanceForm : Routes.incidentForm);
    if (saved == true && mounted) setState(() => _refresh++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: GradientFab(
        heroTag: 'fab-services',
        onPressed: _add,
        backgroundColor: _isMaint ? null : AppColors.danger,
        icon: Icon(_isMaint
            ? Icons.event_repeat_rounded
            : Icons.report_gmailerrorred_rounded),
        label: Text(_isMaint ? 'Planifier' : 'Déclarer'),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const PageHeader(
            title: 'Suivi',
            subtitle: 'Entretiens de la flotte et incidents',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _SegmentSwitch(
              value: _segment,
              onChanged: (s) => setState(() => _segment = s),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _isMaint
                  ? MaintenancesList(
                      key: const ValueKey('maint'), refreshToken: _refresh)
                  : IncidentsList(
                      key: const ValueKey('inc'), refreshToken: _refresh),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SegmentSwitch extends StatelessWidget {
  final ServicesSegment value;
  final ValueChanged<ServicesSegment> onChanged;
  const _SegmentSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget half(ServicesSegment s, String label, IconData icon) {
      final sel = s == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            height: 44,
            decoration: BoxDecoration(
              color: sel ? context.colors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: sel
                  ? [
                      BoxShadow(
                          color: context.palette.cardShadow,
                          blurRadius: 10,
                          offset: const Offset(0, 3))
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 18,
                    color: sel ? AppColors.brand : context.palette.muted),
                const SizedBox(width: 8),
                Text(label,
                    style: context.text.labelLarge?.copyWith(
                        color: sel
                            ? context.colors.onSurface
                            : context.palette.muted)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.palette.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        half(ServicesSegment.maintenances, 'Entretiens', Icons.build_rounded),
        half(ServicesSegment.incidents, 'Incidents',
            Icons.report_gmailerrorred_rounded),
      ]),
    );
  }
}
