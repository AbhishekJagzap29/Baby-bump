import 'package:flutter/material.dart';
import 'package:dw_baby_bump/core/constants/app_colors.dart';
import 'package:dw_baby_bump/models/bump_entry.dart';

class QuickStatsCard extends StatelessWidget {
  final List<BumpEntry> todayEntries;
  final UserLogCounts? serverStats;

  const QuickStatsCard({
    super.key,
    required this.todayEntries,
    this.serverStats,
  });

  @override
  Widget build(BuildContext context) {
    final totalCount = (serverStats != null && serverStats!.todayBumpsCount > 0)
        ? serverStats!.todayBumpsCount
        : todayEntries.fold<int>(0, (sum, item) => sum + item.count);
    final sessionsCount = (serverStats != null && serverStats!.todayLogsCount > 0)
        ? serverStats!.todayLogsCount
        : todayEntries.length;
    final lastTime = todayEntries.isNotEmpty ? todayEntries.first.time : '--:--';
    final topLocation = todayEntries.isNotEmpty ? todayEntries.first.location : 'None yet';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Overview",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.sage.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.successGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      serverStats != null ? 'Server Synced' : 'Live Tracking',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepPlum,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatMetricBox(
                  label: "Total Bumps",
                  value: '$totalCount',
                  icon: Icons.bubble_chart_rounded,
                  color: AppColors.blushPink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatMetricBox(
                  label: "Sessions Logged",
                  value: '$sessionsCount',
                  icon: Icons.history_toggle_off_rounded,
                  color: AppColors.lavender,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.warmCream,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.pin_drop_rounded, size: 18, color: AppColors.dustyRose),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Latest: $topLocation ($lastTime)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepPlum,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatMetricBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatMetricBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.deepPlum, size: 22),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.deepPlum,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.deepPlum.withOpacity(0.75),
            ),
          ),
        ],
      ),
    );
  }
}
