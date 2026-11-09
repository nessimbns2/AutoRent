import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/widgets/status_chips.dart';
import '../../../models/enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Visual identity of the incidents module, built on the app design system
// (AppColors, AppCard, IconBadge…) so it matches the other tabs in light and
// dark mode. Type / status colours come from status_chips.dart, the same ones
// the dashboard and vehicle screens use for incidents.
// ─────────────────────────────────────────────────────────────────────────────

extension IncidentTypeStyle on IncidentType {
  Color get color => incidentTypeColor(this);

  IconData get icon => incidentTypeIcon(this);

  String get hint => switch (this) {
    IncidentType.accident => 'Collision, choc, accrochage',
    IncidentType.panne => 'Moteur, batterie, pneu, électrique',
  };

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color.lerp(color, Colors.white, 0.18)!, color],
  );
}

extension IncidentStatusStyle on IncidentStatus {
  Color get color => incidentStatusColor(this);

  IconData get icon => switch (this) {
    IncidentStatus.enAttente => Icons.schedule_rounded,
    IncidentStatus.enCours => Icons.handyman_rounded,
    IncidentStatus.resolu => Icons.check_circle_rounded,
  };

  /// Plural label used on the list's status selector.
  String get pluralLabel => switch (this) {
    IncidentStatus.enAttente => 'En attente',
    IncidentStatus.enCours => 'En cours',
    IncidentStatus.resolu => 'Résolus',
  };

  IncidentStatus? get next => switch (this) {
    IncidentStatus.enAttente => IncidentStatus.enCours,
    IncidentStatus.enCours => IncidentStatus.resolu,
    IncidentStatus.resolu => null,
  };
}

/// Hero tag shared by the list card badge and the detail header badge.
String incidentHeroTag(int id) => 'incident-badge-$id';

