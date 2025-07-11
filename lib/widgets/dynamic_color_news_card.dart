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
        });
      }
    } catch (e) {
      // Keep default color on error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _dominantColor.withOpacity(0.08),
                _dominantColor.withOpacity(0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _dominantColor.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _dominantColor.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: AspectRatio(
                  aspectRatio: 1.6,
                  child: CachedNetworkImage(
                    imageUrl: widget.article.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => Container(
                      color: CupertinoColors.systemGrey6.resolveFrom(context),
                      child: const Center(
                        child: CupertinoActivityIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: CupertinoColors.systemGrey6.resolveFrom(context),
                      child: Center(
                        child: Icon(
                          CupertinoIcons.photo,
                          size: 40,
                          color: CupertinoColors.systemGrey3.resolveFrom(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Content Section
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timestamp
                    Text(
                      _formatTimestamp(widget.article.timestamp),
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.systemGrey.resolveFrom(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Title
                    Text(
                      widget.article.title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.label.resolveFrom(context),
                        height: 1.3,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Description
                    Text(
                      widget.article.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        height: 1.5,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Read More Indicator
                    Row(
                      children: [
                        const Spacer(),
                        Icon(
                          CupertinoIcons.chevron_right,
                          size: 16,
                          color: _dominantColor,
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