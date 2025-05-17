import 'package:flutter/material.dart';
import '../services/payment_service.dart';
import '../services/network_service.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final Map<String, dynamic>? orderData;
  final Uri? returnUri;

  const PaymentSuccessScreen({
    super.key,
    this.orderData,
    this.returnUri,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _orderData;
  static const String baseUrl = NetworkService.defaultIp;

  @override
  void initState() {
    super.initState();
    print('PaymentSuccessScreen - Initial orderData: ${widget.orderData}');
    print('PaymentSuccessScreen - Initial returnUri: ${widget.returnUri}');
    
    if (widget.returnUri != null) {
      _handlePaymentReturn();
    } else {
      setState(() {
        _isLoading = false;
        _orderData = widget.orderData;
        print('PaymentSuccessScreen - Setting orderData from widget: $_orderData');
      });
    }
  }

  Future<void> _handlePaymentReturn() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final order = await PaymentService.handlePaymentReturn(widget.returnUri!);
      print('PaymentSuccessScreen - Received order from handlePaymentReturn: $order');
      
      setState(() {
        _isLoading = false;
        _orderData = order;
      });
    } catch (e) {
      print('PaymentSuccessScreen - Error in handlePaymentReturn: $e');
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    print('Building order item: $item');
    final product = item['product'] ?? {};
    final size = item['size'] ?? {};
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: (product['imageUrls'] != null && product['imageUrls'].isNotEmpty)
                ? Image.network(
                    '$baseUrl${product['imageUrls'][0]}',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading image: $error');
                      return Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported),
                      );
                    },
                  )
                : Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] ?? 'Unknown Product',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Size: ${size['name'] ?? 'N/A'}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${item['quantity']} x ${(item['price'] as num).toStringAsFixed(0)}đ',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${((item['price'] as num) * (item['quantity'] as num)).toStringAsFixed(0)}đ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('Building PaymentSuccessScreen with orderData: $_orderData');
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading 
          ? 'Đang xử lý thanh toán' 
          : _error != null 
            ? 'Thanh toán thất bại'
            : 'Thanh toán thành công'
        ),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                const Text(
                  'Đang xử lý thanh toán...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vui lòng đợi trong giây lát',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ] else if (_error != null) ...[
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 24),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Quay lại'),
                ),
              ] else ...[
                const Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Thanh toán thành công!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 32),
                if (_orderData != null) ...[
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Mã đơn hàng:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '#${_orderData!['orderCode']}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Thông tin đơn hàng',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_orderData!['orderItems'] != null && (_orderData!['orderItems'] as List).isNotEmpty) ...[
                            ...(_orderData!['orderItems'] as List).map((item) => _buildOrderItem(item)).toList(),
                          ] else ...[
                            const Text('Không có thông tin sản phẩm'),
                          ],
                          const Divider(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Tổng tiền:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_orderData!['total'].toStringAsFixed(0)}đ',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/',
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Về trang chủ',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/orders',
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Xem đơn hàng',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const Text(
                    'Không có thông tin đơn hàng',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
} 