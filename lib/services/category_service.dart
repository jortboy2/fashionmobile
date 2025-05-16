import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/category.dart';
import 'network_service.dart';

class CategoryService {
  static const String baseUrl = NetworkService.defaultIp;

  static Future<List<Category>> getCategories() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/categories'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Category.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (e) {
      throw Exception('Error fetching categories: $e');
    }
  }
} 