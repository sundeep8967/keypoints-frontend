import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/reward_points_service.dart';
import '../services/reward_claims_service.dart';
import '../services/fcm_service.dart';

class PointsDisplayWidget extends StatefulWidget {
  final bool showDetailed;
  
  const PointsDisplayWidget({
    super.key,
    this.showDetailed = false,
  });

  @override
  State<PointsDisplayWidget> createState() => _PointsDisplayWidgetState();
}

class _PointsDisplayWidgetState extends State<PointsDisplayWidget> {
  int _points = 0;
  int _todayEarnings = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    try {
      final points = await RewardPointsService.instance.getPoints();
      final todayEarnings = await RewardPointsService.instance.getTodayEarnings();
      
      if (mounted) {
        setState(() {
          _points = points;
          _todayEarnings = todayEarnings;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Handle error silently in production
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CupertinoColors.systemBlue.withOpacity(0.3)),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(CupertinoColors.systemBlue),
          ),
        ),
      );
    }

    if (widget.showDetailed) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              CupertinoColors.systemBlue.withOpacity(0.1),
              CupertinoColors.systemBlue.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CupertinoColors.systemBlue.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.star_fill,
                  color: CupertinoColors.systemBlue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Reward Points',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.systemBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Points',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      _points.toString(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: CupertinoColors.systemBlue,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '+$_todayEarnings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Claim Button
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: _points >= 1000 ? CupertinoColors.systemGreen : CupertinoColors.systemGrey,
                borderRadius: BorderRadius.circular(12),
                onPressed: () => _showClaimDialog(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.money_dollar_circle,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Claim Reward',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Note about minimum points
            Text(
              'Note: Minimum 1000 points required to claim rewards',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Compact display
    return GestureDetector(
      onTap: () {
        // Show points details dialog
        _showPointsDialog(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              CupertinoColors.systemBlue,
              CupertinoColors.systemBlue.darkColor,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemBlue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.star_fill,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              _points.toString(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (_todayEarnings > 0) ...[
              const SizedBox(width: 4),
              Text(
                '+$_todayEarnings',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showPointsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(CupertinoIcons.star_fill, color: CupertinoColors.systemBlue),
            const SizedBox(width: 8),
            const Text('Reward Points'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Total Points', _points.toString()),
            _buildStatRow('Today\'s Earnings', '+$_todayEarnings'),
            _buildStatRow('Estimated Value', RewardPointsService.instance.pointsToCurrency(_points)),
            const SizedBox(height: 16),
            Text(
              'Earn points by viewing and clicking ads!',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showClaimDialog(BuildContext context) {
    String email = '';
    String fullName = '';
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Claim Reward'),
        content: Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              'Enter your details to claim reward:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              placeholder: 'Enter full name',
              keyboardType: TextInputType.name,
              onChanged: (value) {
                fullName = value;
              },
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              placeholder: 'Enter email address',
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) {
                email = value;
              },
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Save'),
            onPressed: () {
              Navigator.pop(context);
              _processClaim(context, email, fullName);
            },
          ),
        ],
      ),
    );
  }

  void _processClaim(BuildContext context, String email, String fullName) async {
    if (fullName.isEmpty || fullName.trim().length < 2) {
      // Show error for invalid name
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Invalid Name'),
          content: const Text('Please enter your full name.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      // Show error for invalid email
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Invalid Email'),
          content: const Text('Please enter a valid email address.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    if (_points < 1000) {
      // Show error for insufficient points
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Insufficient Points'),
          content: const Text('You need at least 1000 points to claim a reward.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    // Show loading
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CupertinoAlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(),
            SizedBox(height: 16),
            Text('Submitting claim...'),
          ],
        ),
      ),
    );

    // Get current FCM token
    final fcmToken = FCMService.getCurrentToken();
    
    // Submit to Supabase
    final success = await UserDataService.submitClaim(
      email: email,
      fullName: fullName,
      pointsClaimed: _points,
      totalRemainingPoints: _points, // Current total points
      fcmToken: fcmToken, // Use actual FCM token if available
    );

    // Link email to existing FCM token if available
    if (success && fcmToken != null) {
      await FCMService.linkEmailToFCMToken(email);
    }

    // Close loading dialog
    Navigator.pop(context);

    if (success) {
      // Show success message
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.check_mark_circled,
                color: CupertinoColors.systemGreen,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text('Claim Submitted'),
            ],
          ),
          content: const Text(
            'Your reward claim has been submitted successfully. You will receive your voucher via email within 24-48 hours.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } else {
      // Show error message
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: const Text(
            'Failed to submit claim. Please check your internet connection and try again.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }
}