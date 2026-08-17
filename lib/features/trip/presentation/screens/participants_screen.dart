import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/trip_model.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../presentation/providers/trip_provider.dart';
import '../../../../presentation/providers/authentication_provider.dart';
import '../../../../presentation/providers/firebase_providers.dart';
import '../../../../presentation/providers/settlement_provider.dart';

class ParticipantsScreen extends ConsumerWidget {
  const ParticipantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeState = GoRouterState.of(context);
    final tripId = routeState.pathParameters['tripId'] ?? '';
    final tripAsync = ref.watch(tripByIdProvider(tripId));

    return tripAsync.when(
      loading: () => const Scaffold(
        appBar: CustomAppBar(title: 'Participants'),
        body: LoadingIndicator(),
      ),
      error: (err, _) => Scaffold(
        appBar: const CustomAppBar(title: 'Participants'),
        body: Center(child: Text('Error: $err')),
      ),
      data: (trip) {
        if (trip == null) {
          return Scaffold(
            appBar: const CustomAppBar(title: 'Participants'),
            body: const Center(child: Text('Trip not found')),
          );
        }
        return _ParticipantsContent(trip: trip);
      },
    );
  }
}

class _ParticipantsContent extends ConsumerWidget {
  final TripModel trip;

  const _ParticipantsContent({required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(authProvider).user;
    final isAdmin = user != null && trip.isAdmin(user.uid);
    final balances = ref.watch(tripBalanceProvider(trip.tripId));

    return Scaffold(
      appBar: const CustomAppBar(title: 'Participants'),
      body: Column(
        children: [
          if (!trip.isActive)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.grey.shade700,
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade300),
                  const SizedBox(width: 8),
                  Text(
                    'This trip is completed and is now read-only.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade300),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Icon(
                  Icons.people_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${trip.participants.length} Member${trip.participants.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (isAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ADMIN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: trip.participants.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final participantId = trip.participants[index];
                final isCurrentUser = user?.uid == participantId;
                final isParticipantAdmin = trip.isAdmin(participantId);
                final nameAsync = ref.watch(userNameProvider(participantId));
                final participantName = nameAsync.valueOrNull ?? participantId;
                final balance = balances?[participantId];

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: isParticipantAdmin
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    child: Text(
                      participantName.isNotEmpty
                          ? participantName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isParticipantAdmin
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  title: Text(
                    isCurrentUser ? '$participantName (You)' : participantName,
                    style: TextStyle(
                      fontWeight:
                          isCurrentUser ? FontWeight.w600 : FontWeight.normal,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Text(
                        isParticipantAdmin ? 'Admin' : 'Member',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (balance != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '\u2022',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          balance.netBalance >= 0
                              ? 'Gets back \$${balance.netBalance.toStringAsFixed(2)}'
                              : 'Owes \$${(-balance.netBalance).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: balance.netBalance >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.pushNamed(
                    'participantLedger',
                    pathParameters: {
                      'tripId': trip.tripId,
                      'userId': participantId,
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
