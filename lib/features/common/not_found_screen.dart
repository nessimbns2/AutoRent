import 'package:flutter/material.dart';

class NotFoundScreen extends StatelessWidget {
  final String? routeName;
  final String? message;
  const NotFoundScreen({super.key, this.routeName, this.message});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Page introuvable')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                message ?? 'La page "${routeName ?? ''}" est introuvable.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(160, 48)),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
}
