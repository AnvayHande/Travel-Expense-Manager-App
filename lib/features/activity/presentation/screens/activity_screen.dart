import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/activity_model.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../presentation/providers/activity_provider.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routeState = GoRouterState.of(context);
      final tripId = routeState.pathParameters['tripId'] ?? '';
      ref.read(unreadProvider.notifier).markAsRead(tripId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final routeState = GoRouterState.of(context);
    final tripId = routeState.pathParameters['tripId'] ?? '';
    final activitiesAsync = ref.watch(tripActivitiesProvider(tripId));

    return Scaffold(
      appBar: const CustomAppBar(title: 'Activity'),
      body: activitiesAsync.when(
        loading: () =>
            const LoadingIndicator(message: 'Loading activity...'),
        error: (err, _) => Center(
          child: Text('Failed to load activity',
              style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ),
        data: (activities) {
          if (activities.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded,
                      size: 72,
                      color: colorScheme.onSurface.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text(
                    'No activity yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Trip actions will appear here.',
                    style:
                        TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }
          return _ActivityList(activities: activities);
        },
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  final List<ActivityModel> activities;

  const _ActivityList({required this.activities});

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDate(activities);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateHeader(label: entry.key),
            const SizedBox(height: 8),
            ...entry.value.map((activity) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ActivityCard(activity: activity),
                )),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Map<String, List<ActivityModel>> _groupByDate(
      List<ActivityModel> activities) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final grouped = <String, List<ActivityModel>>{};

    for (final a in activities) {
      final day = DateTime(
          a.createdAt.year, a.createdAt.month, a.createdAt.day);
      String label;
      if (day == today) {
        label = 'Today';
      } else if (day == yesterday) {
        label = 'Yesterday';
      } else {
        label =
            '${_monthName(day.month)} ${day.day}, ${day.year}';
      }
      grouped.putIfAbsent(label, () => []).add(a);
    }
    return grouped;
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}

class _DateHeader extends StatelessWidget {
  final String label;

  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityModel activity;

  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconInfo = _iconForType(activity.actionType);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: iconInfo.color.withValues(alpha: 0.12),
              child: Icon(iconInfo.icon, size: 18, color: iconInfo.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                      children: [
                        TextSpan(
                          text: activity.userName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: ' ${activity.message}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(activity.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
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

  _IconInfo _iconForType(String type) {
    switch (type) {
      case 'trip_created':
        return _IconInfo(Icons.flag_rounded, Colors.green);
      case 'participant_joined':
        return _IconInfo(Icons.person_add_rounded, Colors.blue);
      case 'expense_added':
        return _IconInfo(Icons.add_circle_rounded, Colors.orange);
      case 'expense_edited':
        return _IconInfo(Icons.edit_rounded, Colors.indigo);
      case 'expense_deleted':
        return _IconInfo(Icons.delete_rounded, Colors.red);
      case 'settlement_completed':
        return _IconInfo(Icons.check_circle_rounded, Colors.green);
      default:
        return _IconInfo(Icons.info_rounded, Colors.grey);
    }
  }

  String _relativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m minute${m == 1 ? '' : 's'} ago';
    } else if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h hour${h == 1 ? '' : 's'} ago';
    } else if (diff.inDays < 7) {
      final d = diff.inDays;
      return '$d day${d == 1 ? '' : 's'} ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}

class _IconInfo {
  final IconData icon;
  final Color color;

  const _IconInfo(this.icon, this.color);
}
