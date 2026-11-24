import 'package:flutter/material.dart';
import 'package:dw_baby_bump/core/constants/app_colors.dart';
import 'package:dw_baby_bump/models/bump_entry.dart';
import 'package:dw_baby_bump/features/counter/bump_entry_screen.dart';

class HistoryDateGroup extends StatelessWidget {
  final String date;
  final String displayDate;
  final List<BumpEntry> entries;

  const HistoryDateGroup({
    super.key,
    required this.date,
    required this.displayDate,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final dailyTotal = entries.fold<int>(0, (sum, item) => sum + item.count);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
          title: Text(
            displayDate,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.deepPlum,
            ),
          ),
          subtitle: Text(
            '${entries.length} ${entries.length == 1 ? 'record' : 'records'} logged',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.deepPlum.withOpacity(0.6),
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.blushPink,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$dailyTotal total',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.deepPlum,
              ),
            ),
          ),
          children: entries.map((entry) {
            return InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BumpEntryScreen(existingEntry: entry),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.warmCream.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight.withOpacity(0.7)),
                ),
                child: Row(
                  children: [
                    // Time Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.lavender.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        entry.time,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepPlum,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Location & Note
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.location,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepPlum,
                            ),
                          ),
                          if (entry.note != null && entry.note!.isNotEmpty)
                            Text(
                              entry.note!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.deepPlum.withOpacity(0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Individual count
                    Text(
                      '+${entry.count}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dustyRose,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.plumTextSubtle),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
