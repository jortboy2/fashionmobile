import 'package:device_preview/device_preview.dart';
import 'package:fashionmobile/page/home.dart';
import 'package:fashionmobile/page/product_page.dart';
import 'package:fashionmobile/page/product_detail_page.dart';
import 'package:fashionmobile/page/login_page.dart';
import 'package:fashionmobile/page/register_page.dart';
import 'package:fashionmobile/page/orders_page.dart';
import 'package:fashionmobile/page/payment_success_screen.dart';
import 'package:fashionmobile/services/payment_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() {
  runApp(DevicePreview(
    enabled: !kReleaseMode,
    builder: (context) => const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fashion Mobile',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      navigatorObservers: [routeObserver],
      initialRoute: '/',
      onGenerateRoute: (settings) {
        // Handle VNPay web return URL
        if (settings.name?.startsWith('/payment/vnpay/return/web') == true) {
          final uri = Uri.parse(settings.name!);
          return MaterialPageRoute(
            builder: (context) => PaymentSuccessScreen(
              returnUri: uri,
            ),
          );
        }
        return null;
      },
      routes: {
        '/': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/product-detail': (context) => const ProductDetailPage(),
        '/products': (context) => ProductPage(
              categoryId: ModalRoute.of(context)!.settings.arguments as int,
            ),
        '/orders': (context) => const OrdersPage(),
      },
    );
  }
}

