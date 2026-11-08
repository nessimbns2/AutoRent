import 'package:flutter/material.dart';

import '../../../models/enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Visual identity of the incidents module (colors, icons, gradients)
// ─────────────────────────────────────────────────────────────────────────────

extension IncidentTypeStyle on IncidentType {
  Color get color => switch (this) {
        IncidentType.accident => const Color(0xFFE53935),
        IncidentType.panne => const Color(0xFFF57C00),
      };

  IconData get icon => switch (this) {
        IncidentType.accident => Icons.car_crash_rounded,
        IncidentType.panne => Icons.car_repair_rounded,
      };

  String get hint => switch (this) {
        IncidentType.accident => 'Collision, choc, accrochage',
        IncidentType.panne => 'Moteur, batterie, pneu, électrique',
      };

  LinearGradient get gradient => switch (this) {
        IncidentType.accident => const LinearGradient(
            colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        IncidentType.panne => const LinearGradient(
            colors: [Color(0xFFFFA726), Color(0xFFE65100)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
      };
}

extension IncidentStatusStyle on IncidentStatus {
  Color get color => switch (this) {
        IncidentStatus.enAttente => const Color(0xFFF59E0B),
        IncidentStatus.enCours => const Color(0xFF3B82F6),
        IncidentStatus.resolu => const Color(0xFF10B981),
      };

  IconData get icon => switch (this) {
        IncidentStatus.enAttente => Icons.hourglass_top_rounded,
        IncidentStatus.enCours => Icons.engineering_rounded,
        IncidentStatus.resolu => Icons.verified_rounded,
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
// TypeBadge — rounded gradient square with the type icon (used in a Hero)
// ─────────────────────────────────────────────────────────────────────────────
class IncidentTypeBadge extends StatelessWidget {
  final IncidentType type;
  final double size;
  final bool onDark;
  const IncidentTypeBadge({
    super.key,
    required this.type,
    this.size = 48,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: onDark ? null : type.gradient,
          color: onDark ? Colors.white.withValues(alpha: 0.2) : null,
          borderRadius: BorderRadius.circular(size * 0.3),
          border: onDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.5))
              : null,
          boxShadow: onDark
              ? null
              : [
                  BoxShadow(
                    color: type.color.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Icon(type.icon, color: Colors.white, size: size * 0.55),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// StatusPill — colored status label with an icon
// ─────────────────────────────────────────────────────────────────────────────
class IncidentStatusPill extends StatelessWidget {
  final IncidentStatus status;
  final bool onDark;
  const IncidentStatusPill({super.key, required this.status, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : status.color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.2)
            : status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
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
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _curve =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

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
// StatusSelectorCard — one of the 3 tappable counters on top of the list
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
    final scheme = Theme.of(context).colorScheme;
    final color = status.color;
    return AnimatedScale(
      scale: selected ? 1.0 : 0.96,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? color : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? color : scheme.outlineVariant,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.25)
                              : color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(status.icon,
                            size: 16, color: selected ? Colors.white : color),
                      ),
                      const Spacer(),
                      AnimatedCount(
                        value: count,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : scheme.onSurfaceVariant,
                    ),
                    child: Text(
                      status.pluralLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
    final scheme = Theme.of(context).colorScheme;

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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: i == current ? FontWeight.w800 : FontWeight.w500,
                    color: i <= current
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (i < steps.length - 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 17),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(height: 6, color: scheme.surfaceContainerHighest),
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: i < current ? 1 : 0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOutCubic,
                        builder: (context, v, _) => FractionallySizedBox(
                          widthFactor: v,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                steps[i].color,
                                steps[i + 1].color,
                              ]),
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
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      width: isCurrent ? 40 : 34,
      height: isCurrent ? 40 : 34,
      decoration: BoxDecoration(
        color: reached ? status.color : scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: status.color.withValues(alpha: 0.45),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
        child: Icon(
          reached && !isCurrent ? Icons.check_rounded : status.icon,
          key: ValueKey('${status.value}-$reached-$isCurrent'),
          size: 18,
          color: reached ? Colors.white : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// InfoTile — icon + label + value row used in the detail screen
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
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: c),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SectionCard with an icon header (detail + form)
// ─────────────────────────────────────────────────────────────────────────────
class IncidentSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  const IncidentSection({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
