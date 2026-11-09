import 'package:flutter/material.dart';

import 'app_router.dart';
import 'routes.dart';
import 'theme.dart';

class AutoRentApp extends StatelessWidget {
  const AutoRentApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'AutoRent',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        initialRoute: Routes.splash,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onUnknownRoute: AppRouter.onUnknownRoute,
      );
}
