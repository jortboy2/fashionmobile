import 'dart:convert';
import 'package:http/http.dart' as http;
import 'network_service.dart';

class ApiService {
 
  static const String baseUrl = NetworkService.defaultIp;


  // Get all products
  Future<List<dynamic>> getProducts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/products'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load products');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Get product by ID
  Future<Map<String, dynamic>> getProductById(int id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/products/$id'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load product');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Get all categories
  Future<List<dynamic>> getCategories() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/categories'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Register user
  Future<bool> registerUser(String username, String email, String password) async {
    final url = Uri.parse('$baseUrl/api/users/register');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return true;
    } else {
      throw Exception('Đăng ký thất bại: ${response.body}');
    }
  }

  // Login user
  Future<Map<String, dynamic>> loginUser(String username, String password) async {
    final url = Uri.parse('$baseUrl/api/users/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': username,
        'password': password,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Đăng nhập thất bại: ${response.body}');
    }
  }

  Future<List<dynamic>> getProductsByCategory(int categoryId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/products/category/$categoryId'),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to load products');
      }
    } catch (e) {
      throw Exception('Error fetching products: $e');
    }
  }
} 