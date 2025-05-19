import 'dart:convert';
import 'package:fashionmobile/services/network_service.dart';
import 'package:http/http.dart' as http;

class OrderService {
  static const String baseUrl = NetworkService.defaultIp;

  static Future<Map<String, dynamic>> createOrder({
    required int userId,
    required double total,
    required String status,
    required String paymentStatus,
    required String paymentMethod,
    required String receiverName,
    required String receiverEmail,
    required String receiverPhone,
    required String receiverAddress,
    required List<Map<String, dynamic>> orderItems,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/orders'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'total': total,
          'status': status,
          'paymentStatus': paymentStatus,
          'paymentMethod': paymentMethod,
          'receiverName': receiverName,
          'receiverEmail': receiverEmail,
          'receiverPhone': receiverPhone,
          'receiverAddress': receiverAddress,
          'orderItems': orderItems,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        final errorData = jsonDecode(response.body);
        throw Exception('Không thể tạo đơn hàng: ${errorData['message'] ?? response.body}');
      }

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Lỗi tạo đơn hàng: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getUserOrders(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders/user/$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> orders = jsonDecode(response.body);
        return orders.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load orders: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error loading orders: $e');
    }
  }
} 