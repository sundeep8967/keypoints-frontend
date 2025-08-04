import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/news_article.dart';
import '../services/text_formatting_service.dart';
import '../services/dynamic_text_service.dart';
import '../services/url_launcher_service.dart';

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
      // Simple color generation based on article title hash
      final hash = widget.article.title.hashCode;
      final colors = [
        const Color(0xFF6366F1), // Indigo
        const Color(0xFF8B5CF6), // Violet
        const Color(0xFF06B6D4), // Cyan
        const Color(0xFF10B981), // Emerald
        const Color(0xFFF59E0B), // Amber
        const Color(0xFFEF4444), // Red
        const Color(0xFFEC4899), // Pink
        const Color(0xFF84CC16), // Lime
      ];
      
      final selectedColor = colors[hash.abs() % colors.length];
      
      if (mounted) {
        setState(() {
          _dominantColor = selectedColor;
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
                _dominantColor.withValues(alpha: 0.08),
                _dominantColor.withValues(alpha: 0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _dominantColor.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _dominantColor.withValues(alpha: 0.15),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1.6,
                    child: CachedNetworkImage(
                      imageUrl: widget.article.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      // Optimized settings for faster loading
                      fadeInDuration: const Duration(milliseconds: 150),
                      fadeOutDuration: const Duration(milliseconds: 100),
                      memCacheWidth: 1600, // CRITICAL FIX: 4x larger memory cache
                      memCacheHeight: 1200, // CRITICAL FIX: 4x larger memory cache
                      placeholder: (context, url) => Container(
                        color: CupertinoColors.systemGrey6.resolveFrom(context),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CupertinoActivityIndicator(),
                          ),
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
              ),
              
              // Content Section
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title (removed timestamp)
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
                    
                    // Intelligently sized content based on available space
                    Expanded(
                      child: DynamicTextService.buildAdaptiveContent(
                        keypoints: widget.article.keypoints,
                        description: widget.article.description,
                        baseStyle: TextStyle(
                          fontSize: 16,
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          height: 1.4, // Compact line spacing for more content
                          letterSpacing: 0.1,
                        ),
                        minLines: 3,
                        maxLines: 8, // Allow more content in available space
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Read More Indicator with clickable area
                    GestureDetector(
                      onTap: () {
                        if (widget.article.sourceUrl != null && widget.article.sourceUrl!.isNotEmpty) {
                          UrlLauncherService.showLaunchConfirmation(
                            context, 
                            widget.article.sourceUrl, 
                            widget.article.title
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: _dominantColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _dominantColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Read Full Article',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _dominantColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              CupertinoIcons.square_arrow_up,
                              size: 14,
                              color: _dominantColor,
                            ),
                          ],
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