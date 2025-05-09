import 'package:flutter/material.dart';

class CategoryPage extends StatelessWidget {
  const CategoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        centerTitle: true,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 8,
        itemBuilder: (context, index) {
          final categories = [
            {'name': 'T-Shirts', 'icon': Icons.checkroom},
            {'name': 'Pants', 'icon': Icons.accessibility_new},
            {'name': 'Shoes', 'icon': Icons.shopping_bag},
            {'name': 'Accessories', 'icon': Icons.watch},
            {'name': 'Dresses', 'icon': Icons.dry_cleaning},
            {'name': 'Hats', 'icon': Icons.face},
            {'name': 'Bags', 'icon': Icons.shopping_bag_outlined},
            {'name': 'Jewelry', 'icon': Icons.diamond},
          ];

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  categories[index]['icon'] as IconData,
                  size: 40,
                  color: Colors.blue,
                ),
                const SizedBox(height: 8),
                Text(
                  categories[index]['name'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} 