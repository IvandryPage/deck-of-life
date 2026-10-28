import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import '../core/database/app_database.dart';
import '../core/notifications/notification_service.dart';
import '../core/utils/app_info.dart';
import 'bindings/initial_binding.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';
import 'design/tokens.dart';
import 'theme.dart';

class DeckOfLifeApp extends StatelessWidget {
  const DeckOfLifeApp({
    super.key,
    required this.db,
    required this.notifications,
  });

  final AppDatabase db;
  final LocalNotificationService notifications;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      defaultTransition: Transition.rightToLeftWithFade,
      transitionDuration: AppMotion.emphasized,
      initialBinding: InitialBinding(db: db, notifications: notifications),
      initialRoute: Routes.shell,
      getPages: AppPages.pages,
    );
  }
}

/// Ditampilkan bila database tidak bisa dibuka; menghindari layar kosong/crash.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Aplikasi tidak bisa dimulai',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Text(AppInfo.tagline, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
