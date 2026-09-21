import 'package:flutter/material.dart';
import 'package:lnote/services/storage_service.dart';
import 'package:lnote/widgets/dashboard_card_widget.dart';
import 'package:lnote/widgets/github_calendar_widget.dart';

class DesktopWidgetView extends StatelessWidget {
  final StorageService storage;

  const DesktopWidgetView({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dashboard Widget with Day count, Sessions, and IN/OUT buttons
              DashboardCardWidget(
                storage: storage,
                compact: true,
              ),
              const SizedBox(height: 14),

              // GitHub-style Calendar Heat Map Widget
              GitHubCalendarWidget(
                storage: storage,
                weeksToShow: 18,
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
