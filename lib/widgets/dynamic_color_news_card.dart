import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/news_article.dart';
import '../services/color_extraction_service.dart';

class DynamicColorNewsCard extends StatefulWidget {
  final NewsArticle article;
  final VoidCallback? onTap;

  const DynamicColorNewsCard({
    super.key,
    required this.article,
    this.onTap,
  });

  @override
  State<DynamicColorNewsCard> createState() => _DynamicColorNewsCardState();
}

class _DynamicColorNewsCardState extends State<DynamicColorNewsCard> {
  Color _dominantColor = const Color(0xFF4B5563);
  Color _textColor = Colors.white;
  bool _isColorExtracted = false;

  @override
  void initState() {
    super.initState();
    _extractColor();
  }

  Future<void> _extractColor() async {
    try {
      final dominantColor = await ColorExtractionService.extractDominantColorFromUrl(
        widget.article.imageUrl,
      );
      
      if (mounted) {
        setState(() {
          _dominantColor = dominantColor;
          _textColor = ColorExtractionService.getContrastingTextColor(dominantColor);
          _isColorExtracted = true;
        });
      }
    } catch (e) {
      print('Error extracting color for ${widget.article.title}: $e');
      // Keep default colors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _dominantColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _dominantColor.withOpacity(0.8),
                  _dominantColor,
                ],
              ),
            ),
            child: Stack(
              children: [
                // Background Image with Overlay
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: widget.article.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: _dominantColor.withOpacity(0.3),
                      child: Center(
                        child: CupertinoActivityIndicator(
                          color: _textColor,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: _dominantColor.withOpacity(0.3),
                      child: Center(
                        child: Icon(
                          CupertinoIcons.photo,
                          size: 60,
                          color: _textColor.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Gradient Overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          _dominantColor.withOpacity(0.7),
                          _dominantColor.withOpacity(0.9),
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
                
                // Content
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Color extraction indicator
                      if (_isColorExtracted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _textColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _dominantColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _textColor.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Dynamic Color',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _textColor.withOpacity(0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 12),
                      
                      // Title
                      Text(
                        widget.article.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Description
                      Text(
                        widget.article.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: _textColor.withOpacity(0.9),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Timestamp and Read More
                      Row(
                        children: [
                          Text(
                            _formatTimestamp(widget.article.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: _textColor.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _textColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _textColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Read More',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  CupertinoIcons.arrow_right,
                                  size: 12,
                                  color: _textColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(timestamp);
    }
  }
}