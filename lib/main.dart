import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/accounts_provider.dart';
import 'providers/budgets_provider.dart';
import 'providers/categories_provider.dart';
import 'providers/recurring_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/transactions_provider.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_PE');
  runApp(const MiGastoApp());
}

class MiGastoApp extends StatelessWidget {
  const MiGastoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => CategoriesProvider()..load()),
        ChangeNotifierProvider(create: (_) => AccountsProvider()..load()),
        ChangeNotifierProvider(create: (_) => TransactionsProvider()..load()),
        ChangeNotifierProvider(create: (_) => BudgetsProvider()..load()),
        ChangeNotifierProvider(create: (_) => RecurringProvider()..load()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'MiGasto',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorSchemeSeed: const Color(0xFF2E7D32),
              useMaterial3: true,
              brightness: Brightness.light,
              fontFamily: 'Alata',
            ),
            darkTheme: ThemeData(
              colorSchemeSeed: const Color(0xFF2E7D32),
              useMaterial3: true,
              brightness: Brightness.dark,
              fontFamily: 'Alata',
            ),
            themeMode: settings.themeMode,
            locale: const Locale('es', 'PE'),
            supportedLocales: const [Locale('es', 'PE')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
