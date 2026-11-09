import 'package:flutter/material.dart';

import '../../core/widgets/shared_widgets.dart';

class NotFoundScreen extends StatelessWidget {
  final String? routeName;
  final String? message;
  const NotFoundScreen({super.key, this.routeName, this.message});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.explore_off_rounded,
          title: 'Page introuvable',
          message: message ?? 'La page « ${routeName ?? ''} » n\'existe pas.',
        ),
        bottomNavigationBar: BottomActionBar(
          child: PrimaryButton(
            label: 'Retour',
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
      );
}
