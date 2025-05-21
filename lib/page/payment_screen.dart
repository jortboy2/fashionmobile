import 'package:fashionmobile/page/payment_webview.dart';
import 'package:flutter/material.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../services/size_service.dart';
import '../services/auth_service.dart';
import '../services/payment_service.dart';
import 'payment_success_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/network_service.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedPaymentMethod = 'cash'; // Default to cash
  bool _isProcessing = false;

  // Discount code
  final TextEditingController _discountController = TextEditingController();
  String? _discountError;
  Map? _appliedDiscount;
  bool _isUserVoucher = false;

  @override
  void initState() {
    super.initState();
    CartService.initCart();
    _prefillUserData();
  }

  void _prefillUserData() {
    final currentUser = AuthService.currentUser;
    if (currentUser != null) {
      _nameController.text = currentUser['username'] ?? '';
      _emailController.text = currentUser['email'] ?? '';
      _phoneController.text = currentUser['phone'] ?? '';
    }
  }

  Future<void> _applyDiscountCode() async {
    setState(() {
      _discountError = null;
      _appliedDiscount = null;
      _isUserVoucher = false;
    });
    final code = _discountController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _discountError = 'Vui lòng nhập mã giảm giá';
      });
      return;
    }
    try {
      // Thử validate mã giảm giá sản phẩm (nếu có API riêng, bạn thay URL cho đúng)
      final response = await http.get(Uri.parse('${NetworkService.defaultIp}/api/discounts/validate?code=$code'));
      if (response.statusCode == 200) {
        setState(() {
          _appliedDiscount = json.decode(response.body);
          _isUserVoucher = false;
          _discountError = null;
        });
        return;
      }
    } catch (_) {}
    // Nếu không phải mã sản phẩm, thử voucher cá nhân
    final user = AuthService.currentUser;
    if (user != null && user['id'] != null) {
      try {
        final voucherRes = await http.get(Uri.parse('${NetworkService.defaultIp}/api/vouchers/use?userId=${user['id']}&code=$code'));
        if (voucherRes.statusCode == 200) {
          setState(() {
            _appliedDiscount = json.decode(voucherRes.body);
            _isUserVoucher = true;
            _discountError = null;
          });
          return;
        } else {
          setState(() {
            _discountError = utf8.decode(voucherRes.bodyBytes);
            _appliedDiscount = null;
          });
        }
      } catch (e) {
        setState(() {
          _discountError = 'Không thể kiểm tra mã giảm giá. Vui lòng thử lại.';
          _appliedDiscount = null;
        });
      }
    } else {
      setState(() {
        _discountError = 'Bạn cần đăng nhập để sử dụng mã giảm giá cá nhân';
        _appliedDiscount = null;
      });
    }
  }

  double _calculateDiscountedTotal() {
    final subtotal = CartService.totalPrice;
    if (_appliedDiscount == null) return subtotal;
    final discountType = _appliedDiscount!['discountType'] ?? _appliedDiscount!['discount_type'];
    final discountValue = _appliedDiscount!['discountValue'] ?? _appliedDiscount!['discount_value'];
    if (discountType == 'percentage') {
      return subtotal * (1 - (discountValue / 100));
    } else {
      return (subtotal - discountValue).clamp(0, double.infinity);
    }
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Lấy danh sách size từ API
      final sizes = await SizeService.getAllSizes();

      // Map order items, đảm bảo có sizeId
      final orderItems = CartService.cartItems.map((item) {
        final sizeId = item['sizeId'];
        if (sizeId == null) {
          throw Exception('Không tìm thấy sizeId cho sản phẩm ${item['product']['name']} với size ${item['size']}');
        }
        return {
          'productId': item['product']['id'],
          'quantity': item['quantity'],
          'price': item['product']['price'],
          'sizeId': sizeId,
        };
      }).toList();

      final userId = AuthService.currentUser != null ? AuthService.currentUser!['id'] : null;
      if (userId == null) {
        throw Exception('Không tìm thấy thông tin người dùng. Vui lòng đăng nhập lại.');
      }

      final orderData = {
        'userId': userId,
        'total': _calculateDiscountedTotal(),
        'status': 'Chờ xác nhận',
        'paymentStatus': _selectedPaymentMethod == 'cash' 
            ? 'Chưa thanh toán' 
            : 'Chờ thanh toán',
        'paymentMethod': _selectedPaymentMethod,
        'receiverName': _nameController.text,
        'receiverEmail': _emailController.text,
        'receiverPhone': _phoneController.text,
        'receiverAddress': _addressController.text,
        'orderItems': orderItems,
        'discountCode': _appliedDiscount != null ? _appliedDiscount!['code'] : null,
        'isUserVoucher': _isUserVoucher,
      };

      if (_selectedPaymentMethod == 'cash') {
        // For cash payment, create order and show success screen
        final orderResponse = await OrderService.createOrder(
          userId: userId,
          total: _calculateDiscountedTotal(),
          status: 'Chờ xác nhận',
          paymentStatus: 'Chưa thanh toán',
          paymentMethod: 'cash',
          receiverName: _nameController.text,
          receiverEmail: _emailController.text,
          receiverPhone: _phoneController.text,
          receiverAddress: _addressController.text,
          orderItems: orderItems,
        );
        await CartService.clearCart();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentSuccessScreen(
                orderData: orderResponse,
              ),
            ),
          );
        }
      } else if (_selectedPaymentMethod == 'vnpay') {
        // For VNPay
        try {
          final paymentUrl = await PaymentService.createVNPayPayment(
            voucherCode: _appliedDiscount != null ? _appliedDiscount!['code'] : null,
            userId: userId,
            orderData: orderData,
          );
          await CartService.clearCart();
          
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PaymentWebView(
                  paymentUrl: paymentUrl,
                  onPaymentComplete: (response) {
                    if (response['success'] == true) {
                      final orderData = response['data'];
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PaymentSuccessScreen(
                            orderData: orderData,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(response['message'] ?? 'Thanh toán thất bại'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      Navigator.pop(context); // Quay lại màn hình thanh toán
                    }
                  },
                ),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Lỗi thanh toán VNPay: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Summary Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tóm tắt đơn hàng',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...CartService.cartItems.map((item) => _buildOrderItem(
                            '${item['product']['name']} (${item['size']})',
                            '${(item['product']['price'] * item['quantity']).toStringAsFixed(0)}đ',
                          )),
                      _buildOrderItem('Phí vận chuyển', 'Miễn phí'),
                      const Divider(),
                      // Discount code UI
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Mã giảm giá', style: TextStyle(fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _discountController,
                                    decoration: const InputDecoration(
                                      hintText: 'Nhập mã giảm giá',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _isProcessing ? null : _applyDiscountCode,
                                  child: const Text('Áp dụng'),
                                ),
                              ],
                            ),
                            if (_discountError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(_discountError!, style: const TextStyle(color: Colors.red)),
                              ),
                            if (_appliedDiscount != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Đã áp dụng ${_isUserVoucher ? 'voucher' : 'mã giảm giá'}: ${_appliedDiscount!['code']}',
                                  style: const TextStyle(color: Colors.green),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(),
                      _buildOrderItem(
                        'Tổng cộng',
                        '${_calculateDiscountedTotal().toStringAsFixed(0)}đ',
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Delivery Information Section
              const Text(
                'Thông tin giao hàng',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập họ tên';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập email';
                  }
                  if (!value.contains('@')) {
                    return 'Email không hợp lệ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập số điện thoại';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập địa chỉ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Payment Method Section
              const Text(
                'Phương thức thanh toán',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('Thanh toán tiền mặt'),
                      value: 'cash',
                      groupValue: _selectedPaymentMethod,
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value!;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Thanh toán qua VNPay'),
                      value: 'vnpay',
                      groupValue: _selectedPaymentMethod,
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Payment Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Thanh toán',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderItem(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
} 