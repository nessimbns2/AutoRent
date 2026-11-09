import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/app.dart';
import 'core/database/database_helper.dart';
import 'core/services/image_storage.dart';
import 'core/session/session_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await DatabaseHelper.instance.database; // open + create schema + seed
  await ImageStorage.init();              // cache documents dir path
  await SessionManager.instance.init();  // restore logged-in user
  runApp(const AutoRentApp());
}
