import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/database/app_database.dart';
import 'core/errors/app_exception.dart';
import 'core/notifications/notification_service.dart';
import 'data/repositories/routine_repository_impl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');

  final AppDatabase db;
  try {
    db = await AppDatabase.open();
    await RoutineRepositoryImpl(db).migrateToRecurringTasks();
  } on AppException catch (e) {
    runApp(StartupErrorApp(message: e.message));
    return;
  }

  // Kegagalan notifikasi tidak boleh menghalangi aplikasi dibuka.
  final notifications = LocalNotificationService();
  try {
    await notifications.init();
  } catch (e, st) {
    AppLog.error('notifications.init', e, st);
  }

  runApp(DeckOfLifeApp(db: db, notifications: notifications));
}
