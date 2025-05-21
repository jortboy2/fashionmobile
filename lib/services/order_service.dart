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

      return _parseOrderResponse(jsonDecode(response.body));
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
        return orders.map((order) => _parseOrderResponse(order)).toList();
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Không thể tải đơn hàng: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi tải đơn hàng: $e');
    }
  }

  static Future<Map<String, dynamic>> getOrderDetails(int orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders/$orderId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return _parseOrderResponse(jsonDecode(response.body));
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Không thể tải chi tiết đơn hàng: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi tải chi tiết đơn hàng: $e');
    }
  }

  static Future<Map<String, dynamic>> updateOrderStatus(int orderId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/orders/$orderId/status'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        return _parseOrderResponse(jsonDecode(response.body));
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Không thể cập nhật trạng thái đơn hàng: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi cập nhật trạng thái đơn hàng: $e');
    }
  }

  static Future<Map<String, dynamic>> cancelOrder(int orderId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/orders/$orderId/cancel'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return _parseOrderResponse(jsonDecode(response.body));
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Không thể hủy đơn hàng: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi hủy đơn hàng: $e');
    }
  }

  // Helper method to parse order response and ensure consistent data structure
  static Map<String, dynamic> _parseOrderResponse(Map<String, dynamic> order) {
    // Ensure all required fields are present
    final parsedOrder = {
      'id': order['id'],
      'userId': order['userId'],
      'total': order['total']?.toDouble() ?? 0.0,
      'status': order['status'] ?? 'Chờ xác nhận',
      'paymentStatus': order['paymentStatus'] ?? 'Chờ thanh toán',
      'createdAt': order['createdAt'],
      'updatedAt': order['updatedAt'],
      'expiredAt': order['expiredAt'],
      'receiverName': order['receiverName'],
      'receiverEmail': order['receiverEmail'],
      'receiverPhone': order['receiverPhone'],
      'receiverAddress': order['receiverAddress'],
      'orderCode': order['orderCode'],
      'paymentMethod': order['paymentMethod'],
      'orderItems': (order['orderItems'] as List?)?.map((item) {
        final product = item['product'] ?? {};
        final size = item['size'] ?? {};
        return {
          'id': item['id'],
          'orderId': item['orderId'],
          'productId': item['productId'],
          'sizeId': item['sizeId'],
          'quantity': item['quantity'],
          'price': item['price']?.toDouble() ?? 0.0,
          'product': {
            'id': product['id'],
            'name': product['name'] ?? 'Không có tên',
            'description': product['description'],
            'price': product['price']?.toDouble() ?? 0.0,
            'imageUrls': product['imageUrls'] ?? [],
            'productImages': product['productImages'] ?? [],
          },
          'size': {
            'id': size['id'],
            'name': size['name'] ?? 'Không có size',
          },
        };
      }).toList() ?? [],
    };

    return parsedOrder;
  }
} 