// ─────────────────────────────────────────────────────────────────────────────
// TypeBadge — tinted rounded square with the type icon (IconBadge style).
// [filled] gives the solid version used in the detail hero.
// ─────────────────────────────────────────────────────────────────────────────
class IncidentTypeBadge extends StatelessWidget {
  final IncidentType type;
  final double size;
  final bool filled;
  const IncidentTypeBadge({
    super.key,
    required this.type,
    this.size = 48,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: filled ? type.gradient : null,
      color: filled ? null : type.color.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(size * 0.32),
      boxShadow: filled
          ? [
              BoxShadow(
                color: type.color.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ]
          : null,
    ),
    alignment: Alignment.center,
    child: Icon(
      type.icon,
      color: filled ? Colors.white : type.color,
      size: size * 0.5,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// StatusPill — the app's StatusChip with the status icon
// ─────────────────────────────────────────────────────────────────────────────
class IncidentStatusPill extends StatelessWidget {
  final IncidentStatus status;
  final bool solid;
  const IncidentStatusPill({
    super.key,
    required this.status,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 250),
    child: StatusChip(
      key: ValueKey(status),
      label: status.label,
      color: status.color,
      icon: status.icon,
      solid: solid,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EntranceAnimation — fade + slide up, optionally delayed (for staggering)
// ─────────────────────────────────────────────────────────────────────────────
class EntranceAnimation extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  const EntranceAnimation({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 450),
    this.offsetY = 24,
  });

  /// Delay for the [index]-th item of a list: short steps, capped so long
  /// lists don't take forever to appear.
  static Duration staggerDelay(int index) =>
      Duration(milliseconds: 60 * index.clamp(0, 8));

  @override
  State<EntranceAnimation> createState() => _EntranceAnimationState();
}

class _EntranceAnimationState extends State<EntranceAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curve,
    builder: (context, child) => Opacity(
      opacity: _curve.value,
      child: Transform.translate(
        offset: Offset(0, widget.offsetY * (1 - _curve.value)),
        child: child,
      ),
    ),
    child: widget.child,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// AnimatedCount — number that counts up/down to its new value
// ─────────────────────────────────────────────────────────────────────────────
class AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle? style;
  const AnimatedCount({super.key, required this.value, this.style});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value.toDouble()),
    duration: const Duration(milliseconds: 700),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) => Text('${v.round()}', style: style),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// StatusSelectorCard — one of the 3 tappable counters on top of the list.
// Selected = ink (navy) like the app's PillTabs, brand orange in dark mode.
// ─────────────────────────────────────────────────────────────────────────────
class StatusSelectorCard extends StatelessWidget {
  final IncidentStatus status;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const StatusSelectorCard({
    super.key,
    required this.status,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    final selectedBg = context.isDark ? AppColors.brand : AppColors.ink;
    final fg = selected ? Colors.white : context.colors.onSurface;
    return AnimatedScale(
      scale: selected ? 1.0 : 0.97,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? selectedBg : context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : context.palette.border.withValues(alpha: 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? selectedBg.withValues(alpha: 0.28)
                  : context.palette.cardShadow,
              blurRadius: selected ? 18 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.16)
                              : color.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          status.icon,
                          size: 16,
                          color: selected ? Colors.white : color,
                        ),
                      ),
                      const Spacer(),
                      AnimatedCount(
                        value: count,
                        style: context.text.titleLarge?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          status.pluralLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelMedium?.copyWith(
                            color: selected
                                ? Colors.white.withValues(alpha: 0.85)
                                : context.palette.muted,
                          ),
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// StatusTimeline — En attente → En cours → Résolu with animated progress
// ─────────────────────────────────────────────────────────────────────────────
class IncidentStatusTimeline extends StatelessWidget {
  final IncidentStatus status;
  const IncidentStatusTimeline({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final steps = IncidentStatus.values;
    final current = steps.indexOf(status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                _StepDot(
                  status: steps[i],
                  reached: i <= current,
                  isCurrent: i == current,
                ),
                const SizedBox(height: 8),
                Text(
                  steps[i].label,
                  textAlign: TextAlign.center,
                  style: context.text.labelMedium?.copyWith(
                    fontWeight: i == current
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: i <= current
                        ? context.colors.onSurface
                        : context.palette.muted,
                  ),
                ),
              ],
            ),
          ),
          if (i < steps.length - 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(height: 5, color: context.palette.surfaceAlt),
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: i < current ? 1 : 0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOutCubic,
                        builder: (context, v, _) => FractionallySizedBox(
                          widthFactor: v,
                          child: Container(
                            height: 5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [steps[i].color, steps[i + 1].color],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final IncidentStatus status;
  final bool reached;
  final bool isCurrent;
  const _StepDot({
    required this.status,
    required this.reached,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      width: isCurrent ? 42 : 36,
      height: isCurrent ? 42 : 36,
      decoration: BoxDecoration(
        color: reached ? status.color : context.palette.surfaceAlt,
        shape: BoxShape.circle,
        border: isCurrent
            ? Border.all(color: status.color.withValues(alpha: 0.25), width: 4)
            : null,
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: status.color.withValues(alpha: 0.35),
                  blurRadius: 12,
                ),
              ]
            : const [],
      ),
      alignment: Alignment.center,
      child: Icon(
        status.icon,
        size: isCurrent ? 19 : 17,
        color: reached ? Colors.white : context.palette.muted,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// InfoTile — icon badge + label + value row used in the detail screen
// ─────────────────────────────────────────────────────────────────────────────
class IncidentInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  final VoidCallback? onTap;

  const IncidentInfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            IconBadge(
              icon: icon,
              color: color ?? AppColors.brand,
              size: 40,
              iconSize: 19,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.text.bodySmall),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: context.text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: context.palette.muted),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section card with an icon badge header (same look as the app SectionCard,
// but takes any child widget).
// ─────────────────────────────────────────────────────────────────────────────
class IncidentSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;
  final Color? iconColor;

  const IncidentSection({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) => AppCard(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconBadge(
              icon: icon,
              color: iconColor ?? AppColors.brand,
              size: 32,
              iconSize: 17,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: context.text.titleSmall)),
            ?trailing,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}
