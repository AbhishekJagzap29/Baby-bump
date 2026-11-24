import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dw_baby_bump/core/constants/app_colors.dart';

class CountInput extends StatelessWidget {
  final int count;
  final ValueChanged<int> onCountChanged;

  const CountInput({
    super.key,
    required this.count,
    required this.onCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.touch_app_rounded, size: 18, color: AppColors.dustyRose),
            const SizedBox(width: 8),
            Text(
              'Bump Count (Manual Input)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
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
              // Decrement Button
              _CounterButton(
                icon: Icons.remove_rounded,
                onTap: () {
                  if (count > 1) {
                    HapticFeedback.lightImpact();
                    onCountChanged(count - 1);
                  }
                },
              ),
              const SizedBox(width: 16),
              // Count Display & Manual Number Formatter
              Expanded(
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        '$count',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepPlum,
                            ),
                      ),
                      Text(
                        count == 1 ? 'kick / bump' : 'kicks / bumps',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.plumTextSubtle,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Increment Button
              _CounterButton(
                icon: Icons.add_rounded,
                isPrimary: true,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onCountChanged(count + 1);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Preset Count Quick Chips
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [1, 2, 3, 5, 10].map((preset) {
            final isSelected = count == preset;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onCountChanged(preset);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.dustyRose : AppColors.lavender.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '+$preset',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.deepPlum,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const _CounterButton({
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? AppColors.dustyRose : AppColors.lavender.withOpacity(0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 26,
            color: isPrimary ? Colors.white : AppColors.deepPlum,
          ),
        ),
      ),
    );
  }
}
