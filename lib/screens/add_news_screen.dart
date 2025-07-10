import 'package:flutter/cupertino.dart';
import '../models/news_article.dart';
import '../services/firebase_service.dart';

class AddNewsScreen extends StatefulWidget {
  const AddNewsScreen({super.key});

  @override
  State<AddNewsScreen> createState() => _AddNewsScreenState();
}

class _AddNewsScreenState extends State<AddNewsScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveArticle() async {
    if (_titleController.text.trim().isEmpty || 
        _descriptionController.text.trim().isEmpty) {
      _showAlert('Error', 'Please fill in title and description');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final article = NewsArticle(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: _imageUrlController.text.trim().isEmpty 
            ? 'https://via.placeholder.com/800x600/E0E0E0/808080?text=No+Image'
            : _imageUrlController.text.trim(),
        timestamp: DateTime.now(),
      );

      await FirebaseService.addNews(article);
      
      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      _showAlert('Error', 'Failed to save article: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAlert(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
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
          child: const Text('Cancel'),
        ),
        middle: const Text(
          'Add News',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _saveArticle,
          child: _isLoading
              ? const CupertinoActivityIndicator()
              : const Text('Save'),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              const Text(
                'Title',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _titleController,
                placeholder: 'Enter news title...',
                maxLines: 2,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Description
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _descriptionController,
                placeholder: 'Enter news description...',
                maxLines: 8,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Image URL
              const Text(
                'Image URL (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _imageUrlController,
                placeholder: 'https://example.com/image.jpg',
                keyboardType: TextInputType.url,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Save Button
              CupertinoButton.filled(
                onPressed: _isLoading ? null : _saveArticle,
                child: _isLoading
                    ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                    : const Text('Save Article'),
              ),
              
              const SizedBox(height: 20),
              
              // Sample URLs for testing
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sample Image URLs:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSampleUrl('Tech News', 'https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=800&h=600&fit=crop'),
                    _buildSampleUrl('Business', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&h=600&fit=crop'),
                    _buildSampleUrl('Science', 'https://images.unsplash.com/photo-1532094349884-543bc11b234d?w=800&h=600&fit=crop'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSampleUrl(String label, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          _imageUrlController.text = url;
        },
        child: Row(
          children: [
            Text(
              '$label: ',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.systemBlue,
              ),
            ),
            Expanded(
              child: Text(
                url,
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}