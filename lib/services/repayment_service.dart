import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'network_service.dart';
import '../page/payment_webview.dart';
import '../page/payment_success_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class RepaymentService {
  static const String baseUrl = NetworkService.defaultIp;

  static Future<void> handleRepayment(BuildContext context, Map<String, dynamic> order) async {
    try {
      // Check if order is already paid
      if (order['paymentStatus']?.toLowerCase() == 'đã thanh toán') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đơn hàng này đã được thanh toán!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Generate new transaction ID with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newTransactionId = 'ORDER_${order['id']}_RETRY_$timestamp';

      // Get VNPay payment URL with new transaction ID
      final response = await http.post(
        Uri.parse('$baseUrl/api/orders/${order['id']}/retry-payment'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'transactionId': newTransactionId,
          'returnUrl': kIsWeb 
              ? '${Uri.base.origin}/payment/vnpay/return'
              : 'fashionmobile://payment/vnpay/return/mobile',
        }),
      );

      // Hide loading indicator
      Navigator.pop(context);

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Không thể tạo lại thanh toán');
      }

      final paymentData = jsonDecode(response.body);
      if (paymentData['paymentUrl'] == null) {
        throw Exception('Không nhận được URL thanh toán');
      }

      // Save order to local storage with the same key as PaymentService
      final prefs = await SharedPreferences.getInstance();
      final pendingData = {
        'orderData': order,
        'paymentUrl': paymentData['paymentUrl'],
        'orderId': order['id'],
        'transactionId': newTransactionId,
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      print('Storing pending order data: ${jsonEncode(pendingData)}');
      await prefs.setString('pendingOrder', jsonEncode(pendingData));

      // Navigate to PaymentWebView
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentWebView(
              paymentUrl: paymentData['paymentUrl'],
              onPaymentComplete: (response) async {
                try {
                  print('=== VNPay Payment Return Debug ===');
                  print('Payment response: $response');

                  // Get VNPay response parameters
                  final vnpResponseCode = response['vnp_ResponseCode'];
                  final vnpTransactionStatus = response['vnp_TransactionStatus'];
                  final vnpTxnRef = response['vnp_TxnRef'];
                  
                  print('VNPay Parameters:');
                  print('- Response Code: $vnpResponseCode');
                  print('- Transaction Status: $vnpTransactionStatus');
                  print('- Transaction Ref: $vnpTxnRef');

                  // Validate required parameters
                  if (vnpResponseCode == null || vnpTransactionStatus == null || vnpTxnRef == null) {
                    throw Exception('Thiếu thông tin thanh toán từ VNPay');
                  }

                  // Call backend API to verify payment
                  final apiUrl = Uri.parse('$baseUrl/api/orders/payment/vnpay/return/mobile')
                      .replace(queryParameters: {
                    'vnp_ResponseCode': vnpResponseCode,
                    'vnp_TxnRef': vnpTxnRef,
                    'vnp_TransactionStatus': vnpTransactionStatus,
                  });
                  
                  print('Calling backend API: $apiUrl');
                  final verifyResponse = await http.get(apiUrl);
                  print('Backend response status: ${verifyResponse.statusCode}');
                  print('Backend response body: ${verifyResponse.body}');

                  final responseData = jsonDecode(verifyResponse.body);
                  print('Parsed response data: $responseData');

                  // Get order ID from response
                  final orderId = responseData['data']?['orderId'] ?? order['id'];
                  if (orderId == null) {
                    throw Exception('Không tìm thấy ID đơn hàng');
                  }

                  // Get full order details
                  final orderResponse = await http.get(
                    Uri.parse('$baseUrl/api/orders/$orderId'),
                    headers: {
                      'Content-Type': 'application/json',
                    },
                  );
                  
                  print('Order details response status: ${orderResponse.statusCode}');
                  print('Order details response body: ${orderResponse.body}');

                  if (orderResponse.statusCode == 200) {
                    final orderData = jsonDecode(orderResponse.body);
                    print('Retrieved order details: $orderData');
                    
                    // Payment successful
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentSuccessScreen(
                          orderData: orderData,
                        ),
                      ),
                    );
                  } else {
                    print('Error getting order details: ${orderResponse.body}');
                    // Return to order details with pending data
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentSuccessScreen(
                          orderData: order,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  print('=== Payment Error ===');
                  print('Error message: $e');
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  Navigator.pop(context);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      // Hide loading indicator if it's still showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 