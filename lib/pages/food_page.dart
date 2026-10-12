import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/food_item.dart';
import '../services/storage_service.dart';
import '../widgets/food_prep_dialog.dart';
import 'meal_detail_page.dart';

/// Full-page Food tracking view with Morning, Noon, Evening, and Night square cards
class FoodPage extends StatefulWidget {
  final StorageService storage;

  const FoodPage({super.key, required this.storage});

  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> {
  @override
  void initState() {
    super.initState();
    widget.storage.addListener(_onUpdate);
  }

  @override
  void dispose() {
    widget.storage.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  void _openMeal(MealType mealType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MealDetailPage(
          storage: widget.storage,
          mealType: mealType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowName = DateFormat('EEEE').format(tomorrow);
    final tomorrowFoods = widget.storage.getTomorrowFoods();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meals & Nutrition'),
        actions: [
          // Food Prep Checklist floating window launcher
          IconButton(
            tooltip: 'Food Preparation Checklist',
            icon: Badge(
              isLabelVisible: tomorrowFoods.isNotEmpty,
              label: Text('${tomorrowFoods.length}'),
              child: const Icon(Icons.checklist_rtl_rounded),
            ),
            onPressed: () => FoodPrepDialog.show(context, widget.storage),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompactHeight = constraints.maxHeight < 540;

            final gridCards = isCompactHeight
                ? [
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 180,
                            child: _buildMealSquare(
                              theme: theme,
                              mealType: MealType.morning,
                              title: 'Morning',
                              subtitle: 'Breakfast',
                              icon: Icons.wb_sunny_rounded,
                              gradientColors: [
                                const Color(0xFFF59E0B),
                                const Color(0xFFEF4444),
                              ],
                              accentColor: const Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 180,
                            child: _buildMealSquare(
                              theme: theme,
                              mealType: MealType.noon,
                              title: 'Noon',
                              subtitle: 'Lunch',
                              icon: Icons.light_mode_rounded,
                              gradientColors: [
                                const Color(0xFF10B981),
                                const Color(0xFF047857),
                              ],
                              accentColor: const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 180,
                            child: _buildMealSquare(
                              theme: theme,
                              mealType: MealType.evening,
                              title: 'Evening',
                              subtitle: 'Snack & Tea',
                              icon: Icons.wb_twilight_rounded,
                              gradientColors: [
                                const Color(0xFFF97316),
                                const Color(0xFFEC4899),
                              ],
                              accentColor: const Color(0xFFF97316),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 180,
                            child: _buildMealSquare(
                              theme: theme,
                              mealType: MealType.night,
                              title: 'Night',
                              subtitle: 'Dinner',
                              icon: Icons.nightlight_round,
                              gradientColors: [
                                const Color(0xFF6366F1),
                                const Color(0xFF8B5CF6),
                              ],
                              accentColor: const Color(0xFF8B5CF6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ]
                : [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildMealSquare(
                              theme: theme,
                              mealType: MealType.morning,
                              title: 'Morning',
                              subtitle: 'Breakfast',
                              icon: Icons.wb_sunny_rounded,
                              gradientColors: [
                                const Color(0xFFF59E0B),
                                const Color(0xFFEF4444),
                              ],
                              accentColor: const Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMealSquare(
                              theme: theme,
                              mealType: MealType.noon,
                              title: 'Noon',
                              subtitle: 'Lunch',
                              icon: Icons.light_mode_rounded,
                              gradientColors: [
                                const Color(0xFF10B981),
                                const Color(0xFF047857),
                              ],
                              accentColor: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildMealSquare(
                              theme: theme,
                              mealType: MealType.evening,
                              title: 'Evening',
                              subtitle: 'Snack & Tea',
                              icon: Icons.wb_twilight_rounded,
                              gradientColors: [
                                const Color(0xFFF97316),
                                const Color(0xFFEC4899),
                              ],
                              accentColor: const Color(0xFFF97316),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMealSquare(
                              theme: theme,
                              mealType: MealType.night,
                              title: 'Night',
                              subtitle: 'Dinner',
                              icon: Icons.nightlight_round,
                              gradientColors: [
                                const Color(0xFF6366F1),
                                const Color(0xFF8B5CF6),
                              ],
                              accentColor: const Color(0xFF8B5CF6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ];

            final content = Column(
              children: [
                // ─── Quick Banner ───
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.outline.withAlpha(30),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tomorrow ($tomorrowName): ${tomorrowFoods.length} foods planned',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => FoodPrepDialog.show(context, widget.storage),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Checklist',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── 4 Square Options covering the whole page (2x2 grid) ───
                ...gridCards,
              ],
            );

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: isCompactHeight
                  ? SingleChildScrollView(child: content)
                  : content,
            );
          },
        ),
      ),
    );
  }

  Widget _buildMealSquare({
    required ThemeData theme,
    required MealType mealType,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required Color accentColor,
  }) {
    final foods = widget.storage.getFoodsForMeal(mealType);
    final count = foods.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openMeal(mealType),
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                gradientColors[0].withAlpha(theme.brightness == Brightness.dark ? 45 : 30),
                gradientColors[1].withAlpha(theme.brightness == Brightness.dark ? 25 : 15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accentColor.withAlpha(70),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withAlpha(25),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top row: Icon badge & count pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: gradientColors[0].withAlpha(90),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 26),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withAlpha(35),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accentColor.withAlpha(60),
                          width: 0.8,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          count == 1 ? '1 food' : '$count foods',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Center food previews (if any)
                if (foods.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: foods.take(2).map((f) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  f.name,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 11.5,
                                    color: theme.colorScheme.onSurface.withAlpha(190),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ] else ...[
                  Text(
                    'No foods added yet',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(120),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],

                // Bottom row: Title & Subtitle + Arrow icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(150),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: accentColor.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: accentColor,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
