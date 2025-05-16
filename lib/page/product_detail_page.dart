import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({Key? key}) : super(key: key);

  @override
  _ProductDetailPageState createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _product;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    CartService.initCart();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final productId = ModalRoute.of(context)!.settings.arguments as int;
    _loadProduct(productId);
  }

  Future<void> _loadProduct(int id) async {
    try {
      final product = await _apiService.getProductById(id);
      setState(() {
        _product = product;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading product: $e')),
      );
    }
  }

  void _showAddToCartDialog() {
    String selectedSize = '';
    int quantity = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Chọn size và số lượng'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Size Selection
              if (_product!['productSizes'] != null && _product!['productSizes'].isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Size:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: (_product!['productSizes'] as List).map((sizeData) {
                        final sizeId = sizeData['id']['sizeId'];
                        final stock = sizeData['stock'];
                        final size = _getSizeName(sizeId);
                        return ChoiceChip(
                          label: Text('$size (${stock} còn)'),
                          selected: selectedSize == size,
                          onSelected: stock > 0
                              ? (selected) {
                                  if (selected) {
                                    setState(() => selectedSize = size);
                                  }
                                }
                              : null,
                        );
                      }).toList(),
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              // Quantity Selection
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: quantity > 1
                        ? () => setState(() => quantity--)
                        : null,
                  ),
                  Text(
                    quantity.toString(),
                    style: const TextStyle(fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(() => quantity++),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: selectedSize.isEmpty
                  ? null
                  : () async {
                      await CartService.addToCart(_product!, selectedSize, quantity);
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã thêm vào giỏ hàng'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
              child: const Text('Thêm vào giỏ'),
            ),
          ],
        ),
      ),
    );
  }

  String _getSizeName(int sizeId) {
    switch (sizeId) {
      case 1:
        return 'S';
      case 2:
        return 'M';
      case 3:
        return 'L';
      case 4:
        return 'XL';
      default:
        return 'Unknown';
    }
  }

  Widget _buildImageSlider() {
    final images = (_product!['productImages'] as List)
        .where((img) => img is Map && img['imageUrl'] != null && (img['imageUrl'] as String).isNotEmpty)
        .toList();

    if (images.isEmpty) {
      return Container(
        width: double.infinity,
        height: 320,
        color: Colors.grey[300],
        child: const Icon(Icons.image_not_supported, size: 80),
      );
    }

    return CarouselSlider(
      options: CarouselOptions(
        height: 320,
        enableInfiniteScroll: false,
        enlargeCenterPage: true,
        viewportFraction: 1,
      ),
      items: images.map<Widget>((img) {
        return Image.network(
          'http://192.168.1.58:8080${img['imageUrl']}',
          width: double.infinity,
          height: 320,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 320,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, size: 80, color: Colors.red),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_product?['name'] ?? 'Product Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.pushNamed(context, '/cart');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _product == null
              ? const Center(child: Text('Product not found'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImageSlider(),
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _product!['name'] ?? 'No Name',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${_product!['price']?.toString() ?? '0'} VNĐ',
                              style: const TextStyle(
                                fontSize: 22,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _product!['description'] ?? 'No description available',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 18),
                            if (_product!['category'] != null) ...[
                              const Text(
                                'Category',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _product!['category']['name'] ?? 'Uncategorized',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: _product == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Thêm vào giỏ', style: TextStyle(fontSize: 16)),
                      onPressed: _showAddToCartDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      child: const Text('Mua ngay', style: TextStyle(fontSize: 16)),
                      onPressed: () {
                        // TODO: Thêm logic mua ngay ở đây
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chức năng mua ngay đang phát triển!')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 