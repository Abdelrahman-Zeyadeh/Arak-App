import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/locale_provider.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/downloader/services/download_queue_service.dart';
import 'shared/widgets/app_scaffold.dart';
import 'shared/widgets/share_intent_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SecureStorageService().init();
  await DownloadQueueService().initNotifications();

  runApp(
    const ProviderScope(
      child: ArakApp(),
    ),
  );
}

class ArakApp extends ConsumerWidget {
  const ArakApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme(locale.languageCode),
      darkTheme: AppTheme.darkTheme(locale.languageCode),
      locale: locale,
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ShareIntentHandler(child: const AppScaffold()),
    );
  }
}
