import 'dart:convert';
import 'package:fashionmobile/services/network_service.dart';
import 'package:http/http.dart' as http;

class SizeService {
  static const String baseUrl = NetworkService.defaultIp;

  static Future<List<Map<String, dynamic>>> getAllSizes() async {
    final response = await http.get(Uri.parse('$baseUrl/api/sizes'));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load sizes');
    }
  }
} 