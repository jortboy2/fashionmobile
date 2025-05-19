import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:fashionmobile/services/network_service.dart';
import 'package:http/http.dart' as http;
import 'package:fashionmobile/services/auth_service.dart';

class CartService {
  static const String _cartKey = 'cart_items';
  static List<Map<String, dynamic>> _cartItems = [];
  static Map<String, dynamic>? appliedVoucher;
  static double _totalPrice = 0;
  static const String baseUrl = NetworkService.defaultIp;

  // Get all cart items
  static List<Map<String, dynamic>> get cartItems => _cartItems;

  // Get total price
  static double get totalPrice => _totalPrice;

  // Initialize cart from storage
  static Future<void> initCart() async {
    try {
      // Get user ID from AuthService
      if (!AuthService.isLoggedIn || AuthService.currentUser == null) {
        throw Exception('User not logged in');
      }
      
      final userId = AuthService.currentUser!['id'];
      if (userId == null) {
        throw Exception('User ID not found');
      }

      // Make API call to get cart
      final response = await http.get(
        Uri.parse('$baseUrl/api/cart/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final cartData = json.decode(response.body);
        // Update local cart with data from API
        _cartItems = List<Map<String, dynamic>>.from(cartData['items'] ?? []);
        calculateTotal();
      } else {
        throw Exception('Failed to get cart: ${response.body}');
      }
    } catch (e) {
      // If API call fails, try to load from local storage
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString(_cartKey);
      if (cartJson != null) {
        _cartItems = List<Map<String, dynamic>>.from(json.decode(cartJson));
        calculateTotal();
      } else {
        _cartItems = [];
        _totalPrice = 0;
      }
      throw Exception('Error loading cart: $e');
    }
  }

  // Add item to cart
  static Future<void> addToCart(Map<String, dynamic> product, String size, int quantity, int sizeId) async {
    try {
      // Get user ID from AuthService
      if (!AuthService.isLoggedIn || AuthService.currentUser == null) {
        throw Exception('User not logged in');
      }
      
      final userId = AuthService.currentUser!['id'];
      if (userId == null) {
        throw Exception('User ID not found');
      }

      // Make API call with parameters in URL
      final response = await http.post(
        Uri.parse('$baseUrl/api/cart/add?userId=$userId&productId=${product['id']}&sizeId=$sizeId&quantity=$quantity'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        // Update local cart
        final existingItemIndex = _cartItems.indexWhere(
          (item) => item['product']['id'] == product['id'] && item['size'] == size,
        );

        if (existingItemIndex != -1) {
          _cartItems[existingItemIndex]['quantity'] += quantity;
        } else {
          _cartItems.add({
            'product': product,
            'size': size,
            'sizeId': sizeId,
            'quantity': quantity,
          });
        }

        await _saveCart();
        calculateTotal();
      } else {
        throw Exception('Failed to add item to cart: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error adding to cart: $e');
    }
  }

  // Remove item from cart
  static Future<void> removeFromCart(int productId, String size) async {
    _cartItems.removeWhere(
      (item) => item['product']['id'] == productId && item['size'] == size,
    );
    await _saveCart();
    calculateTotal();
  }

  // Update item quantity
  static Future<void> updateQuantity(int productId, String size, int quantity) async {
    final itemIndex = _cartItems.indexWhere(
      (item) => item['product']['id'] == productId && item['size'] == size,
    );

    if (itemIndex != -1) {
      _cartItems[itemIndex]['quantity'] = quantity;
      await _saveCart();
      calculateTotal();
    }
  }

  // Clear cart
  static Future<void> clearCart() async {
    _cartItems.clear();
    _totalPrice = 0;
    appliedVoucher = null;
    await _saveCart();
  }

  // Save cart to storage
  static Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cartKey, json.encode(_cartItems));
  }

  static void applyVoucher(Map<String, dynamic> voucher) {
    appliedVoucher = voucher;
    calculateTotal();
  }

  static void removeVoucher() {
    appliedVoucher = null;
    calculateTotal();
  }

  static void calculateTotal() {
    _totalPrice = _cartItems.fold(0, (sum, item) {
      final price = item['product']['price'] ?? 0;
      final quantity = item['quantity'] ?? 0;
      return sum + (price * quantity);
    });

    // Apply voucher discount if exists
    if (appliedVoucher != null) {
      final discount = appliedVoucher!['discount'] ?? 0;
      _totalPrice = _totalPrice * (1 - discount / 100);
    }
  }
} 