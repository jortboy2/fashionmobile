import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:fashionmobile/services/network_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
          'status': 'Chờ xác nhận',
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

      // 2. Create VNPay payment for the order
      final paymentResponse = await http.post(
        Uri.parse('$baseUrl/api/orders/$orderId/payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': orderData['total'],
          'orderInfo': 'Thanh toan don hang #$orderId',
          'returnUrl': kIsWeb 
              ? '${Uri.base.origin}/payment/vnpay/return/web'  // Web return URL
              : 'fashionmobile://payment/vnpay/return/mobile', // Mobile return URL
        }),
      );

      print('VNPay payment response: ${paymentResponse.body}');

      if (paymentResponse.statusCode != 200) {
        final errorData = jsonDecode(paymentResponse.body);
        throw Exception('Không thể tạo thanh toán VNPay: ${errorData['message'] ?? paymentResponse.body}');
      }

      final paymentData = jsonDecode(paymentResponse.body);
      if (paymentData['paymentUrl'] == null) {
        throw Exception('Không nhận được URL thanh toán từ VNPay');
      }

      // 3. Store order data and voucher info for later use
      final prefs = await SharedPreferences.getInstance();
      final pendingData = {
        'orderData': order,
        'voucherCode': voucherCode,
        'userId': userId,
        'paymentUrl': paymentData['paymentUrl'],
        'orderId': orderId,
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      print('Storing pending order data: ${jsonEncode(pendingData)}');
      await prefs.setString('pendingOrder', jsonEncode(pendingData));

      return paymentData['paymentUrl'];
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
      print('Handling payment return with URI: $returnUri');
      
      final prefs = await SharedPreferences.getInstance();
      final pendingOrderJson = prefs.getString('pendingOrder');
      
      if (pendingOrderJson == null) {
        throw Exception('Không tìm thấy thông tin đơn hàng đang chờ xử lý');
      }

      final pendingOrder = jsonDecode(pendingOrderJson);
      print('Retrieved pending order data: ${jsonEncode(pendingOrder)}');

      // Check payment status from VNPay
      final vnpResponseCode = returnUri.queryParameters['vnp_ResponseCode'];
      final vnpTransactionNo = returnUri.queryParameters['vnp_TransactionNo'];
      final vnpOrderInfo = returnUri.queryParameters['vnp_OrderInfo'];
      
      print('VNPay response code: $vnpResponseCode');
      print('VNPay transaction no: $vnpTransactionNo');
      print('VNPay order info: $vnpOrderInfo');

      if (vnpResponseCode != '00') {
        throw Exception('Thanh toán không thành công. Mã lỗi: $vnpResponseCode');
      }

      // Update order status after successful payment
      final orderId = pendingOrder['orderId'];
      final updateResponse = await http.put(
        Uri.parse('$baseUrl/api/orders/$orderId/status?status=Đã thanh toán'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'paymentStatus': 'Đã thanh toán',
          'transactionNo': vnpTransactionNo,
        }),
      );

      print('Order update response: ${updateResponse.body}');

      if (updateResponse.statusCode != 200) {
        final errorData = jsonDecode(updateResponse.body);
        throw Exception('Không thể cập nhật trạng thái đơn hàng: ${errorData['message'] ?? updateResponse.body}');
      }

      final order = jsonDecode(updateResponse.body);

      // Clear pending order data
      await prefs.remove('pendingOrder');
      print('Cleared pending order data');

      return order;
    } catch (e, stackTrace) {
      print('Error handling payment return: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Lỗi xử lý kết quả thanh toán: $e');
    }
  }
} 