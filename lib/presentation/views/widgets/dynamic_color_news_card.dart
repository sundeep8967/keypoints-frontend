import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../domain/entities/news_article_entity.dart';
import '../../../data/services/dynamic_text_service.dart';
import '../../../data/services/url_launcher_service.dart';
import '../../../data/services/read_articles_service.dart';
import '../../../core/utils/app_logger.dart';

class DynamicColorNewsCard extends StatefulWidget {
  final NewsArticleEntity article;
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
        onPressed: () {
          // Mark as read when user taps the card
          ReadArticlesService.markAsRead(widget.article.id);
          AppLogger.log('Card tap: marked as read ${widget.article.id}');
          widget.onTap?.call();
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _dominantColor.withValues(alpha: 0.12),
                _dominantColor.withValues(alpha: 0.18),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _dominantColor.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _dominantColor.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, 12),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Image Section with overlay
              Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 1.6,
                        child: CachedNetworkImage(
                          imageUrl: widget.article.imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          fadeInDuration: const Duration(milliseconds: 200),
                          fadeOutDuration: const Duration(milliseconds: 150),
                          memCacheWidth: 1600,
                          memCacheHeight: 1200,
                          placeholder: (context, url) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  _dominantColor.withValues(alpha: 0.2),
                                  _dominantColor.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CupertinoActivityIndicator(),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  _dominantColor.withValues(alpha: 0.2),
                                  _dominantColor.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                CupertinoIcons.photo,
                                size: 48,
                                color: _dominantColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Category badge overlay
                  Positioned(
                    top: 28,
                    left: 28,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: _dominantColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.article.effectiveCategory.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _dominantColor,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // Enhanced Content Section
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enhanced Title
                    Text(
                      widget.article.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.label.resolveFrom(context),
                        height: 1.3,
                        letterSpacing: -0.3,
                      ),
                    ),
                    
                    const SizedBox(height: 14),
                    
                    // Enhanced content
                    DynamicTextService.buildAdaptiveContent(
                      keypoints: widget.article.description,
                      description: widget.article.description,
                      baseStyle: TextStyle(
                        fontSize: 15,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        height: 1.5,
                        letterSpacing: 0.15,
                      ),
                      minLines: 3,
                      maxLines: 8,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Modern Read More Button
                    GestureDetector(
                      onTap: () async {
                        await ReadArticlesService.markAsRead(widget.article.id);
                        AppLogger.log('Read Full Article: marked as read ${widget.article.id}');
                        if (widget.article.sourceUrl != null && widget.article.sourceUrl!.isNotEmpty) {
                          UrlLauncherService.showLaunchConfirmation(
                            context, 
                            widget.article.sourceUrl, 
                            widget.article.title
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _dominantColor,
                              Color.lerp(_dominantColor, Colors.black, 0.2)!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _dominantColor.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Read Full Article',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              CupertinoIcons.arrow_up_right_circle_fill,
                              size: 18,
                              color: Colors.white,
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
}