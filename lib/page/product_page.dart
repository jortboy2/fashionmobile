import 'package:fashionmobile/services/network_service.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/category.dart';
import '../services/cart_service.dart';

class ProductPage extends StatefulWidget {
  final int? categoryId;

  const ProductPage({
    Key? key,
    this.categoryId,
  }) : super(key: key);

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final ApiService _apiService = ApiService();
  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];
  bool _isLoading = true;
  List<Category> _categories = [];
  Category? _selectedCategory;
  RangeValues _priceRange = const RangeValues(0, 10000000);
  String _sortBy = 'name'; // 'name', 'price_asc', 'price_desc'
  static const String baseUrl = NetworkService.defaultIp;

  @override
  void initState() {
    super.initState();
    _loadData();

    CartService.initCart();
  }

  Future<void> _loadData() async {
    try {
      final categories = await _apiService.getCategories();
      List<dynamic> products;
      if (widget.categoryId == null) {
        products = await _apiService.getProducts();
      } else {
        products = await _apiService.getProductsByCategory(widget.categoryId!);
      }

      setState(() {
        _categories = categories.map((c) => Category.fromJson(c)).toList();
        _selectedCategory = (widget.categoryId != null)
            ? _categories.firstWhere(
                (c) => c.id == widget.categoryId,
                orElse: () => Category(id: -1, name: 'Không xác định'),
              )
            : null;
        _products = products;
        _filteredProducts = products;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  void _applyFilters() {
  setState(() {
    _filteredProducts = _products.where((product) {
      // Category filter
      if (_selectedCategory != null) {
        final productCategory = product['category'];
        final productCategoryId = productCategory != null ? productCategory['id'] : null;
        if (productCategoryId == null || productCategoryId != _selectedCategory!.id) {
          return false;
        }
      }

      // Price range filter
      final price = product['price'] ?? 0;
      if (price < _priceRange.start || price > _priceRange.end) {
        return false;
      }

      return true;
    }).toList();

    // Sorting
    _filteredProducts.sort((a, b) {
      switch (_sortBy) {
        case 'name':
          return (a['name'] ?? '').compareTo(b['name'] ?? '');
        case 'price_asc':
          return ((a['price'] ?? 0) as num)
              .compareTo((b['price'] ?? 0) as num);
        case 'price_desc':
          return ((b['price'] ?? 0) as num)
              .compareTo((a['price'] ?? 0) as num);
        default:
          return 0;
      }
    });
  });
}

  void _showAddToCartDialog(Map<String, dynamic> product) {
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
              if (product['productSizes'] != null &&
                  product['productSizes'].isNotEmpty)
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
                      children:
                          (product['productSizes'] as List).map((sizeData) {
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
                    onPressed:
                        quantity > 1 ? () => setState(() => quantity--) : null,
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
                      // Tìm sizeId từ productSizes
                      final sizeData = (product['productSizes'] as List).firstWhere(
                        (size) => _getSizeName(size['id']['sizeId']) == selectedSize,
                      );
                      final sizeId = sizeData['id']['sizeId'];
                      
                      await CartService.addToCart(
                          product, selectedSize, quantity, sizeId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        centerTitle: true,
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
          : Column(
              children: [
                // Filter Section
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Categories
                      const Text(
                        'Danh mục',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            final isSelected =
                                _selectedCategory?.id == category.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(category.name),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedCategory =
                                        selected ? category : null;
                                    _applyFilters();
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Price Range
                      const Text(
                        'Khoảng giá',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_priceRange.start.round()} VNĐ',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '${_priceRange.end.round()} VNĐ',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      RangeSlider(
                        values: _priceRange,
                        min: 0,
                        max: 10000000,
                        divisions: 100,
                        labels: RangeLabels(
                          '${_priceRange.start.round()} VNĐ',
                          '${_priceRange.end.round()} VNĐ',
                        ),
                        onChanged: (values) {
                          setState(() {
                            _priceRange = values;
                          });
                        },
                        onChangeEnd: (values) {
                          setState(() {
                            _priceRange = values;
                            _applyFilters();
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Sort Options
                      const Text(
                        'Sắp xếp theo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Tên A-Z'),
                              selected: _sortBy == 'name',
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _sortBy = 'name';
                                    _applyFilters();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Giá tăng dần'),
                              selected: _sortBy == 'price_asc',
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _sortBy = 'price_asc';
                                    _applyFilters();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Giá giảm dần'),
                              selected: _sortBy == 'price_desc',
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _sortBy = 'price_desc';
                                    _applyFilters();
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Products Grid
                Expanded(
                  child: _filteredProducts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Không tìm thấy sản phẩm phù hợp',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Vui lòng thử lại với bộ lọc khác',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/product-detail',
                                  arguments: product['id'],
                                );
                              },
                              child: Card(
                                elevation: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child:
                                          (product['productImages'] != null &&
                                                  product['productImages']
                                                      is List &&
                                                  product['productImages']
                                                      .isNotEmpty &&
                                                  product['productImages'][0]
                                                      is Map &&
                                                  product['productImages'][0]
                                                          ['imageUrl'] !=
                                                      null &&
                                                  (product['productImages']
                                                              [0]['imageUrl']
                                                          as String)
                                                      .isNotEmpty)
                                              ? Image.network(
                                                  '$baseUrl${product['productImages'][0]['imageUrl']}',
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                )
                                              : Container(
                                                  color: Colors.grey[300],
                                                  child: const Icon(Icons
                                                      .image_not_supported),
                                                ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product['name'] ?? 'No Name',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${product['price']?.toString() ?? '0'} VNĐ',
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              icon: const Icon(
                                                  Icons.shopping_cart),
                                              label: const Text('Thêm vào giỏ'),
                                              onPressed: () =>
                                                  _showAddToCartDialog(product),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue,
                                                foregroundColor: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
