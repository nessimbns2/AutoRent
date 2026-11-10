import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../services/image_storage.dart';
import '../utils/app_exception.dart';
import '../utils/ui_helpers.dart';

// ═════════════════════════════════════════════════════════════════════════════
// AutoRent UI kit — reusable building blocks shared by every screen.
// ═════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
// AppCard — rounded surface with a soft shadow and optional tap feedback
// ─────────────────────────────────────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final bool shadow;
  final bool border;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.onLongPress,
    this.color,
    this.gradient,
    this.radius = AppRadius.lg,
    this.shadow = true,
    this.border = true,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? context.colors.surface) : null,
        gradient: gradient,
        borderRadius: br,
        // Light mode relies on the soft shadow; dark mode on a hairline.
        border: border && gradient == null && color == null && context.isDark
            ? Border.all(color: context.hairline)
            : null,
        boxShadow: shadow ? context.softShadow : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: br,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IconBadge — tinted rounded square holding an icon
// ─────────────────────────────────────────────────────────────────────────────
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;
  final bool filled;

  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
    this.iconSize,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: filled
          ? AppColors.tint(color)
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: context.isDark ? 0.24 : 0.17),
                color.withValues(alpha: context.isDark ? 0.10 : 0.07),
              ],
            ),
      borderRadius: BorderRadius.circular(size * 0.34),
      boxShadow: filled
          ? [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: size * 0.3,
                offset: Offset(0, size * 0.12),
              ),
            ]
          : null,
    ),
    child: Icon(
      icon,
      color: filled ? Colors.white : color,
      size: iconSize ?? size * 0.5,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// LoadingView
// ─────────────────────────────────────────────────────────────────────────────
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      width: 34,
      height: 34,
      child: CircularProgressIndicator(strokeWidth: 3),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ErrorView
// ─────────────────────────────────────────────────────────────────────────────
class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const IconBadge(
            icon: Icons.wifi_tethering_error_rounded,
            color: AppColors.danger,
            size: 72,
          ),
          const SizedBox(height: 18),
          Text(
            'Oups, une erreur est survenue',
            textAlign: TextAlign.center,
            style: context.text.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EmptyState
// ─────────────────────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final String message;
  final String? title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.brand.withValues(alpha: 0.16),
                  AppColors.brand.withValues(alpha: 0.0),
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(26),
                boxShadow: context.brandGlow,
              ),
              child: Icon(icon, size: 36, color: Colors.white),
            ),
          ),
          const SizedBox(height: 18),
          if (title != null) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: context.text.titleMedium,
            ),
            const SizedBox(height: 6),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: context.palette.muted,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 22),
            GradientButton(
              label: actionLabel!,
              icon: Icons.add_rounded,
              onPressed: onAction,
              height: 50,
            ),
          ],
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// StatusChip — soft pill with a coloured dot
// ─────────────────────────────────────────────────────────────────────────────
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool solid;
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: solid ? color : color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, size: 13, color: solid ? Colors.white : color)
        else
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: solid ? Colors.white : color,
              shape: BoxShape.circle,
            ),
          ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: solid ? Colors.white : color,
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SearchField
// ─────────────────────────────────────────────────────────────────────────────
class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;
  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 8),
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md + 2),
              boxShadow: context.softShadow,
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: context.colors.surface,
                prefixIcon: const Icon(Icons.search_rounded),
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md + 2),
                  borderSide: BorderSide(color: context.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md + 2),
                  borderSide: BorderSide(color: context.hairline),
                ),
              ),
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SectionHeader — title + optional action link
// ─────────────────────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(4, 8, 4, 10),
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16.5,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: context.text.labelMedium?.copyWith(
                      color: AppColors.brand,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.brand,
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SectionCard — titled card used by detail & form screens
// ─────────────────────────────────────────────────────────────────────────────
class SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => AppCard(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              IconBadge(
                icon: icon!,
                color: iconColor ?? AppColors.brand,
                size: 32,
                iconSize: 17,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(title, style: context.text.titleSmall)),
            ?trailing,
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// LabeledRow — label on the left, value on the right
// ─────────────────────────────────────────────────────────────────────────────
class LabeledRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;
  final IconData? icon;
  final bool emphasize;
  const LabeledRow({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
    this.icon,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: context.palette.muted),
          const SizedBox(width: 10),
        ],
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: context.text.bodyMedium?.copyWith(
              color: context.palette.muted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          flex: 6,
          child: Align(
            alignment: Alignment.centerRight,
            child:
                trailing ??
                Text(
                  value,
                  textAlign: TextAlign.right,
                  style:
                      (emphasize
                              ? context.text.titleMedium?.copyWith(
                                  color: AppColors.brand,
                                )
                              : context.text.bodyMedium)
                          ?.copyWith(fontWeight: FontWeight.w600),
                ),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// InfoTile — compact icon + label + value tile (spec grids)
// ─────────────────────────────────────────────────────────────────────────────
class InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const InfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppColors.brand,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md + 2),
      border: context.isDark ? Border.all(color: context.hairline) : null,
      boxShadow: context.softShadow,
    ),
    child: Row(
      children: [
        IconBadge(
          icon: icon,
          color: color,
          size: 38,
          iconSize: 19,
          filled: true,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.text.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: context.text.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// InfoBanner — tinted message strip
// ─────────────────────────────────────────────────────────────────────────────
class InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Widget? action;
  const InfoBanner({
    super.key,
    required this.icon,
    required this.text,
    this.color = AppColors.info,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          color.withValues(alpha: context.isDark ? 0.16 : 0.11),
          color.withValues(alpha: context.isDark ? 0.08 : 0.05),
        ],
      ),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: color.withValues(alpha: 0.18)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: context.text.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
        ?action,
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PillTabs — horizontally scrollable filter pills with optional counters
// ─────────────────────────────────────────────────────────────────────────────
class PillTab<T> {
  final T value;
  final String label;
  final int? count;
  final IconData? icon;
  const PillTab(this.value, this.label, {this.count, this.icon});
}

class PillTabs<T> extends StatelessWidget {
  final List<PillTab<T>> tabs;
  final T selected;
  final ValueChanged<T> onChanged;
  final EdgeInsetsGeometry padding;
  const PillTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 50,
    child: ListView.separated(
      // Room for the selected pill's shadow.
      padding: padding.add(const EdgeInsets.symmetric(vertical: 4)),
      scrollDirection: Axis.horizontal,
      itemCount: tabs.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, i) {
        final t = tabs[i];
        final sel = t.value == selected;
        final dark = context.isDark;
        final fg = sel
            ? (dark ? AppColors.ink : Colors.white)
            : context.colors.onSurface;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: sel
                ? (dark ? Colors.white : AppColors.ink)
                : context.colors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: sel
                  ? Colors.transparent
                  : (dark
                        ? context.hairline
                        : context.palette.border.withValues(alpha: 0.7)),
            ),
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: (dark ? Colors.black : AppColors.ink).withValues(
                        alpha: 0.22,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () => onChanged(t.value),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (t.icon != null) ...[
                      Icon(t.icon, size: 16, color: fg),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      t.label,
                      style: context.text.labelMedium?.copyWith(color: fg),
                    ),
                    if (t.count != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          gradient: sel ? AppColors.brandGradient : null,
                          color: sel ? null : context.palette.surfaceAlt,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${t.count}',
                          style: context.text.labelSmall?.copyWith(
                            color: sel ? Colors.white : fg,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PageHeader — large title used at the top of each bottom-nav tab
// ─────────────────────────────────────────────────────────────────────────────
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 14, 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.headlineSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: context.text.bodySmall),
              ],
            ],
          ),
        ),
        ...actions,
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CircleIconButton — round surface button used in headers
// ─────────────────────────────────────────────────────────────────────────────
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final Color? background;
  final int? badge;
  const CircleIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.background,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final plain = background == null;
    final button = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: plain ? context.softShadow : null,
      ),
      child: Material(
        color: background ?? context.colors.surface,
        shape: CircleBorder(
          side: plain && context.isDark
              ? BorderSide(color: context.hairline)
              : BorderSide.none,
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 21,
              color: color ?? context.colors.onSurface,
            ),
          ),
        ),
      ),
    );
    final withBadge = badge == null || badge == 0
        ? button
        : Stack(
            clipBehavior: Clip.none,
            children: [
              button,
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  constraints: const BoxConstraints(minWidth: 18),
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: background ?? context.colors.surface,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    '$badge',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: tooltip == null
          ? withBadge
          : Tooltip(message: tooltip!, child: withBadge),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PrimaryButton — full-width filled button with loading state
// ─────────────────────────────────────────────────────────────────────────────
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final Color? color;
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) => GradientButton(
    label: label,
    icon: icon,
    onPressed: onPressed,
    loading: loading,
    color: color,
    expand: true,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// GradientButton — sunset-gradient button with a soft glow
// ─────────────────────────────────────────────────────────────────────────────
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  /// Solid colour instead of the sunset gradient (e.g. danger actions).
  final Color? color;
  final double height;
  final bool expand;
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.color,
    this.height = 56,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    // A disabled action turns neutral instead of a washed-out gradient.
    final disabled = onPressed == null && !loading;
    final fg = disabled ? context.palette.muted : Colors.white;
    final radius = BorderRadius.circular(AppRadius.md + 2);
    final glowColor = color ?? AppColors.brand;
    final content = loading
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelLarge?.copyWith(
                    color: fg,
                    fontSize: 15,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: 1,
        child: Container(
          width: expand ? double.infinity : null,
          height: height,
          decoration: BoxDecoration(
            gradient: color == null && !disabled
                ? AppColors.brandGradient
                : null,
            color: disabled ? context.palette.surfaceAlt : color,
            borderRadius: radius,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: glowColor.withValues(
                        alpha: context.isDark ? 0.30 : 0.32,
                      ),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: enabled ? onPressed : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Center(widthFactor: 1, child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GradientFab — extended floating button in the sunset gradient
// ─────────────────────────────────────────────────────────────────────────────
class GradientFab extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;

  /// Solid colour instead of the gradient (e.g. red for incidents).
  final Color? backgroundColor;

  /// Kept for call-site compatibility with FloatingActionButton.
  final Object? heroTag;
  const GradientFab({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.backgroundColor,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final glow = backgroundColor ?? AppColors.brand;
    final radius = BorderRadius.circular(22);
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: backgroundColor == null ? AppColors.brandGradient : null,
        color: backgroundColor,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.42),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: IconTheme(
              data: const IconThemeData(color: Colors.white, size: 22),
              child: DefaultTextStyle(
                style: context.text.labelLarge!.copyWith(
                  color: Colors.white,
                  fontSize: 15,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [icon, const SizedBox(width: 8), label],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BottomActionBar — sticky frosted container for the main action(s)
// ─────────────────────────────────────────────────────────────────────────────
class BottomActionBar extends StatelessWidget {
  final Widget child;
  const BottomActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.vertical(
      top: Radius.circular(AppRadius.xl),
    ),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(
            alpha: context.isDark ? 0.86 : 0.9,
          ),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          border: Border(
            top: BorderSide(
              color: context.isDark
                  ? context.hairline
                  : context.palette.border.withValues(alpha: 0.6),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: child,
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// AuroraBackground — midnight gradient lit by soft sunset glows
// ─────────────────────────────────────────────────────────────────────────────
class AuroraBackground extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  const AuroraBackground({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
  });

  static Widget _glow(Color c, double size, double alpha) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            c.withValues(alpha: alpha),
            c.withValues(alpha: alpha * 0.35),
            c.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: borderRadius ?? BorderRadius.zero,
    child: Container(
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Stack(
        children: [
          Positioned(
            top: -110,
            right: -90,
            child: _glow(AppColors.brand, 320, 0.62),
          ),
          Positioned(
            top: -40,
            right: 60,
            child: _glow(AppColors.coral, 200, 0.22),
          ),
          Positioned(
            bottom: -150,
            left: -110,
            child: _glow(const Color(0xFF6366F1), 340, 0.36),
          ),
          if (padding == null)
            child
          else
            Padding(padding: padding!, child: child),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// GlassPanel — frosted translucent panel for dark hero areas
// ─────────────────────────────────────────────────────────────────────────────
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double opacity;
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = AppRadius.lg,
    this.opacity = 0.08,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: opacity + 0.04),
              Colors.white.withValues(alpha: opacity * 0.5),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: child,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// GradientText — text painted with the sunset gradient
// ─────────────────────────────────────────────────────────────────────────────
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient gradient;
  const GradientText(
    this.text, {
    super.key,
    this.style,
    this.gradient = AppColors.brandGradient,
  });

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (r) => gradient.createShader(Offset.zero & r.size),
    child: Text(text, style: style),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// AvatarCircle — photo or initials
// ─────────────────────────────────────────────────────────────────────────────
class AvatarCircle extends StatelessWidget {
  final String initials;
  final String? photoFile;
  final double size;
  final Color? color;
  const AvatarCircle({
    super.key,
    required this.initials,
    this.photoFile,
    this.size = 44,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? _colorFor(initials);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: photoFile == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.withValues(alpha: 0.85), c],
              )
            : null,
        image: photoFile != null
            ? DecorationImage(
                image: ResizeImage(
                  FileImage(ImageStorage.fileFor(photoFile!)),
                  width: 800,
                ),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: photoFile == null
          ? Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.36,
              ),
            )
          : null,
    );
  }

  static Color _colorFor(String s) {
    const options = [
      AppColors.brand,
      AppColors.info,
      AppColors.violet,
      AppColors.teal,
      AppColors.success,
      AppColors.ink3,
    ];
    final h = s.codeUnits.fold<int>(0, (a, b) => a + b);
    return options[h % options.length];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CarPlaceholder — soft gradient + car glyph for vehicles without photo
// ─────────────────────────────────────────────────────────────────────────────
class CarPlaceholder extends StatelessWidget {
  final int seed;
  final double? iconSize;
  const CarPlaceholder({super.key, this.seed = 0, this.iconSize});

  @override
  Widget build(BuildContext context) {
    final g =
        AppColors.carGradients[seed.abs() % AppColors.carGradients.length];
    return LayoutBuilder(
      builder: (context, c) {
        final s =
            iconSize ??
            (c.maxWidth.isFinite
                ? (c.maxWidth * 0.42).clamp(20.0, 120.0)
                : 48.0);
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: context.isDark
                  ? [g[0].withValues(alpha: 0.25), g[1].withValues(alpha: 0.35)]
                  : g,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.directions_car_filled_rounded,
            size: s,
            color: Colors.white.withValues(alpha: 0.92),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CarImage — Image.file with graceful fallback to [CarPlaceholder]
// ─────────────────────────────────────────────────────────────────────────────
class CarImage extends StatelessWidget {
  final String? fileName;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int seed;
  const CarImage({
    super.key,
    this.fileName,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.seed = 0,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = SizedBox(
      width: width,
      height: height,
      child: CarPlaceholder(seed: seed),
    );
    if (fileName == null) return placeholder;
    return Image.file(
      ImageStorage.fileFor(fileName!),
      fit: fit,
      width: width,
      height: height,
      // Decode at display size, not full camera resolution.
      cacheWidth: (width != null && width!.isFinite)
          ? (width! * MediaQuery.devicePixelRatioOf(context)).round()
          : 800,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PhotoStrip — horizontal scrollable strip of photo thumbnails
// ─────────────────────────────────────────────────────────────────────────────
class PhotoStrip extends StatelessWidget {
  final List<String> fileNames;
  final void Function(int index) onTap;
  final double size;
  const PhotoStrip({
    super.key,
    required this.fileNames,
    required this.onTap,
    this.size = 76,
  });

  @override
  Widget build(BuildContext context) {
    if (fileNames.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: fileNames.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => onTap(i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: CarImage(fileName: fileNames[i], width: size, height: size),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PhotoPickerField
// ─────────────────────────────────────────────────────────────────────────────
class PhotoPickerField extends StatefulWidget {
  final List<String> fileNames;
  final int maxPhotos;
  final ValueChanged<List<String>> onChanged;

  /// Shows a "Couverture" label on the first photo and a star on the others
  /// to make them the cover (moved to the first position).
  final bool coverSelectable;
  const PhotoPickerField({
    super.key,
    required this.fileNames,
    required this.onChanged,
    this.maxPhotos = 6,
    this.coverSelectable = false,
  });

  @override
  State<PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<PhotoPickerField> {
  late List<String> _files;

  @override
  void initState() {
    super.initState();
    _files = List<String>.from(widget.fileNames);
  }

  Future<void> _addPhoto() async {
    final source = await pickImageSource(context);
    if (source == null || !mounted) return;
    String? name;
    try {
      name = await ImageStorage.pickAndSave(source);
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, kind: SnackKind.error);
      return;
    }
    if (name == null || !mounted) return;
    final saved = name;
    setState(() => _files.add(saved));
    widget.onChanged(_files);
  }

  void _removePhoto(int i) {
    setState(() => _files.removeAt(i));
    widget.onChanged(_files);
  }

  void _makeCover(int i) {
    if (i == 0) return;
    setState(() => _files.insert(0, _files.removeAt(i)));
    widget.onChanged(_files);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (_files.length < widget.maxPhotos)
            Padding(
              padding: const EdgeInsets.only(right: 10, top: 6),
              child: InkWell(
                onTap: _addPhoto,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.brand.withValues(alpha: 0.45),
                      width: 1.4,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_a_photo_rounded,
                        color: AppColors.brand,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_files.length}/${widget.maxPhotos}',
                        style: context.text.labelSmall?.copyWith(
                          color: AppColors.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ..._files.asMap().entries.map(
            (e) => Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 10, top: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: CarImage(fileName: e.value, width: 82, height: 82),
                  ),
                ),
                if (widget.coverSelectable && e.key == 0)
                  Positioned(
                    left: 0,
                    right: 10,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text(
                        'Couverture',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (widget.coverSelectable && e.key > 0)
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: Tooltip(
                      message: 'Définir comme couverture',
                      child: GestureDetector(
                        onTap: () => _makeCover(e.key),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.star_outline_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 0,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _removePhoto(e.key),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.colors.surface,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks where the photo comes from. The camera is only offered where the
/// platform supports it (not on Windows / Linux desktop); when the gallery is
/// the only choice and there is nothing to remove, it is opened directly.
Future<ImageSource?> pickImageSource(
  BuildContext context, {
  VoidCallback? onRemove,
}) async {
  final hasCamera = ImagePicker().supportsImageSource(ImageSource.camera);
  if (!hasCamera && onRemove == null) return ImageSource.gallery;

  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ajouter une photo', style: sheetCtx.text.titleMedium),
            const SizedBox(height: 14),
            if (hasCamera)
              ListTile(
                leading: const IconBadge(
                  icon: Icons.photo_camera_rounded,
                  color: AppColors.brand,
                ),
                title: const Text('Appareil photo'),
                subtitle: const Text('Prendre une nouvelle photo'),
                onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
              ),
            ListTile(
              leading: const IconBadge(
                icon: Icons.photo_library_rounded,
                color: AppColors.info,
              ),
              title: Text(hasCamera ? 'Galerie' : 'Choisir un fichier'),
              subtitle: Text(
                hasCamera
                    ? 'Choisir une image existante'
                    : 'Parcourir les images de l\'ordinateur',
              ),
              onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
            ),
            if (onRemove != null)
              ListTile(
                leading: const IconBadge(
                  icon: Icons.delete_outline_rounded,
                  color: AppColors.danger,
                ),
                title: const Text(
                  'Supprimer la photo',
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  onRemove();
                },
              ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FormSection — groups form fields inside a titled card
// ─────────────────────────────────────────────────────────────────────────────
class FormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color color;
  const FormSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.color = AppColors.brand,
  });

  @override
  Widget build(BuildContext context) => SectionCard(
    title: title,
    icon: icon,
    iconColor: color,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        children[i],
      ],
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ResponsiveCenter — constrains and centres content on wide screens
// ─────────────────────────────────────────────────────────────────────────────
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 640,
    this.padding,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DetailMenu — "more" popup used in detail app bars (edit / delete …)
// ─────────────────────────────────────────────────────────────────────────────
class DetailMenuItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;
  const DetailMenuItem(
    this.label,
    this.icon,
    this.onTap, {
    this.destructive = false,
  });
}

class DetailMenu extends StatelessWidget {
  final List<DetailMenuItem> items;
  const DetailMenu({super.key, required this.items});

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
    tooltip: 'Plus d\'actions',
    icon: const Icon(Icons.more_horiz_rounded),
    position: PopupMenuPosition.under,
    onSelected: (i) => items[i].onTap(),
    itemBuilder: (_) => [
      for (var i = 0; i < items.length; i++)
        PopupMenuItem(
          value: i,
          child: Row(
            children: [
              Icon(
                items[i].icon,
                size: 20,
                color: items[i].destructive
                    ? AppColors.danger
                    : context.colors.onSurface,
              ),
              const SizedBox(width: 12),
              Text(
                items[i].label,
                style: TextStyle(
                  color: items[i].destructive ? AppColors.danger : null,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
