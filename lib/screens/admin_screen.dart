import 'package:flutter/cupertino.dart';
import '../services/firebase_service.dart';
import '../services/data_import_service.dart';
import '../models/news_article.dart';
import 'add_news_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isLoading = false;
  String _status = '';
  List<String> _logs = [];

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
    print(message);
  }

  Future<void> _importFromGitHub() async {
    setState(() {
      _isLoading = true;
      _status = 'Importing from GitHub...';
      _logs.clear();
    });

    try {
      _addLog('Starting import from GitHub...');
      
      // Get available files
      final files = await DataImportService.getDataFiles();
      _addLog('Found ${files.length} JSON files');

      if (files.isEmpty) {
        _addLog('No JSON files found. Trying direct URLs...');
        await _tryDirectUrls();
        return;
      }

      int totalImported = 0;
      for (String file in files) {
        _addLog('Processing $file...');
        final articles = await DataImportService.importFromFile(file);
        
        for (NewsArticle article in articles) {
          await FirebaseService.addNews(article);
          totalImported++;
        }
        
        _addLog('Imported ${articles.length} articles from $file');
      }
      
      _addLog('✅ Import completed! Total: $totalImported articles');
      setState(() {
        _status = 'Import completed successfully!';
      });
    } catch (e) {
      _addLog('❌ Error during import: $e');
      setState(() {
        _status = 'Import failed';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _tryDirectUrls() async {
    // Try common file names and paths
    final commonFiles = [
      'data/news.json',
      'data/articles.json',
      'news.json',
      'articles.json',
      'data.json',
      'sample.json',
    ];

    for (String file in commonFiles) {
      try {
        _addLog('Trying direct URL: $file');
        final articles = await DataImportService.importFromFile(file);
        if (articles.isNotEmpty) {
          _addLog('✅ Found data in $file');
          for (NewsArticle article in articles) {
            await FirebaseService.addNews(article);
          }
          _addLog('Imported ${articles.length} articles from $file');
          return;
        }
      } catch (e) {
        _addLog('Failed to load $file: $e');
      }
    }
    
    _addLog('❌ No accessible data files found');
  }

  Future<void> _addSampleData() async {
    setState(() {
      _isLoading = true;
      _status = 'Adding sample data...';
      _logs.clear();
    });

    try {
      final sampleArticles = [
        NewsArticle(
          id: '1',
          title: 'Flutter 3.0 Released with Exciting New Features',
          description: 'Google announces Flutter 3.0 with improved performance, better web support, and enhanced developer tools. This release marks a significant milestone in Flutter\'s evolution with new widgets, improved compilation, and better integration with native platforms.',
          imageUrl: 'https://storage.googleapis.com/cms-storage-bucket/6a07d8a62f4308d2b854.png',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        NewsArticle(
          id: '2',
          title: 'AI Revolution: ChatGPT Transforms Software Development',
          description: 'Artificial Intelligence is reshaping how developers write code, debug applications, and solve complex problems. The integration of AI tools in development workflows is increasing productivity and changing the landscape of software engineering.',
          imageUrl: 'https://images.unsplash.com/photo-1677442136019-21780ecad995?w=800&h=600&fit=crop',
          timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        ),
        NewsArticle(
          id: '3',
          title: 'Mobile App Security: Best Practices for 2024',
          description: 'As mobile applications handle increasingly sensitive data, security has become paramount. Learn about the latest security practices, encryption methods, and vulnerability assessments that every mobile developer should implement.',
          imageUrl: 'https://images.unsplash.com/photo-1563986768609-322da13575f3?w=800&h=600&fit=crop',
          timestamp: DateTime.now().subtract(const Duration(hours: 8)),
        ),
      ];

      for (NewsArticle article in sampleArticles) {
        await FirebaseService.addNews(article);
        _addLog('Added: ${article.title}');
      }

      _addLog('✅ Sample data added successfully!');
      setState(() {
        _status = 'Sample data added!';
      });
    } catch (e) {
      _addLog('❌ Error adding sample data: $e');
      setState(() {
        _status = 'Failed to add sample data';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAllData() async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('Are you sure you want to delete all news articles? This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete All'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _isLoading = true;
        _status = 'Clearing data...';
        _logs.clear();
      });

      try {
        await FirebaseService.clearAllNews();
        _addLog('✅ All data cleared successfully!');
        setState(() {
          _status = 'Data cleared!';
        });
      } catch (e) {
        _addLog('❌ Error clearing data: $e');
        setState(() {
          _status = 'Failed to clear data';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground.withOpacity(0.9),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(
            CupertinoIcons.back,
            color: CupertinoColors.systemBlue,
          ),
        ),
        middle: const Text(
          'Admin Panel',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status
              if (_status.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _status,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Action Buttons
              CupertinoButton.filled(
                onPressed: _isLoading ? null : _importFromGitHub,
                child: _isLoading
                    ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                    : const Text('Import from GitHub'),
              ),
              
              const SizedBox(height: 12),
              
              CupertinoButton(
                color: CupertinoColors.systemGreen,
                onPressed: _isLoading ? null : _addSampleData,
                child: const Text('Add Sample Data'),
              ),
              
              const SizedBox(height: 12),
              
              CupertinoButton(
                color: CupertinoColors.systemBlue,
                onPressed: _isLoading ? null : () async {
                  final result = await Navigator.of(context).push<bool>(
                    CupertinoPageRoute(
                      builder: (context) => const AddNewsScreen(),
                    ),
                  );
                  if (result == true) {
                    _addLog('✅ Manual article added successfully');
                  }
                },
                child: const Text('Add News Manually'),
              ),
              
              const SizedBox(height: 12),
              
              CupertinoButton(
                color: CupertinoColors.systemRed,
                onPressed: _isLoading ? null : _clearAllData,
                child: const Text('Clear All Data'),
              ),

              const SizedBox(height: 24),

              // Logs
              const Text(
                'Logs:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _logs.isEmpty
                      ? const Center(
                          child: Text(
                            'No logs yet',
                            style: TextStyle(
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                _logs[index],
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Courier',
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}