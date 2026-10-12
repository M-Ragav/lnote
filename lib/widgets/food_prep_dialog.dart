import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/food_item.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// Floating checklist dialog for tomorrow's food preparation
class FoodPrepDialog extends StatefulWidget {
  final StorageService storage;

  const FoodPrepDialog({super.key, required this.storage});

  /// Static helper to display the dialog
  static Future<void> show(BuildContext context, StorageService storage) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => FoodPrepDialog(storage: storage),
    );
  }

  @override
  State<FoodPrepDialog> createState() => _FoodPrepDialogState();
}

class _FoodPrepDialogState extends State<FoodPrepDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowDayName = DateFormat('EEEE').format(tomorrow);
    final tomorrowDateStr = DateFormat('MMM d').format(tomorrow);
    final tomorrowFoods = widget.storage.getTomorrowFoods();

    final totalCount = tomorrowFoods.length;
    final checkedCount = tomorrowFoods
        .where((f) => widget.storage.isTomorrowFoodChecked(f.id))
        .length;
    final progress = totalCount > 0 ? (checkedCount / totalCount) : 0.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outline.withAlpha(50),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(120),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Header ───
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentTeal.withAlpha(30),
                    AppTheme.accentCyan.withAlpha(15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withAlpha(35),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentTeal.withAlpha(80),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.checklist_rtl_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            Text(
                              'Food Preparation',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentTeal.withAlpha(35),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tomorrowDayName,
                                style: const TextStyle(
                                  color: AppTheme.accentTeal,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Foods required for tomorrow ($tomorrowDateStr)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(160),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    splashRadius: 20,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ─── Progress bar ───
            if (totalCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor:
                              theme.colorScheme.outline.withAlpha(40),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.accentTeal,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$checkedCount / $totalCount prepared',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: checkedCount == totalCount
                            ? AppTheme.accentTeal
                            : theme.colorScheme.onSurface.withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),

            // ─── Food List ───
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: tomorrowFoods.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 36,
                          horizontal: 24,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.restaurant_outlined,
                              size: 48,
                              color: theme.colorScheme.onSurface.withAlpha(80),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No Foods Scheduled for $tomorrowDayName',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add your breakfast, lunch, snack, or dinner in the Food tab with $tomorrowDayName enabled.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    theme.colorScheme.onSurface.withAlpha(140),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shrinkWrap: true,
                        itemCount: tomorrowFoods.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final food = tomorrowFoods[index];
                          final isChecked =
                              widget.storage.isTomorrowFoodChecked(food.id);
                          return _buildFoodCheckTile(theme, food, isChecked);
                        },
                      ),
              ),
            ),

            // ─── Actions: Temporary Skip & Skip & Done ───
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withAlpha(35),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Temporary Skip button (10 min snooze)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: AppTheme.warningAmber.withAlpha(120),
                            ),
                          ),
                          icon: const Icon(
                            Icons.snooze_rounded,
                            size: 17,
                            color: AppTheme.warningAmber,
                          ),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Temporary Skip',
                              style: TextStyle(
                                color: AppTheme.warningAmber,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          onPressed: () async {
                            await widget.storage.temporarySkipFoodPrep();
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Snoozed: Popup will return in 10 minutes.',
                                  ),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Skip button (won't pop up again today)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: theme.colorScheme.outline.withAlpha(80),
                            ),
                          ),
                          icon: Icon(
                            Icons.block_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurface.withAlpha(160),
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Skip Today',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withAlpha(180),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          onPressed: () async {
                            await widget.storage.skipFoodPrepToday();
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Skipped: Floating window won\'t pop up again today.',
                                  ),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Complete / Done Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        backgroundColor: AppTheme.accentTeal,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Done & Close',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodCheckTile(
    ThemeData theme,
    FoodItem food,
    bool isChecked,
  ) {
    Color mealColor;
    IconData mealIcon;
    switch (food.mealType) {
      case MealType.morning:
        mealColor = const Color(0xFFF59E0B);
        mealIcon = Icons.wb_sunny_rounded;
        break;
      case MealType.noon:
        mealColor = const Color(0xFF10B981);
        mealIcon = Icons.light_mode_rounded;
        break;
      case MealType.evening:
        mealColor = const Color(0xFFF97316);
        mealIcon = Icons.wb_twilight_rounded;
        break;
      case MealType.night:
        mealColor = const Color(0xFF8B5CF6);
        mealIcon = Icons.nightlight_round;
        break;
    }

    return InkWell(
      onTap: () {
        setState(() {
          widget.storage.toggleTomorrowFoodChecked(food.id);
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isChecked
              ? AppTheme.accentTeal.withAlpha(20)
              : theme.colorScheme.surfaceContainerHighest.withAlpha(45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isChecked
                ? AppTheme.accentTeal.withAlpha(90)
                : theme.colorScheme.outline.withAlpha(30),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isChecked,
                activeColor: AppTheme.accentTeal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                onChanged: (_) {
                  setState(() {
                    widget.storage.toggleTomorrowFoodChecked(food.id);
                  });
                },
              ),
            ),
            const SizedBox(width: 12),

            // Meal badge icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: mealColor.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                mealIcon,
                size: 15,
                color: mealColor,
              ),
            ),
            const SizedBox(width: 10),

            // Food name & count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          food.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: isChecked
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            color: isChecked
                                ? theme.colorScheme.onSurface.withAlpha(120)
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (food.count != null && food.count!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: mealColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            food.count!,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: mealColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        flex: 2,
                        child: Text(
                          '${food.mealType.displayName} • ${food.deadline}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(130),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (food.notes != null && food.notes!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          flex: 3,
                          child: Text(
                            '• ${food.notes!}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(110),
                              fontStyle: FontStyle.italic,
                              fontSize: 10.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
