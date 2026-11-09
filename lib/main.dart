import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/app.dart';
import 'core/database/database_helper.dart';
import 'core/services/image_storage.dart';
import 'core/services/theme_controller.dart';
import 'core/session/session_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Transparent status bar on Android for the edge-to-edge headers.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  await DatabaseHelper.instance.database; // open SQLite + create schema + seed
  await ImageStorage.init(); //              cache documents dir path
  await ThemeController.instance.init(); //  light / dark preference
  await SessionManager.instance.init(); //   restore logged-in user
  runApp(const AutoRentApp());
}
