import 'package:flutter/material.dart';
import 'text_formatting_service.dart';

/// Service for dynamically sizing text content based on available space
class DynamicTextService {
  /// Creates a widget that intelligently fills available space with key points
  static Widget buildDynamicKeyPoints({
    required String keypoints,
    required TextStyle baseStyle,
    required BoxConstraints constraints,
    int minLines = 3,
    int maxLines = 20,
  }) {
    return LayoutBuilder(
      builder: (context, availableConstraints) {
        // Calculate available height for text
        final availableHeight = availableConstraints.maxHeight;
        
        // Estimate line height based on text style
        final estimatedLineHeight = (baseStyle.fontSize ?? 16) * (baseStyle.height ?? 1.4);
        
        // Calculate how many lines can fit in available space
        final maxPossibleLines = (availableHeight / estimatedLineHeight).floor();
        
        // Use intelligent line count (between min and max)
        final intelligentMaxLines = maxPossibleLines.clamp(minLines, maxLines);
        
        return TextFormattingService.formatKeyPoints(
          keypoints,
          baseStyle,
          maxLines: intelligentMaxLines,
        );
      },
    );
  }
  
  /// Creates a flexible widget that adapts to available space
  static Widget buildAdaptiveContent({
    required String? keypoints,
    required String description,
    required TextStyle baseStyle,
    int minLines = 3,
    int maxLines = 15,
  }) {
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate available height
          final availableHeight = constraints.maxHeight;
          final estimatedLineHeight = (baseStyle.fontSize ?? 16) * (baseStyle.height ?? 1.4);
          final maxPossibleLines = (availableHeight / estimatedLineHeight).floor();
          final intelligentMaxLines = maxPossibleLines.clamp(minLines, maxLines);
          
          if (keypoints?.isNotEmpty == true) {
            return TextFormattingService.formatKeyPoints(
              keypoints!,
              baseStyle,
              maxLines: intelligentMaxLines,
            );
          } else {
            return Text(
              description,
              style: baseStyle,
              maxLines: intelligentMaxLines,
              overflow: TextOverflow.ellipsis,
            );
          }
        },
      ),
    );
  }
}