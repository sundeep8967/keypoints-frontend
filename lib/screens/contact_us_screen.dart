
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'keypointsnews@gmail.com',
      queryParameters: {
        'subject': 'Key Points App Feedback',
      },
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      throw 'Could not launch $emailLaunchUri';
    }
  }

  

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black,
        border: null,
        middle: Text(
          'Contact Us',
          style: TextStyle(
            color: CupertinoColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSection(
              'Get in Touch',
              [
                _buildContactItem(
                  'Email Us',
                  'keypointsnews@gmail.com',
                  CupertinoIcons.mail,
                  () => _launchEmail(),
                ),
                
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6.darkColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildContactItem(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return CupertinoListTile(
      leading: Icon(icon, color: CupertinoColors.systemBlue),
      title: Text(
        title,
        style: const TextStyle(color: CupertinoColors.white),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: CupertinoColors.systemGrey,
          fontSize: 14,
        ),
      ),
      trailing: const Icon(
        CupertinoIcons.chevron_right,
        color: CupertinoColors.systemGrey,
        size: 16,
      ),
      onTap: onTap,
    );
  }
}
