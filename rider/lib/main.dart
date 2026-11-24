import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/order_provider.dart';
import 'providers/earnings_provider.dart';
import 'providers/location_provider.dart';
import 'services/push_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushService.init(appNavigatorKey);
  
  // Configure system UI overlays - prevent content under status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  // Ensure edge-to-edge layout with safe areas handled by Scaffold/SafeArea
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  runApp(const OtamzoRiderApp());
}

class OtamzoRiderApp extends StatelessWidget {
  const OtamzoRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => EarningsProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: MaterialApp(
        title: 'Otamzo Rider',
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        theme: buildAppTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}
