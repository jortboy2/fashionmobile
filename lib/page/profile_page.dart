import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/network_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import 'lucky_wheel.dart';
import 'user_vouchers.dart';
import 'user_profile_page.dart';

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
      body: user == null
          ? const Center(child: Text('Bạn chưa đăng nhập!'))
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.purple.shade100,
                    Colors.white,
                  ],
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Profile Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.purple.shade300,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.purple.shade100,
                                child: Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.purple.shade300,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              user['username'] ?? '',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              user['email'] ?? '',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Profile Actions
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            _buildActionButton(
                              context,
                              icon: Icons.person,
                              label: 'Thông tin cá nhân',
                              color: Colors.orange,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const UserProfilePage()),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildActionButton(
                              context,
                              icon: Icons.shopping_bag,
                              label: 'Xem đơn hàng của tôi',
                              color: Colors.blue,
                              onTap: () => Navigator.pushNamed(context, '/orders'),
                            ),
                            const SizedBox(height: 16),
                            _buildActionButton(
                              context,
                              icon: Icons.casino,
                              label: 'Vòng quay may mắn',
                              color: Colors.purple,
                              onTap: () => _showLuckyWheel(context),
                            ),
                            const SizedBox(height: 16),
                            _buildActionButton(
                              context,
                              icon: Icons.card_giftcard,
                              label: 'Mã giảm giá của tôi',
                              color: Colors.green,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const UserVouchersPage()),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildActionButton(
                              context,
                              icon: Icons.logout,
                              label: 'Đăng xuất',
                              color: Colors.red,
                              onTap: () {
                                AuthService.logout();
                                Navigator.pushReplacementNamed(context, '/login');
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color,
                  color.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}