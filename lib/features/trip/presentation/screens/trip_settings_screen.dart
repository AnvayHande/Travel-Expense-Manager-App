import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/trip_model.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../presentation/providers/trip_provider.dart';
import '../../../../presentation/providers/authentication_provider.dart';
import '../../../../presentation/providers/firebase_providers.dart';

class TripSettingsScreen extends ConsumerStatefulWidget {
  const TripSettingsScreen({super.key});

  @override
  ConsumerState<TripSettingsScreen> createState() =>
      _TripSettingsScreenState();
}

class _TripSettingsScreenState extends ConsumerState<TripSettingsScreen> {
  bool _isEditing = false;
  bool _isProcessing = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _destCtrl;
  late TextEditingController _descCtrl;
  String _currency = 'USD';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _destCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _initEditFields(TripModel trip) {
    _nameCtrl = TextEditingController(text: trip.tripName);
    _destCtrl = TextEditingController(text: trip.destination ?? '');
    _descCtrl = TextEditingController(text: trip.description ?? '');
    _currency = trip.currency;
    _startDate = trip.startDate;
    _endDate = trip.endDate;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final routeState = GoRouterState.of(context);
    final tripId = routeState.pathParameters['tripId'] ?? '';
    final tripAsync = ref.watch(tripByIdProvider(tripId));
    final user = ref.watch(authProvider).user;

    return tripAsync.when(
      loading: () => const Scaffold(
        appBar: CustomAppBar(title: 'Trip Settings'),
        body: LoadingIndicator(),
      ),
      error: (err, _) => Scaffold(
        appBar: const CustomAppBar(title: 'Trip Settings'),
        body: Center(child: Text('Error: $err')),
      ),
      data: (trip) {
        if (trip == null) {
          return Scaffold(
            appBar: const CustomAppBar(title: 'Trip Settings'),
            body: const Center(child: Text('Trip not found')),
          );
        }

        final isAdmin = user != null && trip.isAdmin(user.uid);
        final isOnlyAdmin =
            isAdmin && trip.participants.where((p) => p == user.uid).length == 1;

        if (!_isEditing) {
          _initEditFields(trip);
          _isEditing = true;
        }

        return Scaffold(
          appBar: const CustomAppBar(title: 'Trip Settings'),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!trip.isActive)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
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
              _buildTripInfoSection(trip, colorScheme, isAdmin),
              if (trip.isActive && isAdmin) ...[
                const SizedBox(height: 24),
                _buildEditForm(trip, colorScheme),
                const SizedBox(height: 24),
                _buildParticipantsSection(trip, colorScheme),
                const SizedBox(height: 24),
                _buildTransferAdminSection(trip, colorScheme),
                const SizedBox(height: 24),
                _buildDangerZone(trip, colorScheme),
              ],
              if (!isAdmin || !isOnlyAdmin) ...[
                const SizedBox(height: 24),
                _buildLeaveTripSection(trip, colorScheme, isAdmin, isOnlyAdmin),
              ],
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTripInfoSection(
      TripModel trip, ColorScheme colorScheme, bool isAdmin) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outlined,
                    size: 20, color: colorScheme.onSurface),
                const SizedBox(width: 8),
                Text('Trip Information',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
                const Spacer(),
                Icon(isAdmin ? Icons.lock_open_rounded : Icons.lock_rounded,
                    size: 16, color: colorScheme.onSurfaceVariant),
              ],
            ),
            const Divider(height: 24),
            _InfoRow(label: 'Name', value: trip.tripName, colorScheme: colorScheme),
            _InfoRow(label: 'Destination', value: trip.destination ?? 'Not set',
                colorScheme: colorScheme),
            _InfoRow(label: 'Description', value: trip.description ?? 'Not set',
                colorScheme: colorScheme),
            _InfoRow(label: 'Start Date',
                value: trip.startDate != null ? DateFormatter.formatDate(trip.startDate!) : 'Not set',
                colorScheme: colorScheme),
            _InfoRow(label: 'End Date',
                value: trip.endDate != null ? DateFormatter.formatDate(trip.endDate!) : 'Not set',
                colorScheme: colorScheme),
            _InfoRow(label: 'Currency', value: trip.currency, colorScheme: colorScheme),
            _InfoRow(label: 'Admin', value: trip.adminName, colorScheme: colorScheme),
            _InfoRow(label: 'Invite Code', value: trip.inviteCode ?? 'N/A',
                colorScheme: colorScheme, isLast: true),
          ],
        ),
      ),
    );
  }

  Widget _buildEditForm(TripModel trip, ColorScheme colorScheme) {
    final tripState = ref.watch(tripProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_outlined,
                    size: 20, color: colorScheme.onSurface),
                const SizedBox(width: 8),
                Text('Edit Trip Details',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
              ],
            ),
            const Divider(height: 24),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Trip Name *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _destCtrl,
              decoration: const InputDecoration(labelText: 'Destination'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _currency,
              decoration: const InputDecoration(labelText: 'Currency'),
              items: const [
                DropdownMenuItem(value: 'USD', child: Text('USD')),
                DropdownMenuItem(value: 'INR', child: Text('INR')),
                DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                DropdownMenuItem(value: 'GBP', child: Text('GBP')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _currency = v);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(true),
                    child: Text(_startDate != null
                        ? DateFormatter.formatDate(_startDate!)
                        : 'Start Date'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(false),
                    child: Text(_endDate != null
                        ? DateFormatter.formatDate(_endDate!)
                        : 'End Date'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: tripState.isLoading
                    ? null
                    : () => _saveTrip(trip),
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsSection(
      TripModel trip, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people_outlined,
                    size: 20, color: colorScheme.onSurface),
                const SizedBox(width: 8),
                Text('Participants',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
              ],
            ),
            const Divider(height: 24),
            ...trip.participants.map((uid) => _buildParticipantRow(
                trip, uid, colorScheme)),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantRow(
      TripModel trip, String uid, ColorScheme colorScheme) {
    final user = ref.watch(authProvider).user;
    final isSelf = user?.uid == uid;
    final isParticipantAdmin = trip.isAdmin(uid);
    final nameAsync = ref.watch(userNameProvider(uid));
    final name = nameAsync.valueOrNull ?? uid;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isParticipantAdmin
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            child: Icon(
              isParticipantAdmin
                  ? Icons.star_rounded
                  : Icons.person_outlined,
              size: 16,
              color: isParticipantAdmin
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$name${isSelf ? ' (You)' : ''}',
              style: TextStyle(
                fontWeight: isSelf ? FontWeight.w600 : FontWeight.normal,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          if (isParticipantAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Admin',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary)),
            ),
          if (!isParticipantAdmin && !isSelf)
            IconButton(
              icon: Icon(Icons.person_remove_outlined,
                  size: 20, color: colorScheme.error),
              tooltip: 'Remove participant',
              onPressed: _isProcessing
                  ? null
                  : () => _confirmRemoveParticipant(trip, uid),
            ),
        ],
      ),
    );
  }

  Widget _buildTransferAdminSection(
      TripModel trip, ColorScheme colorScheme) {
    final nonAdminParticipants = trip.participants
        .where((uid) => !trip.isAdmin(uid))
        .toList();

    if (nonAdminParticipants.isEmpty) {
      return const SizedBox.shrink();
    }

    String? selectedUid;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.admin_panel_settings_outlined,
                    size: 20, color: colorScheme.onSurface),
                const SizedBox(width: 8),
                Text('Transfer Admin Role',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Transfer admin role to another participant. You will lose admin privileges.',
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setLocalState) => Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedUid,
                    decoration: const InputDecoration(
                        labelText: 'New Admin'),
                    items: nonAdminParticipants.map((uid) {
                      final nameAsync =
                          ref.read(userNameProvider(uid));
                      final name = nameAsync.valueOrNull ?? uid;
                      return DropdownMenuItem(
                          value: uid, child: Text(name));
                    }).toList(),
                    onChanged: (v) {
                      setLocalState(() => selectedUid = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: selectedUid == null || _isProcessing
                          ? null
                          : () => _confirmTransferAdmin(
                              trip, selectedUid!),
                      icon: const Icon(Icons.swap_horiz_rounded,
                          size: 18),
                      label: const Text('Transfer Admin'),
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

  Widget _buildDangerZone(TripModel trip, ColorScheme colorScheme) {
    final tripState = ref.watch(tripProvider);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_rounded,
                    size: 20, color: colorScheme.error),
                const SizedBox(width: 8),
                Text('Danger Zone',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.error)),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Deleting this trip will permanently remove all expenses, settlements, and activity history.',
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: tripState.isLoading
                    ? null
                    : () => _confirmDeleteTrip(trip),
                icon: const Icon(Icons.delete_rounded, size: 18),
                label: const Text('Delete This Trip'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveTripSection(TripModel trip, ColorScheme colorScheme,
      bool isAdmin, bool isOnlyAdmin) {
    if (isOnlyAdmin) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.exit_to_app_rounded,
                size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Leave Trip',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface)),
                  Text('You will no longer be a participant.',
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            TextButton(
              onPressed: _isProcessing
                  ? null
                  : () => _confirmLeaveTrip(trip),
              child: const Text('Leave'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final current = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveTrip(TripModel trip) async {
    if (_nameCtrl.text.trim().isEmpty) {
      SnackbarHelper.showError(context, 'Trip name is required.');
      return;
    }

    final updated = trip.copyWith(
      tripName: _nameCtrl.text.trim(),
      destination: _destCtrl.text.trim().isEmpty
          ? null
          : _destCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      currency: _currency,
      startDate: _startDate,
      endDate: _endDate,
    );

    final success =
        await ref.read(tripProvider.notifier).updateTrip(updated);
    if (mounted) {
      if (success) {
        SnackbarHelper.showSuccess(context, 'Trip updated!');
      } else {
        SnackbarHelper.showError(
            context,
            ref.read(tripProvider).error ?? 'Failed to update trip.');
      }
    }
  }

  Future<void> _confirmRemoveParticipant(
      TripModel trip, String userIdToRemove) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final nameAsync = ref.read(userNameProvider(userIdToRemove));
    final name = nameAsync.valueOrNull ?? userIdToRemove;

    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Remove Participant',
      message: 'Remove $name from this trip?',
      confirmLabel: 'Remove',
      icon: Icons.person_remove_rounded,
      confirmColor: Colors.red,
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    final success = await ref.read(tripProvider.notifier).removeParticipant(
          tripId: trip.tripId,
          userIdToRemove: userIdToRemove,
          currentUserId: user.uid,
          currentUserName: user.name,
        );

    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        SnackbarHelper.showSuccess(context, 'Participant removed.');
      } else {
        final error = ref.read(tripProvider).error;
        SnackbarHelper.showError(
            context, error ?? 'Failed to remove participant.');
      }
    }
  }

  Future<void> _confirmTransferAdmin(
      TripModel trip, String newAdminId) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final nameAsync = ref.read(userNameProvider(newAdminId));
    final newAdminName = nameAsync.valueOrNull ?? newAdminId;

    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Transfer Admin',
      message:
          'Transfer admin role to $newAdminName? You will become a regular participant.',
      confirmLabel: 'Transfer',
      icon: Icons.swap_horiz_rounded,
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    final success =
        await ref.read(tripProvider.notifier).transferAdminRole(
              tripId: trip.tripId,
              newAdminId: newAdminId,
              newAdminName: newAdminName,
              currentUserId: user.uid,
              currentUserName: user.name,
            );

    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        SnackbarHelper.showSuccess(
            context, 'Admin role transferred to $newAdminName!');
      } else {
        final error = ref.read(tripProvider).error;
        SnackbarHelper.showError(
            context, error ?? 'Failed to transfer admin role.');
      }
    }
  }

  Future<void> _confirmDeleteTrip(TripModel trip) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Trip',
      message:
          'Are you sure you want to delete "${trip.tripName}"? This will permanently remove all expenses, settlements, and activity history.',
      confirmLabel: 'Delete Everything',
      icon: Icons.delete_rounded,
      confirmColor: Colors.red,
    );

    if (confirmed != true) return;

    final success = await ref
        .read(tripProvider.notifier)
        .deleteTripWithAllData(trip.tripId);

    if (mounted) {
      if (success) {
        SnackbarHelper.showSuccess(context, 'Trip deleted.');
        context.goNamed('home');
      } else {
        SnackbarHelper.showError(
            context,
            ref.read(tripProvider).error ?? 'Failed to delete trip.');
      }
    }
  }

  Future<void> _confirmLeaveTrip(TripModel trip) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Leave Trip',
      message:
          'Are you sure you want to leave "${trip.tripName}"?',
      confirmLabel: 'Leave',
      icon: Icons.exit_to_app_rounded,
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    final success = await ref.read(tripProvider.notifier).leaveTrip(
          tripId: trip.tripId,
          userId: user.uid,
        );

    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        SnackbarHelper.showSuccess(context, 'You left the trip.');
        context.goNamed('home');
      } else {
        SnackbarHelper.showError(
            context,
            ref.read(tripProvider).error ?? 'Failed to leave trip.');
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme colorScheme;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.colorScheme,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13, color: colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface)),
          ),
        ],
      ),
    );
  }
}
