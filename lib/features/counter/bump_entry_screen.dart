import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dw_baby_bump/core/constants/app_colors.dart';
import 'package:dw_baby_bump/core/constants/app_strings.dart';
import 'package:dw_baby_bump/core/utils/date_time_utils.dart';
import 'package:dw_baby_bump/database/bump_repository.dart';
import 'package:dw_baby_bump/features/auth/auth_provider.dart';
import 'package:dw_baby_bump/models/bump_entry.dart';
import 'widgets/count_input.dart';
import 'widgets/location_selector.dart';

class BumpEntryScreen extends ConsumerStatefulWidget {
  final BumpEntry? existingEntry; // If viewing an existing record (read-only)

  const BumpEntryScreen({super.key, this.existingEntry});

  @override
  ConsumerState<BumpEntryScreen> createState() => _BumpEntryScreenState();
}

class _BumpEntryScreenState extends ConsumerState<BumpEntryScreen> {
  late DateTime _selectedDate;
  late TextEditingController _timeController;
  late TextEditingController _noteController;
  late String _selectedLocation;
  late int _bumpCount;
  String? _timeError;
  bool _isSaving = false;

  bool get isReadOnly => widget.existingEntry != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    if (widget.existingEntry != null) {
      _selectedDate = DateTime.tryParse(widget.existingEntry!.date) ?? now;
      _timeController = TextEditingController(text: widget.existingEntry!.time);
      _selectedLocation = widget.existingEntry!.location;
      _bumpCount = widget.existingEntry!.count;
      _noteController = TextEditingController(
        text: widget.existingEntry!.note ?? widget.existingEntry!.observation ?? '',
      );
    } else {
      _selectedDate = now;
      // Auto-filled 24-hr time as default, user can freely edit in HH:mm
      _timeController = TextEditingController(text: DateTimeUtils.format24HourTime(now));
      _selectedLocation = AppStrings.bumpLocations[0]; // Upper Left
      _bumpCount = 1;
      _noteController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _timeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    if (isReadOnly) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.dustyRose,
              onPrimary: Colors.white,
              onSurface: AppColors.deepPlum,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTimeFromDialog() async {
    if (isReadOnly) return;

    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.dustyRose,
                onPrimary: Colors.white,
                onSurface: AppColors.deepPlum,
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minuteStr = picked.minute.toString().padLeft(2, '0');
      setState(() {
        _timeController.text = '$hourStr:$minuteStr';
        _timeError = null;
      });
    }
  }

  Future<void> _saveEntry() async {
    if (isReadOnly) return;

    final timeText = _timeController.text.trim();
    if (!DateTimeUtils.isValid24HourTime(timeText)) {
      setState(() {
        _timeError = 'Enter time in 24-hour format (HH:mm), e.g. 14:35';
      });
      return;
    }

    setState(() {
      _timeError = null;
      _isSaving = true;
    });

    final auth = ref.read(authProvider);
    final uid = auth.currentUser?.uid;

    final entry = BumpEntry(
      date: DateTimeUtils.formatIsoDate(_selectedDate),
      time: timeText,
      location: _selectedLocation,
      count: _bumpCount,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      observation: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );

    try {
      final result = await ref.read(bumpEntriesProvider.notifier).addEntry(entry, uid: uid);
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.deepPlum,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.sage),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      result.message.isNotEmpty
                          ? result.message
                          : 'Baby bump logged successfully!',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Text(result.message),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Failed to save entry: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: Text(isReadOnly ? 'Bump Record Details' : 'Log Baby Bump'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Description Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.blushPink.withOpacity(0.55),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_rounded, color: AppColors.dustyRose, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isReadOnly ? 'Recorded Movement Details' : 'Record Little Kicks & Bumps',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepPlum,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isReadOnly
                              ? 'View logged date, time, location and bump count.'
                              : 'Fill in date, 24-hr time, location & kicks felt.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.deepPlum.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Date Selection / Display
            Text(
              isReadOnly ? 'Date' : 'Date (Auto-filled today)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: isReadOnly ? null : _pickDate,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowColor.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.dustyRose),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        DateTimeUtils.formatDisplayDate(_selectedDate),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepPlum,
                        ),
                      ),
                    ),
                    if (!isReadOnly)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.lavender.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          DateTimeUtils.friendlyRelativeDate(
                              DateTimeUtils.formatIsoDate(_selectedDate)),
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepPlum),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Time Selection / Display
            Text(
              isReadOnly ? 'Time (24-hour)' : 'Time in 24-hour format (HH:mm)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _timeController,
                    readOnly: isReadOnly,
                    keyboardType: TextInputType.datetime,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                      color: AppColors.deepPlum,
                    ),
                    decoration: InputDecoration(
                      hintText: '14:35',
                      prefixIcon: const Icon(Icons.access_time_rounded, color: AppColors.dustyRose),
                      errorText: _timeError,
                    ),
                    onChanged: (val) {
                      if (_timeError != null && DateTimeUtils.isValid24HourTime(val)) {
                        setState(() {
                          _timeError = null;
                        });
                      }
                    },
                  ),
                ),
                if (!isReadOnly) ...[
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _pickTimeFromDialog,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.lavender.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.schedule, size: 20, color: AppColors.deepPlum),
                          SizedBox(width: 6),
                          Text(
                            'Picker',
                            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.deepPlum),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Location
            Text(
              'Bump Location',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            if (isReadOnly)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowColor.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.blushPink.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.pin_drop_rounded, color: AppColors.dustyRose, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Location Area',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.plumTextSubtle,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedLocation,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepPlum,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              LocationSelector(
                selectedLocation: _selectedLocation,
                onLocationChanged: (newLoc) {
                  setState(() {
                    _selectedLocation = newLoc;
                  });
                },
              ),
            const SizedBox(height: 20),

            // Bump Count
            Text(
              'Movement Count',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            if (isReadOnly)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowColor.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.lavender.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_rounded, color: AppColors.deepPlum, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kicks / Bumps Count',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.plumTextSubtle,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$_bumpCount ${_bumpCount == 1 ? "bump" : "bumps"} felt',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.dustyRose,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              CountInput(
                count: _bumpCount,
                onCountChanged: (newCount) {
                  setState(() {
                    _bumpCount = newCount;
                  });
                },
              ),
            const SizedBox(height: 20),

            // Optional Note / Observation
            Text(
              isReadOnly ? 'Observation / Notes' : 'Optional Observation / Note',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              readOnly: isReadOnly,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: isReadOnly
                    ? 'No personal notes recorded.'
                    : 'e.g., Felt after drinking cold water or having lunch',
              ),
            ),
            const SizedBox(height: 32),

            // Save Entry Button (Shown only when creating a new bump, hidden when viewing existing record)
            if (!isReadOnly) ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveEntry,
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bookmark_added_rounded, size: 22),
                            SizedBox(width: 10),
                            Text(
                              'Save Entry',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ] else ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.sage.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_outlined, size: 16, color: AppColors.deepPlum),
                      SizedBox(width: 8),
                      Text(
                        'View-Only Record',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepPlum,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }
}
