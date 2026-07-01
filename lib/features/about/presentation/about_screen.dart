import 'package:flutter/material.dart';

import 'package:bulwark/core/app_info.dart';
import 'package:bulwark/shared/theme/app_colors.dart';
import 'package:bulwark/shared/theme/app_spacing.dart';

/// About: what Bulwark is, why it's local-first and free, the version, a link to
/// the open-source licenses, and the not-medical-advice statement in full.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(AppInfo.appName, style: text.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppInfo.tagline,
            style: text.titleMedium?.copyWith(color: AppColors.basalt),
          ),
          const SizedBox(height: AppSpacing.lg),

          const _Section(
            title: 'What Bulwark is',
            body: 'Bulwark introduces healthy habits a few at a time, hung off '
                'things you already do — waking, meals, brushing, bed — with a '
                '30-second daily check-in. Habits you keep become stones in a '
                'wall: a maintenance floor the app quietly watches so it never '
                'collapses. The goal is not perfection. The goal is a floor '
                "that doesn't collapse.",
          ),
          const _Section(
            title: 'Free and open',
            body: 'Bulwark is free and open-source software. There are no '
                'accounts, no ads, no tracking, and no subscriptions — the app '
                'is not built to monetize you.',
          ),
          const _Section(
            title: 'Your data stays here',
            body: 'Your data never leaves this device. There are no accounts '
                'and no network access — the Android build ships with no '
                'internet permission at all. Export gives you a copy you own; '
                'nothing is ever uploaded.',
          ),
          const _Section(
            title: 'Not medical advice',
            body: 'Bulwark is habit-tracking with health education, not medical '
                'advice, diagnosis, or treatment. Nothing here is a substitute '
                'for a clinician. For any specific condition, medication, '
                'symptom, or if you are pregnant or managing a health issue, '
                'talk to a qualified professional before changing what you do.',
          ),

          const SizedBox(height: AppSpacing.sm),
          Text('Version ${AppInfo.appVersion}',
              style: text.bodyMedium?.copyWith(color: AppColors.stone)),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            icon: const Icon(Icons.description_outlined),
            label: const Text('Open-source licenses'),
            onPressed: () => showLicensePage(
              context: context,
              applicationName: AppInfo.appName,
              applicationVersion: AppInfo.appVersion,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: text.bodyMedium),
        ],
      ),
    );
  }
}
