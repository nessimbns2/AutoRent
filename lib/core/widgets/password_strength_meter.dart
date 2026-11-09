import 'package:flutter/material.dart';

import '../utils/password_policy.dart';

/// Live strength bar under a password field. Listens to [controller] itself,
/// so the parent does not need to call setState.
class PasswordStrengthMeter extends StatelessWidget {
  final TextEditingController controller;
  const PasswordStrengthMeter({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (value.text.isEmpty) return const SizedBox.shrink();
        final (color, label, fraction) =
            switch (PasswordPolicy.strength(value.text)) {
          PasswordStrength.weak => (Colors.red, 'faible', 0.25),
          PasswordStrength.fair => (Colors.orange, 'moyenne', 0.5),
          PasswordStrength.good => (Colors.lightGreen, 'bonne', 0.75),
          PasswordStrength.strong => (Colors.green, 'excellente', 1.0),
        };
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 6,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(height: 4),
              Text('Robustesse : $label',
                  style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        );
      },
    );
  }
}
