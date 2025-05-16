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
          'receiverName': receiverName,
          'receiverEmail': receiverEmail,
          'receiverPhone': receiverPhone,
          'receiverAddress': receiverAddress,
          'orderItems': orderItems,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create order: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating order: $e');
    }
  }
} 