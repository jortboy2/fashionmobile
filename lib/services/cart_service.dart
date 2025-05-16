import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CartService {
  static const String _cartKey = 'cart_items';
  static List<Map<String, dynamic>> _cartItems = [];

  // Get all cart items
  static List<Map<String, dynamic>> get cartItems => _cartItems;

  // Initialize cart from storage
  static Future<void> initCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString(_cartKey);
    if (cartJson != null) {
      _cartItems = List<Map<String, dynamic>>.from(json.decode(cartJson));
    } else {
      _cartItems = [];
    }
  }

  // Add item to cart
  static Future<void> addToCart(Map<String, dynamic> product, String size, int quantity) async {
    final existingItemIndex = _cartItems.indexWhere(
      (item) => item['product']['id'] == product['id'] && item['size'] == size,
    );

    if (existingItemIndex != -1) {
      _cartItems[existingItemIndex]['quantity'] += quantity;
    } else {
      _cartItems.add({
        'product': product,
        'size': size,
        'quantity': quantity,
      });
    }

    await _saveCart();
  }

  // Remove item from cart
  static Future<void> removeFromCart(int productId, String size) async {
    _cartItems.removeWhere(
      (item) => item['product']['id'] == productId && item['size'] == size,
    );
    await _saveCart();
  }

  // Update item quantity
  static Future<void> updateQuantity(int productId, String size, int quantity) async {
    final itemIndex = _cartItems.indexWhere(
      (item) => item['product']['id'] == productId && item['size'] == size,
    );

    if (itemIndex != -1) {
      _cartItems[itemIndex]['quantity'] = quantity;
      await _saveCart();
    }
  }

  // Clear cart
  static Future<void> clearCart() async {
    _cartItems.clear();
    await _saveCart();
  }

  // Calculate total price
  static double get totalPrice {
    return _cartItems.fold(0, (sum, item) {
      final price = item['product']['price'] ?? 0;
      final quantity = item['quantity'] ?? 0;
      return sum + (price * quantity);
    });
  }

  // Save cart to storage
  static Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cartKey, json.encode(_cartItems));
  }
} 