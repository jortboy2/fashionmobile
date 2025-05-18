import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'lucky_wheel.dart';
import 'user_vouchers.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  void _showLuckyWheel(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => LuckyWheel(
        userId: AuthService.currentUser?['id'] ?? 0,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: user == null
          ? const Center(child: Text('Bạn chưa đăng nhập!'))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  const Text('Thông tin tài khoản', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 28),
                      const SizedBox(width: 12),
                      Text('Username: ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                      Text(user['username'] ?? '', style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.email, size: 28),
                      const SizedBox(width: 12),
                      Text('Email: ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                      Text(user['email'] ?? '', style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/orders');
                    },
                    icon: const Icon(Icons.shopping_bag),
                    label: const Text('Xem đơn hàng của tôi'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showLuckyWheel(context),
                    icon: const Icon(Icons.casino),
                    label: const Text('Vòng quay may mắn'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const UserVouchersPage()),
                      );
                    },
                    icon: const Icon(Icons.card_giftcard),
                    label: const Text('Mã giảm giá của tôi'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      AuthService.logout();
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Đăng xuất'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 