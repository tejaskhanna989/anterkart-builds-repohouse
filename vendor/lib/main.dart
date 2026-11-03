import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/order_provider.dart';
import 'providers/product_provider.dart';
import 'providers/stats_provider.dart';
import 'services/onesignal_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Initializes OneSignal with the app id from ApiConfig. Push permission is
  // NOT requested here — the native verification dialog requests it once the
  // device registers (see OneSignalManager in android/).
  OneSignalService.initialize();
  runApp(const OtamzoVendorApp());
}

class OtamzoVendorApp extends StatelessWidget {
  const OtamzoVendorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => StatsProvider()),
      ],
      child: MaterialApp(
        title: 'Otamzo Vendor',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}
