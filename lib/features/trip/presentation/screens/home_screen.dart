import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/trip_model.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/section_title.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../presentation/providers/authentication_provider.dart';
import '../../../../presentation/providers/trip_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final tripsAsync = ref.watch(userTripsProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.screenHorizontalPadding,
            vertical: AppConstants.screenVerticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(context, colorScheme, user),
              SizedBox(height: 24),
              _buildWelcomeCard(context, colorScheme, user, tripsAsync),
              SizedBox(height: 24),
              _buildQuickActions(context, colorScheme),
              SizedBox(height: 24),
              _buildMyTrips(context, colorScheme, tripsAsync, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    ColorScheme colorScheme,
    dynamic user,
  ) {
    final initial = (user?.name ?? 'U').toString().characters.first.toUpperCase();

    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: colorScheme.primaryContainer,
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.name ?? 'User',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              if (user?.email != null)
                Text(
                  user!.email,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => context.pushNamed('settings'),
          icon: Icon(Icons.settings_outlined),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard(
    BuildContext context,
    ColorScheme colorScheme,
    dynamic user,
    AsyncValue<List<TripModel>> tripsAsync,
  ) {
    final allTrips = tripsAsync.asData?.value ?? [];
    final activeCount = allTrips.where((t) => t.isActive).length;
    final pastCount = allTrips.where((t) => !t.isActive).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, ${user?.name?.split(' ').first ?? 'Friend'}!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ready to manage your trip expenses?',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onPrimary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStat(context, '$activeCount', 'Active Trips',
                  colorScheme.onPrimary),
              const SizedBox(width: 32),
              _buildStat(context, '$pastCount', 'Past Trips',
                  colorScheme.onPrimary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: 'Quick Actions'),
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: 'Create Trip',
                icon: Icons.add_circle_outline,
                onPressed: () => context.pushNamed('createTrip'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SecondaryButton(
                label: 'Join Trip',
                icon: Icons.group_add_outlined,
                onPressed: () => context.pushNamed('joinTrip'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SecondaryButton(
                label: 'Scan QR',
                icon: Icons.qr_code_scanner_rounded,
                onPressed: () => context.pushNamed('scanQr'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMyTrips(
    BuildContext context,
    ColorScheme colorScheme,
    AsyncValue<List<TripModel>> tripsAsync,
    WidgetRef ref,
  ) {
    return tripsAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: LoadingIndicator(),
      ),
      error: (err, _) => SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Failed to load trips',
            style: TextStyle(color: colorScheme.error),
          ),
        ),
      ),
      data: (trips) {
        final activeTrips = trips.where((t) => t.isActive).toList();
        final pastTrips = trips.where((t) => !t.isActive).toList();

        if (trips.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.card_travel_outlined,
            title: 'No trips yet',
            subtitle:
                'Create a new trip or join one with an invite code',
            actionLabel: 'Create Trip',
            onAction: () => context.pushNamed('createTrip'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (activeTrips.isNotEmpty) ...[
              SectionTitle(title: 'Active Trips'),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activeTrips.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _buildTripCard(context, colorScheme, activeTrips[index], ref),
              ),
            ],
            if (pastTrips.isNotEmpty) ...[
              if (activeTrips.isNotEmpty) const SizedBox(height: 24),
              SectionTitle(title: 'Past Trips'),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pastTrips.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _buildTripCard(context, colorScheme, pastTrips[index], ref),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTripCard(
    BuildContext context,
    ColorScheme colorScheme,
    TripModel trip,
    WidgetRef ref,
  ) {
    final user = ref.watch(authProvider).user;
    final isAdmin = user != null && trip.isAdmin(user.uid);
    final isActive = trip.isActive;

    return Card(
      margin: EdgeInsets.zero,
      color: isActive ? null : colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: () => context.pushNamed(
          'tripDetails',
          pathParameters: {'tripId': trip.tripId},
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isActive
                      ? (isAdmin
                          ? colorScheme.primaryContainer
                          : colorScheme.secondaryContainer)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isAdmin ? Icons.star_rounded : Icons.card_travel_rounded,
                  color: isActive
                      ? (isAdmin ? colorScheme.primary : colorScheme.secondary)
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            trip.tripName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isAdmin && isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Admin',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        if (!isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.outline.withAlpha(40),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Completed',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (trip.destination != null &&
                            trip.destination!.isNotEmpty) ...[
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: isActive ? colorScheme.onSurfaceVariant : colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              trip.destination!,
                              style: TextStyle(
                                fontSize: 13,
                                color: isActive ? colorScheme.onSurfaceVariant : colorScheme.outline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Icon(
                          Icons.people_outlined,
                          size: 14,
                          color: isActive ? colorScheme.onSurfaceVariant : colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${trip.participants.length}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isActive ? colorScheme.onSurfaceVariant : colorScheme.outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          trip.currency,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isActive ? colorScheme.onSurfaceVariant : colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    if (trip.startDate != null || trip.endDate != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: isActive ? colorScheme.onSurfaceVariant : colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTripDates(trip),
                            style: TextStyle(
                              fontSize: 12,
                              color: isActive ? colorScheme.onSurfaceVariant : colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTripDates(TripModel trip) {
    if (trip.startDate != null && trip.endDate != null) {
      return '${DateFormatter.formatDayMonth(trip.startDate!)} - ${DateFormatter.formatDayMonth(trip.endDate!)}';
    } else if (trip.startDate != null) {
      return DateFormatter.formatDate(trip.startDate!);
    } else if (trip.endDate != null) {
      return DateFormatter.formatDate(trip.endDate!);
    }
    return '';
  }
}
