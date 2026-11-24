import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dw_baby_bump/core/constants/app_colors.dart';
import 'package:dw_baby_bump/core/utils/date_time_utils.dart';
import 'package:dw_baby_bump/database/bump_repository.dart';
import '../counter/bump_entry_screen.dart';
import 'widgets/history_date_group.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedData = ref.watch(groupedHistoryProvider);
    final serverStats = ref.watch(userLogCountsProvider);
    final sortedDates = groupedData.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Descending order (newest first)

    final calculatedTotal = groupedData.values
        .expand((list) => list)
        .fold<int>(0, (sum, item) => sum + item.count);
    final totalAllBumps = (serverStats != null && serverStats.totalBumpsCount > 0)
        ? serverStats.totalBumpsCount
        : calculatedTotal;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: const Text('Bump History'),
      ),
      body: groupedData.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: const BoxDecoration(
                        color: AppColors.blushPink,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        size: 44,
                        color: AppColors.dustyRose,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No bump records yet',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your baby bump logs will be grouped here day-by-day with daily totals and times.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.deepPlum.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const BumpEntryScreen()),
                        );
                      },
                      child: const Text('Log First Bump'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(bumpEntriesProvider.notifier).loadEntries();
              },
              color: AppColors.dustyRose,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // Summary Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.lavender, AppColors.blushPink],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Overall Movement Logged',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.deepPlum,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$totalAllBumps Total Bumps',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.deepPlum,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${sortedDates.length} ${sortedDates.length == 1 ? 'Day' : 'Days'}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dustyRose,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Grouped List of dates
                  ...sortedDates.map((date) {
                    final entries = groupedData[date]!;
                    final displayDate = DateTimeUtils.friendlyRelativeDate(date);
                    return HistoryDateGroup(
                      date: date,
                      displayDate: displayDate,
                      entries: entries,
                    );
                  }),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
