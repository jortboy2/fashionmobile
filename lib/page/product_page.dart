import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/category.dart';

class ProductPage extends StatefulWidget {
  final int categoryId;

  const ProductPage({
    Key? key,
    required this.categoryId,
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final categories = await _apiService.getCategories();
      final products = await _apiService.getProductsByCategory(widget.categoryId);
      
      setState(() {
        _categories = categories.map((c) => Category.fromJson(c)).toList();
        _selectedCategory = _categories.firstWhere((c) => c.id == widget.categoryId);
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
          if (productCategory == null || 
              productCategory['id'] == null || 
              productCategory['id'] != _selectedCategory!.id) {
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

      // Apply sorting
      _filteredProducts.sort((a, b) {
        switch (_sortBy) {
          case 'name':
            return (a['name'] ?? '').compareTo(b['name'] ?? '');
          case 'price_asc':
            return ((a['price'] ?? 0) as num).compareTo((b['price'] ?? 0) as num);
          case 'price_desc':
            return ((b['price'] ?? 0) as num).compareTo((a['price'] ?? 0) as num);
          default:
            return 0;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredProducts.isEmpty
              ? const Center(child: Text('No products found'))
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
                                final isSelected = _selectedCategory?.id == category.id;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(category.name),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedCategory = selected ? category : null;
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
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                                    child: (product['productImages'] != null &&
                                            product['productImages'] is List &&
                                            product['productImages'].isNotEmpty &&
                                            product['productImages'][0] is Map &&
                                            product['productImages'][0]['imageUrl'] != null &&
                                            (product['productImages'][0]['imageUrl'] as String).isNotEmpty)
                                        ? Image.network(
                                            'http://192.168.1.58:8080${product['productImages'][0]['imageUrl']}',
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                          )
                                        : Container(
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.image_not_supported),
                                          ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
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