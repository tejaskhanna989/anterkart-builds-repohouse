import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/product_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'providers/address_provider.dart';
import 'providers/banner_provider.dart';
import 'providers/location_provider.dart';
import 'providers/store_provider.dart';
import 'providers/theme_provider.dart';
import 'services/push_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/profile_screen.dart';

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
  
  runApp(const OtamzoCustomerApp());
}

class OtamzoCustomerApp extends StatelessWidget {
  const OtamzoCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => AddressProvider()),
        ChangeNotifierProvider(create: (_) => BannerProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => StoreProvider()..init()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, theme, __) => MaterialApp(
          title: 'Otamzo',
          debugShowCheckedModeBanner: false,
          navigatorKey: appNavigatorKey,
          theme: buildAppTheme(),
          darkTheme: buildDarkAppTheme(),
          themeMode: theme.themeMode,
          home: const SplashScreen(),
          routes: {
            '/login': (_) => const LoginScreen(),
            '/register': (_) => const RegisterScreen(),
            '/home': (_) => const HomeScreen(),
            '/cart': (_) => const CartScreen(),
            '/orders': (_) => const OrdersScreen(),
            '/profile': (_) => const ProfileScreen(),
          },
        ),
      ),
    );
  }
}
