import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'orders_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String orderNumber;
  const OrderSuccessScreen({super.key, required this.orderNumber});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981)),
                child: const Icon(Icons.check, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text('Order Placed!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Order #$orderNumber', style: const TextStyle(fontSize: 16, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Your food is being prepared', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false),
                  child: const Text('Back to Home'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const OrdersScreen()), (r) => false),
                child: const Text('View My Orders'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
