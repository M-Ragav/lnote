import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class SkillsPage extends StatefulWidget {
  final StorageService storage;

  const SkillsPage({super.key, required this.storage});

  @override
  State<SkillsPage> createState() => _SkillsPageState();
}

class _SkillsPageState extends State<SkillsPage> {
  static const double _masteryHours = 10000;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skills = widget.storage.skills;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skills'),
      ),
      body: skills.isEmpty
          ? _buildEmpty(theme)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount: skills.length,
              itemBuilder: (context, index) {
                return _buildSkillCard(theme, skills[index]);
              },
            ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.accentGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentTeal.withAlpha(100),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddSkillDialog(context),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withAlpha(51),
          ),
          const SizedBox(height: 16),
          Text(
            'No skills yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(102),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first skill to start tracking mastery',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildSkillCard(ThemeData theme, dynamic skill) {
    final totalDuration = widget.storage.getHoursForSkill(skill.name);
    final totalHours = totalDuration.inMinutes / 60.0;
    final progress = (totalHours / _masteryHours).clamp(0.0, 1.0);
    final percent = (progress * 100);
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes.remainder(60);
    final hoursStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    return Dismissible(
      key: Key(skill.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withAlpha(30),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: Icon(Icons.delete_outline_rounded,
            color: AppTheme.errorRed.withAlpha(179)),
      ),
      confirmDismiss: (direction) async {
        return await _confirmDelete(context, skill.name);
      },
      onDismissed: (direction) {
        widget.storage.removeSkill(skill.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withAlpha(77),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Skill name + hours
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.accentTeal.withAlpha(30),
                        AppTheme.accentCyan.withAlpha(15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: AppTheme.accentTeal.withAlpha(204),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$hoursStr logged',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(128),
                        ),
                      ),
                    ],
                  ),
                ),
                // Percentage
                Text(
                  '${percent.toStringAsFixed(1)}%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.accentTeal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor:
                    theme.colorScheme.onSurface.withAlpha(26),
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.accentTeal),
              ),
            ),
            const SizedBox(height: 6),

            // Hours label
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${totalHours.toStringAsFixed(1)} / ${_masteryHours.round()} hours',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(102),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, String skillName) async {
    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Skill', style: theme.textTheme.headlineMedium),
        content: Text(
          'Remove "$skillName"? This won\'t delete tagged session data.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                Text('Delete', style: TextStyle(color: AppTheme.errorRed)),
          ),
        ],
      ),
    );
  }

  void _showAddSkillDialog(BuildContext context) {
    final theme = Theme.of(context);
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withAlpha(51),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Add Skill', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Track your journey to 10,000 hours of mastery',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),

            // Name field
            Text(
              'SKILL NAME',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              style: theme.textTheme.titleMedium,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. Flutter, Piano, Drawing',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(77),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: theme.colorScheme.outline.withAlpha(128)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppTheme.accentTeal, width: 1.5),
                ),
              ),
              onSubmitted: (value) {
                final name = value.trim();
                if (name.isNotEmpty) {
                  widget.storage.addSkill(name);
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 20),

            // Add button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      widget.storage.addSkill(name);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Add Skill',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
