import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:fashionmobile/services/network_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fashionmobile/services/auth_service.dart';

class PaymentService {
  static const String baseUrl = NetworkService.defaultIp;

  static Future<String> createVNPayPayment({
    required Map<String, dynamic> orderData,
    String? voucherCode,
    int? userId,
  }) async {
    try {
      print('Creating VNPay payment with data: ${jsonEncode(orderData)}');
      
      // 1. Create order first
      final orderResponse = await http.post(
        Uri.parse('$baseUrl/api/orders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'total': orderData['total'],
          'status': 'Đang xử lý',
          'paymentStatus': 'Chờ thanh toán',
          'paymentMethod': orderData['paymentMethod'] ?? 'vnpay',
          'receiverName': orderData['receiverName'],
          'receiverEmail': orderData['receiverEmail'],
          'receiverPhone': orderData['receiverPhone'],
          'receiverAddress': orderData['receiverAddress'],
          'orderItems': orderData['orderItems'],
        }),
      );

      if (orderResponse.statusCode != 200 && orderResponse.statusCode != 201) {
        final errorData = jsonDecode(orderResponse.body);
        throw Exception('Không thể tạo đơn hàng: ${errorData['message'] ?? orderResponse.body}');
      }

      final order = jsonDecode(orderResponse.body);
      final orderId = order['id'];

      // Generate unique transaction ID
      final transactionId = 'ORDER_${orderId}_${DateTime.now().millisecondsSinceEpoch}';

      // 2. Create VNPay payment for the order
      final paymentResponse = await http.post(
        Uri.parse('$baseUrl/api/orders/$orderId/payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': orderData['total'],
          'orderInfo': 'Thanh toan don hang #$orderId',
          'returnUrl': kIsWeb 
              ? '${Uri.base.origin}/payment/vnpay/return'
              : 'fashionmobile://payment/vnpay/return/mobile',
          'transactionId': transactionId,
        }),
      );

      print('VNPay payment response: ${paymentResponse.body}');

      if (paymentResponse.statusCode != 200) {
        final errorData = jsonDecode(paymentResponse.body);
        throw Exception('Không thể tạo thanh toán VNPay: ${errorData['message'] ?? paymentResponse.body}');
      }

      final paymentData = jsonDecode(paymentResponse.body);
      final success = paymentData['success'] as bool? ?? false;
      final paymentUrl = paymentData['data']?['paymentUrl'];

      if (!success || paymentUrl == null) {
        print('Invalid payment data: $paymentData');
        throw Exception('Không nhận được URL thanh toán từ VNPay');
      }

      // 3. Store order data for later use
      final prefs = await SharedPreferences.getInstance();
      final pendingData = {
        'orderData': order,
        'voucherCode': voucherCode,
        'userId': userId,
        'paymentUrl': paymentUrl,
        'orderId': orderId,
        'transactionId': transactionId,
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      print('Storing pending order data: ${jsonEncode(pendingData)}');
      await prefs.setString('pendingOrder', jsonEncode(pendingData));

      return paymentUrl;
    } catch (e, stackTrace) {
      print('Error creating VNPay payment: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Lỗi tạo thanh toán VNPay: $e');
    }
  }

  static Future<void> launchPaymentUrl(String url) async {
    try {
      print('Launching payment URL: $url');
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Không thể mở URL thanh toán');
      }
    } catch (e, stackTrace) {
      print('Error launching payment URL: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Lỗi mở trang thanh toán: $e');
    }
  }

  static Future<Map<String, dynamic>> handlePaymentReturn(Uri returnUri) async {
    try {
      print('=== VNPay Payment Return Debug ===');
      print('Full return URI: $returnUri');
      print('All query parameters: ${returnUri.queryParameters}');
      
      final prefs = await SharedPreferences.getInstance();
      final pendingOrderJson = prefs.getString('pendingOrder');
      
      if (pendingOrderJson == null) {
        print('Error: No pending order found in storage');
        throw Exception('Không tìm thấy thông tin đơn hàng đang chờ xử lý');
      }

      final pendingOrder = jsonDecode(pendingOrderJson);
      print('Pending order data: ${jsonEncode(pendingOrder)}');

      // Get VNPay response parameters
      final vnpResponseCode = returnUri.queryParameters['vnp_ResponseCode'];
      final vnpTransactionStatus = returnUri.queryParameters['vnp_TransactionStatus'];
      final vnpTxnRef = returnUri.queryParameters['vnp_TxnRef'];
      
      print('VNPay Parameters:');
      print('- Response Code: $vnpResponseCode');
      print('- Transaction Status: $vnpTransactionStatus');
      print('- Transaction Ref: $vnpTxnRef');

      // Validate required parameters
      if (vnpResponseCode == null || vnpTransactionStatus == null || vnpTxnRef == null) {
        print('Error: Missing required VNPay parameters');
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
      final response = await http.get(apiUrl);
      print('Backend response status: ${response.statusCode}');
      print('Backend response body: ${response.body}');

      final responseData = jsonDecode(response.body);
      print('Parsed response data: $responseData');

      // Clear pending order data
      await prefs.remove('pendingOrder');

      // Get order ID from response
      final orderId = responseData['data']?['orderId'] ?? pendingOrder['orderId'];
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
        return orderData;
      } else {
        print('Error getting order details: ${orderResponse.body}');
        // Return pending order data if can't get from API
        return pendingOrder['orderData'];
      }
    } catch (e, stackTrace) {
      print('=== Payment Error ===');
      print('Error message: $e');
      print('Stack trace: $stackTrace');
      // Return pending order data even if there's an error
      final prefs = await SharedPreferences.getInstance();
      final pendingOrderJson = prefs.getString('pendingOrder');
      if (pendingOrderJson != null) {
        final pendingOrder = jsonDecode(pendingOrderJson);
        return pendingOrder['orderData'];
      }
      throw Exception('Lỗi xử lý kết quả thanh toán: $e');
    }
  }
} 