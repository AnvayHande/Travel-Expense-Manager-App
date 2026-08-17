import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../presentation/providers/trip_provider.dart';
import '../../../../presentation/providers/authentication_provider.dart';
import '../../../../presentation/providers/activity_provider.dart';

class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _destinationController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String _currency = 'USD';

  static const _currencies = ['USD', 'INR', 'EUR', 'GBP'];

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required bool isStart,
    required DateTime? current,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: isStart ? now : (_startDate ?? now),
      lastDate: now.add(const Duration(days: 365 * 5)),
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

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) {
      SnackbarHelper.showError(context, 'You must be logged in.');
      return;
    }

    final trip = await ref.read(tripProvider.notifier).createTrip(
          tripName: _nameController.text.trim(),
          destination: _destinationController.text.trim().isEmpty
              ? null
              : _destinationController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          currency: _currency,
          adminId: user.uid,
          adminName: user.name,
        );

    if (trip != null && mounted) {
      ref.read(activityServiceProvider).logActivity(
        tripId: trip.tripId,
        userId: user.uid,
        userName: user.name,
        actionType: 'trip_created',
        message: 'created this trip',
      );
      SnackbarHelper.showSuccess(context, 'Trip created successfully!');
      context.goNamed('tripDetails', pathParameters: {'tripId': trip.tripId});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tripState = ref.watch(tripProvider);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Create Trip'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trip Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Fill in the details for your new trip',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              CustomTextField(
                controller: _nameController,
                label: 'Trip Name *',
                hint: 'e.g. Summer Vacation',
                textInputAction: TextInputAction.next,
                prefixIcon: Icon(
                  Icons.edit_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Trip name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _destinationController,
                label: 'Destination',
                hint: 'e.g. Paris, France',
                textInputAction: TextInputAction.next,
                prefixIcon: Icon(
                  Icons.location_on_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Optional trip description',
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                maxLines: 3,
                prefixIcon: Icon(
                  Icons.description_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _buildCurrencyDropdown(colorScheme),
              const SizedBox(height: 16),
              _buildDatePickers(colorScheme),
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Create Trip',
                icon: Icons.add_circle_outline,
                isLoading: tripState.isLoading,
                onPressed: _handleCreate,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencyDropdown(ColorScheme colorScheme) {
    return DropdownButtonFormField<String>(
      initialValue: _currency,
      decoration: InputDecoration(
        labelText: 'Currency',
        prefixIcon: Icon(
          Icons.attach_money_rounded,
          color: colorScheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6750A4), width: 2),
        ),
        filled: true,
      ),
      items: _currencies
          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _currency = v);
      },
    );
  }

  Widget _buildDatePickers(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _DateField(
            label: 'Start Date',
            date: _startDate,
            colorScheme: colorScheme,
            onTap: () => _pickDate(isStart: true, current: _startDate),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DateField(
            label: 'End Date',
            date: _endDate,
            colorScheme: colorScheme,
            onTap: () => _pickDate(isStart: false, current: _endDate),
            validator: () {
              if (_startDate != null &&
                  _endDate != null &&
                  _endDate!.isBefore(_startDate!)) {
                SnackbarHelper.showError(
                    context, 'End date cannot be before start date.');
              }
            },
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final VoidCallback? validator;

  const _DateField({
    required this.label,
    required this.date,
    required this.colorScheme,
    required this.onTap,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            Icons.calendar_today_outlined,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
        ),
        child: Text(
          date != null
              ? '${date!.day}/${date!.month}/${date!.year}'
              : 'Select date',
          style: TextStyle(
            color: date != null
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
