import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/trip_model.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../presentation/providers/trip_provider.dart';
import '../../../../presentation/providers/authentication_provider.dart';
import '../../../../presentation/providers/activity_provider.dart';

class JoinTripScreen extends ConsumerStatefulWidget {
  const JoinTripScreen({super.key});

  @override
  ConsumerState<JoinTripScreen> createState() => _JoinTripScreenState();
}

class _JoinTripScreenState extends ConsumerState<JoinTripScreen> {
  final _codeController = TextEditingController();
  TripModel? _foundTrip;
  bool _isSearching = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _searchTrip() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      SnackbarHelper.showError(context, 'Please enter an invite code.');
      return;
    }

    setState(() {
      _isSearching = true;
      _foundTrip = null;
    });

    final trip = await ref.read(tripProvider.notifier).getTripByInviteCode(code);

    if (mounted) {
      setState(() {
        _isSearching = false;
        _foundTrip = trip;
      });

      if (trip == null) {
        SnackbarHelper.showError(context, 'No trip found with this code.');
      }
    }
  }

  Future<void> _handleJoin() async {
    if (_foundTrip == null) return;

    final user = ref.read(authProvider).user;
    if (user == null) {
      SnackbarHelper.showError(context, 'You must be logged in.');
      return;
    }

    final success = await ref
        .read(tripProvider.notifier)
        .joinTrip(_foundTrip!.tripId, user.uid);

    if (mounted) {
      if (success) {
        ref.read(activityServiceProvider).logActivity(
          tripId: _foundTrip!.tripId,
          userId: user.uid,
          userName: user.name,
          actionType: 'participant_joined',
          message: 'joined the trip',
        );
        SnackbarHelper.showSuccess(
            context, 'You have joined the trip successfully!');
        context.goNamed(
          'tripDetails',
          pathParameters: {'tripId': _foundTrip!.tripId},
        );
      } else {
        final error = ref.read(tripProvider).error;
        SnackbarHelper.showError(
          context,
          error ?? 'Failed to join trip.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Join Trip'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter Invite Code',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask your trip admin for the invite code',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _codeController,
                    label: 'Invite Code',
                    hint: 'e.g. A7K9Q2',
                    textInputAction: TextInputAction.search,
                    prefixIcon: Icon(
                      Icons.vpn_key_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an invite code';
                      }
                      return null;
                    },
                    onSubmitted: (_) => _searchTrip(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSearching ? null : _searchTrip,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (_foundTrip != null) _buildTripPreview(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildTripPreview(ColorScheme colorScheme) {
    final trip = _foundTrip!;
    final user = ref.read(authProvider).user;
    final isAlreadyParticipant =
        user != null && trip.participants.contains(user.uid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trip Found',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.card_travel_rounded,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.tripName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          if (trip.destination != null &&
                              trip.destination!.isNotEmpty)
                            Text(
                              trip.destination!,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                _buildInfoRow(
                  colorScheme,
                  Icons.person_outlined,
                  'Admin',
                  trip.adminName,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  colorScheme,
                  Icons.people_outlined,
                  'Participants',
                  '${trip.participants.length} member${trip.participants.length == 1 ? '' : 's'}',
                ),
                if (trip.startDate != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    colorScheme,
                    Icons.calendar_today_outlined,
                    'Start Date',
                    DateFormatter.formatDate(trip.startDate!),
                  ),
                ],
                if (trip.endDate != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    colorScheme,
                    Icons.calendar_today_outlined,
                    'End Date',
                    DateFormatter.formatDate(trip.endDate!),
                  ),
                ],
                const SizedBox(height: 12),
                _buildInfoRow(
                  colorScheme,
                  Icons.attach_money_rounded,
                  'Currency',
                  trip.currency,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: isAlreadyParticipant
              ? 'Already a Member'
              : 'Join Trip',
          icon: isAlreadyParticipant
              ? Icons.check_circle_outline
              : Icons.group_add_outlined,
          onPressed: isAlreadyParticipant ? null : _handleJoin,
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    ColorScheme colorScheme,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
