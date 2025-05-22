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
      print('=== Creating VNPay Payment ===');
      print('Order Data: ${jsonEncode(orderData)}');
      print('Voucher Code: $voucherCode');
      print('User ID: $userId');
      
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

      print('=== Order Creation Response ===');
      print('Status Code: ${orderResponse.statusCode}');
      print('Response Body: ${orderResponse.body}');

      if (orderResponse.statusCode != 200 && orderResponse.statusCode != 201) {
        final errorData = jsonDecode(orderResponse.body);
        throw Exception('Không thể tạo đơn hàng: ${errorData['message'] ?? orderResponse.body}');
      }

      final order = jsonDecode(orderResponse.body);
      final orderId = order['id'];
      print('Created Order ID: $orderId');

      // Generate unique transaction ID
      final transactionId = 'ORDER_${orderId}_${DateTime.now().millisecondsSinceEpoch}';
      print('Transaction ID: $transactionId');

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

      print('=== VNPay Payment Response ===');
      print('Status Code: ${paymentResponse.statusCode}');
      print('Response Body: ${paymentResponse.body}');

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

      print('Payment URL: $paymentUrl');
      return paymentUrl;
    } catch (e, stackTrace) {
      print('=== Payment Creation Error ===');
      print('Error: $e');
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
    print('=== VNPay Payment Return ===');
    print('Full URI: $returnUri');
    print('Query Parameters: ${returnUri.queryParameters}');

    // Get VNPay response parameters
    final vnpResponseCode = returnUri.queryParameters['vnp_ResponseCode'];
    final vnpTransactionStatus = returnUri.queryParameters['vnp_TransactionStatus'];
    final vnpTxnRef = returnUri.queryParameters['vnp_TxnRef'];
    
    print('VNPay Parameters:');
    print('- Response Code: $vnpResponseCode');
    print('- Transaction Status: $vnpTransactionStatus');
    print('- Transaction Ref: $vnpTxnRef');

    // Call backend API to verify payment
    final apiUrl = Uri.parse('$baseUrl/api/orders/payment/vnpay/return/mobile')
        .replace(queryParameters: {
      'vnp_ResponseCode': vnpResponseCode,
      'vnp_TxnRef': vnpTxnRef,
      'vnp_TransactionStatus': vnpTransactionStatus,
    });
    
    print('Calling API: $apiUrl');
    final response = await http.get(apiUrl);
    print('API Response Status: ${response.statusCode}');
    print('API Response Body: ${response.body}');

    final responseData = jsonDecode(response.body);
    print('Parsed Response: $responseData');

    // Get order ID from response
    final orderId = responseData['data']?['order']?['id'];
    if (orderId != null) {
      // Get full order details
      final orderResponse = await http.get(
        Uri.parse('$baseUrl/api/orders/$orderId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('=== Order Details Response ===');
      print('Status: ${orderResponse.statusCode}');
      print('Body: ${orderResponse.body}');

      if (orderResponse.statusCode == 200) {
        final orderData = jsonDecode(orderResponse.body);
        print('Order Data: $orderData');
        return orderData;
      }
    }

    return responseData;
  }
} 