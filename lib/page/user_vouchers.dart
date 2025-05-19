import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/network_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class UserVouchersPage extends StatefulWidget {
  const UserVouchersPage({Key? key}) : super(key: key);

  @override
  State<UserVouchersPage> createState() => _UserVouchersPageState();
}

class _UserVouchersPageState extends State<UserVouchersPage> {
  List<dynamic> vouchers = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchVouchers();
  }

  Future<void> fetchVouchers() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final user = AuthService.currentUser;
      if (user == null || user['id'] == null) {
        setState(() {
          error = 'Bạn chưa đăng nhập!';
          loading = false;
        });
        return;
      }
      final url = '${NetworkService.defaultIp}/api/vouchers/user/${user['id']}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          vouchers = json.decode(response.body);
          loading = false;
        });
      } else {
        setState(() {
          error = 'Không thể tải danh sách mã giảm giá.';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Có lỗi xảy ra. Vui lòng thử lại sau.';
        loading = false;
      });
    }
  }

  String formatCurrency(dynamic amount) {
    if (amount == null) return '';
    return NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(amount);
  }

  String formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    final date = DateTime.tryParse(dateString);
    if (date == null) return 'N/A';
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String getVoucherStatus(Map voucher) {
    final now = DateTime.now();
    final startDate = DateTime.tryParse(voucher['startDate'] ?? '') ?? now;
    final endDate = DateTime.tryParse(voucher['endDate'] ?? '') ?? now;
    if (voucher['used'] == true) return 'Đã sử dụng';
    if (now.isBefore(startDate)) return 'Chưa có hiệu lực';
    if (now.isAfter(endDate)) return 'Hết hạn';
    return 'Có hiệu lực';
  }

  Color getVoucherStatusColor(Map voucher) {
    final now = DateTime.now();
    final startDate = DateTime.tryParse(voucher['startDate'] ?? '') ?? now;
    final endDate = DateTime.tryParse(voucher['endDate'] ?? '') ?? now;
    if (voucher['used'] == true) return Colors.grey;
    if (now.isBefore(startDate)) return Colors.orange;
    if (now.isAfter(endDate)) return Colors.red;
    return Colors.green;
  }

  Duration getTimeLeft(Map voucher) {
    final endDate = DateTime.tryParse(voucher['endDate'] ?? '');
    if (endDate == null) return Duration.zero;
    final now = DateTime.now();
    final diff = endDate.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  Widget buildCountdown(Duration duration) {
    if (duration == Duration.zero) {
      return const Text('Đã hết hạn', style: TextStyle(color: Colors.red));
    }
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return Row(
      children: [
        if (days > 0)
          Text('$days ngày ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('$hours giờ ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('$minutes phút ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('$seconds giây', style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mã giảm giá của tôi')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : vouchers.isEmpty
                  ? const Center(child: Text('Bạn chưa có mã giảm giá nào.'))
                  : RefreshIndicator(
                      onRefresh: fetchVouchers,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: vouchers.length,
                        itemBuilder: (context, index) {
                          final voucher = vouchers[index];
                          final status = getVoucherStatus(voucher);
                          final statusColor = getVoucherStatusColor(voucher);
                          final timeLeft = getTimeLeft(voucher);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.card_giftcard, color: statusColor),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          voucher['discountType'] == 'percentage'
                                              ? 'Giảm ${voucher['discountValue']}%'
                                              : 'Giảm ${formatCurrency(voucher['discountValue'])}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.purple[50],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  voucher['code'] ?? '',
                                                  style: const TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.purple,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.copy, color: Colors.purple),
                                                onPressed: () {
                                                  Clipboard.setData(ClipboardData(text: voucher['code'] ?? ''));
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Đã sao chép mã!')),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Thời gian: ${formatDate(voucher['startDate'])} - ${formatDate(voucher['endDate'])}'),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Text('Hết hạn sau: '),
                                      buildCountdown(timeLeft),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
} 