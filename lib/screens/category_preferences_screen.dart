import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';
import '../screens/news_feed_screen.dart';

class CategoryPreferencesScreen extends StatefulWidget {
  const CategoryPreferencesScreen({super.key});

  @override
  State<CategoryPreferencesScreen> createState() => _CategoryPreferencesScreenState();
}

class _CategoryPreferencesScreenState extends State<CategoryPreferencesScreen> {
  final Set<String> _selectedCategories = {};
  
  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'Technology',
      'icon': CupertinoIcons.device_laptop,
      'description': 'Latest tech news, gadgets, and innovations',
      'color': Colors.blue,
    },
    {
      'name': 'Science',
      'icon': CupertinoIcons.lab_flask,
      'description': 'Scientific discoveries and research',
      'color': Colors.green,
    },
    {
      'name': 'Business',
      'icon': CupertinoIcons.briefcase,
      'description': 'Market trends, finance, and economy',
      'color': Colors.orange,
    },
    {
      'name': 'Sports',
      'icon': CupertinoIcons.sportscourt,
      'description': 'Sports news, scores, and highlights',
      'color': Colors.red,
    },
    {
      'name': 'Entertainment',
      'icon': CupertinoIcons.tv,
      'description': 'Movies, music, and celebrity news',
      'color': Colors.purple,
    },
    {
      'name': 'Health',
      'icon': CupertinoIcons.heart,
      'description': 'Health tips, medical news, and wellness',
      'color': Colors.pink,
    },
    {
      'name': 'World',
      'icon': CupertinoIcons.globe,
      'description': 'International news and global events',
      'color': Colors.indigo,
    },
    {
      'name': 'Environment',
      'icon': CupertinoIcons.leaf_arrow_circlepath,
      'description': 'Climate change and environmental news',
      'color': Colors.teal,
    },
    {
      'name': 'Energy',
      'icon': CupertinoIcons.bolt,
      'description': 'Energy sector and renewable resources',
      'color': Colors.yellow,
    },
    {
      'name': 'Lifestyle',
      'icon': CupertinoIcons.person_2,
      'description': 'Fashion, travel, and lifestyle trends',
      'color': Colors.cyan,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              // Header
              const Text(
                'Choose Your Interests',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Select categories you\'re interested in. You can change these later in settings.',
                style: TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Categories grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = _selectedCategories.contains(category['name']);
                    
                    return CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          if (isSelected) {
                            _selectedCategories.remove(category['name']);
                          } else {
                            _selectedCategories.add(category['name']);
                          }
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? category['color'].withOpacity(0.2)
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected 
                                ? category['color']
                                : Colors.white.withOpacity(0.2),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? category['color']
                                      : Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Icon(
                                  category['icon'],
                                  size: 30,
                                  color: isSelected 
                                      ? Colors.white
                                      : category['color'],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                category['name'],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected 
                                      ? category['color']
                                      : Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                category['description'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected 
                                      ? category['color'].withOpacity(0.8)
                                      : CupertinoColors.systemGrey,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isSelected)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Icon(
                                    CupertinoIcons.checkmark_circle_fill,
                                    color: category['color'],
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Selected count and continue button
              Container(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  children: [
                    if (_selectedCategories.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          '${_selectedCategories.length} categories selected',
                          style: const TextStyle(
                            fontSize: 16,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      ),
                    
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton.filled(
                        onPressed: _selectedCategories.isNotEmpty ? _completeSetup : null,
                        child: const Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    CupertinoButton(
                      onPressed: _skipSetup,
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(
                          fontSize: 16,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _completeSetup() async {
    // Save selected categories
    await LocalStorageService.setCategoryPreferences(_selectedCategories.toList());
    
    // Mark setup as completed
    await LocalStorageService.setFirstTimeSetupCompleted(true);
    
    // Navigate to main app
    _navigateToMainApp();
  }
  
  Future<void> _skipSetup() async {
    // Mark setup as completed without saving preferences
    await LocalStorageService.setFirstTimeSetupCompleted(true);
    
    // Navigate to main app
    _navigateToMainApp();
  }
  
  void _navigateToMainApp() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute(
          builder: (context) => const NewsFeedScreen(),
        ),
        (route) => false,
      );
    }
  }
}