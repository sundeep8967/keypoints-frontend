import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

void main() {
  runApp(TestApp());
}

class TestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'News App Test',
      home: TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  @override
  _TestScreenState createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  String _selectedCategory = 'All';

  Widget _buildHorizontalCategories() {
    final categories = [
      'All',
      'Technology',
      'Science',
      'Environment',
      'Energy',
      'Lifestyle',
      'Business',
      'Entertainment',
      'Health',
      'Sports',
      'World',
      'Trending'
    ];

    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == _selectedCategory;
          
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = category;
                });
                print('Selected category: $category');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected 
                    ? Colors.white 
                    : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Center(
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.black : Colors.white,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          // Top row with settings
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      print('Settings pressed');
                    },
                    child: const Icon(
                      CupertinoIcons.ellipsis,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Horizontal categories
          _buildHorizontalCategories(),
          // Content area
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Selected Category:',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    _selectedCategory,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Categories are now displayed horizontally at the top!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}