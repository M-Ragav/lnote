import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../services/storage_service.dart';

/// Detail page for a specific meal slot (Morning, Noon, Evening, Night)
class MealDetailPage extends StatefulWidget {
  final StorageService storage;
  final MealType mealType;

  const MealDetailPage({
    super.key,
    required this.storage,
    required this.mealType,
  });

  @override
  State<MealDetailPage> createState() => _MealDetailPageState();
}

class _MealDetailPageState extends State<MealDetailPage> {
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

  Color get _accentColor {
    switch (widget.mealType) {
      case MealType.morning:
        return const Color(0xFFF59E0B);
      case MealType.noon:
        return const Color(0xFF10B981);
      case MealType.evening:
        return const Color(0xFFF97316);
      case MealType.night:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData get _mealIcon {
    switch (widget.mealType) {
      case MealType.morning:
        return Icons.wb_sunny_rounded;
      case MealType.noon:
        return Icons.light_mode_rounded;
      case MealType.evening:
        return Icons.wb_twilight_rounded;
      case MealType.night:
        return Icons.nightlight_round;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foods = widget.storage.getFoodsForMeal(widget.mealType);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _accentColor.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_mealIcon, color: _accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Text('${widget.mealType.displayName} Foods'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ─── Header Info Card ───
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _accentColor.withAlpha(25),
                  _accentColor.withAlpha(8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _accentColor.withAlpha(50),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.mealType.subtitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _accentColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Target window: ${widget.mealType.defaultTimeHint}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(160),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _accentColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${foods.length} items',
                    style: TextStyle(
                      color: _accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Foods List ───
          Expanded(
            child: foods.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                    itemCount: foods.length,
                    itemBuilder: (context, index) {
                      return _buildFoodCard(theme, foods[index]);
                    },
                  ),
          ),
        ],
      ),
      // ─── Floating Add Icon ───
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          'Add ${widget.mealType.displayName} Food',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showAddEditSheet(context),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _accentColor.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(_mealIcon, size: 40, color: _accentColor),
            ),
            const SizedBox(height: 20),
            Text(
              'No Foods for ${widget.mealType.displayName}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the add button below to set up what you want to eat for ${widget.mealType.displayName.toLowerCase()}, set count, target days, and eating deadline.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(140),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Food Now'),
              onPressed: () => _showAddEditSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodCard(ThemeData theme, FoodItem food) {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(45),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(theme.brightness == Brightness.dark ? 40 : 12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Name, Count, Toggle / Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              food.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                decoration: food.isEnabled
                                    ? TextDecoration.none
                                    : TextDecoration.lineThrough,
                                color: food.isEnabled
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurface.withAlpha(110),
                              ),
                            ),
                          ),
                          if (food.count != null && food.count!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: _accentColor.withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                food.count!,
                                style: TextStyle(
                                  color: _accentColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: _accentColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Deadline: ${food.deadline}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: theme.colorScheme.onSurface.withAlpha(160),
                    size: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showAddEditSheet(context, food: food);
                    } else if (val == 'toggle') {
                      widget.storage.toggleFoodActive(food.id);
                    } else if (val == 'delete') {
                      _confirmDelete(context, food);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: const [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Edit Food'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            food.isEnabled
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(food.isEnabled ? 'Pause Food' : 'Activate Food'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: const [
                          Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                          SizedBox(width: 10),
                          Text('Delete', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Notes if any
            if (food.notes != null && food.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  food.notes!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurface.withAlpha(170),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Weekdays selection indicator row
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Days:',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(130),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...List.generate(7, (i) {
                        final dayNum = i + 1; // 1 = Mon .. 7 = Sun
                        final isSelected = food.daysOfWeek.contains(dayNum);
                        return Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(right: 3),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _accentColor.withAlpha(45)
                                : theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? _accentColor
                                  : theme.colorScheme.outline.withAlpha(25),
                              width: 0.8,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            dayLabels[i],
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? _accentColor
                                  : theme.colorScheme.onSurface.withAlpha(90),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _accentColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    food.daysOfWeek.length == 7
                        ? 'Every day'
                        : (food.daysOfWeek.length == 5 &&
                                !food.daysOfWeek.contains(6) &&
                                !food.daysOfWeek.contains(7)
                            ? 'Weekdays'
                            : (food.daysOfWeek.length == 2 &&
                                    food.daysOfWeek.contains(6) &&
                                    food.daysOfWeek.contains(7)
                                ? 'Weekends'
                                : '${food.daysOfWeek.length} days/wk')),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, FoodItem food) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Food?'),
        content: Text('Are you sure you want to remove "${food.name}" from ${widget.mealType.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              widget.storage.removeFood(food.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddEditSheet(BuildContext context, {FoodItem? food}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddEditFoodSheet(
        mealType: widget.mealType,
        accentColor: _accentColor,
        existingFood: food,
        onSave: (newItem) async {
          if (food == null) {
            await widget.storage.addFood(newItem);
          } else {
            await widget.storage.updateFood(newItem);
          }
        },
      ),
    );
  }
}

/// Bottom sheet for adding or editing a food item
class _AddEditFoodSheet extends StatefulWidget {
  final MealType mealType;
  final Color accentColor;
  final FoodItem? existingFood;
  final Future<void> Function(FoodItem) onSave;

  const _AddEditFoodSheet({
    required this.mealType,
    required this.accentColor,
    this.existingFood,
    required this.onSave,
  });

  @override
  State<_AddEditFoodSheet> createState() => _AddEditFoodSheetState();
}

class _AddEditFoodSheetState extends State<_AddEditFoodSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _countController;
  late final TextEditingController _notesController;
  late List<int> _selectedDays;
  late String _deadline;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final f = widget.existingFood;
    _nameController = TextEditingController(text: f?.name ?? '');
    _countController = TextEditingController(text: f?.count ?? '');
    _notesController = TextEditingController(text: f?.notes ?? '');
    _selectedDays = f != null ? List<int>.from(f.daysOfWeek) : [1, 2, 3, 4, 5, 6, 7];
    _deadline = f?.deadline ?? widget.mealType.defaultDeadline;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    // Parse current deadline string
    TimeOfDay initial = const TimeOfDay(hour: 8, minute: 30);
    try {
      final parts = _deadline.replaceAll(RegExp(r'[^\d:]'), '').split(':');
      if (parts.length >= 2) {
        var h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        if (_deadline.toUpperCase().contains('PM') && h < 12) h += 12;
        if (_deadline.toUpperCase().contains('AM') && h == 12) h = 0;
        initial = TimeOfDay(hour: h, minute: m);
      }
    } catch (_) {}

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null && mounted) {
      final formatted = picked.format(context);
      setState(() {
        _deadline = formatted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingFood != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    const dayTitles = [
      {'num': 1, 'label': 'Mon'},
      {'num': 2, 'label': 'Tue'},
      {'num': 3, 'label': 'Wed'},
      {'num': 4, 'label': 'Thu'},
      {'num': 5, 'label': 'Fri'},
      {'num': 6, 'label': 'Sat'},
      {'num': 7, 'label': 'Sun'},
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(40),
          width: 0.8,
        ),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withAlpha(70),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Food' : 'Add ${widget.mealType.displayName} Food',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    splashRadius: 20,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ─── Food Name (Required) ───
              TextFormField(
                controller: _nameController,
                autofocus: !isEditing,
                decoration: InputDecoration(
                  labelText: 'Food Name *',
                  hintText: 'e.g. Boiled Eggs, Oatmeal, Green Salad',
                  prefixIcon: Icon(Icons.restaurant_menu_rounded, color: widget.accentColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: widget.accentColor, width: 2),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a food name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // ─── Count / Quantity (Optional) ───
              TextFormField(
                controller: _countController,
                decoration: InputDecoration(
                  labelText: 'Count / Quantity (Optional)',
                  hintText: 'e.g. 2 eggs, 1 bowl, 250ml',
                  prefixIcon: Icon(Icons.scale_rounded, color: widget.accentColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: widget.accentColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ─── Notes (Optional) ───
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'e.g. Soak overnight in warm water, add honey',
                  prefixIcon: Icon(Icons.note_alt_outlined, color: widget.accentColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: widget.accentColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ─── Deadline to have the food ───
              Text(
                'Deadline to have food',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDeadline,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withAlpha(50),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded, color: widget.accentColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _deadline,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.accentColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Change',
                          style: TextStyle(
                            color: widget.accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ─── Days Selection in the week ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Days of the Week',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedDays = [1, 2, 3, 4, 5, 6, 7]);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('All', style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedDays = [1, 2, 3, 4, 5]);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Weekdays', style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedDays = [6, 7]);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Weekends', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 7 Day Toggle Chips (flex-expanded for all screen widths)
              Row(
                children: dayTitles.map((item) {
                  final dayNum = item['num'] as int;
                  final dayLabel = item['label'] as String;
                  final isSelected = _selectedDays.contains(dayNum);

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              if (_selectedDays.length > 1) {
                                _selectedDays.remove(dayNum);
                              }
                            } else {
                              _selectedDays.add(dayNum);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? widget.accentColor
                                : theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? widget.accentColor
                                  : theme.colorScheme.outline.withAlpha(40),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              dayLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : theme.colorScheme.onSurface.withAlpha(160),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: widget.accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (_formKey.currentState?.validate() ?? false) {
                      final item = FoodItem(
                        id: widget.existingFood?.id ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        name: _nameController.text.trim(),
                        count: _countController.text.trim().isEmpty
                            ? null
                            : _countController.text.trim(),
                        notes: _notesController.text.trim().isEmpty
                            ? null
                            : _notesController.text.trim(),
                        daysOfWeek: _selectedDays,
                        deadline: _deadline,
                        mealType: widget.mealType,
                        isEnabled: widget.existingFood?.isEnabled ?? true,
                      );
                      await widget.onSave(item);
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  },
                  child: Text(
                    isEditing ? 'Save Changes' : 'Add Food',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
