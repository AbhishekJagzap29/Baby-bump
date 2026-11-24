import 'package:flutter/material.dart';
import 'package:dw_baby_bump/core/constants/app_colors.dart';
import 'package:dw_baby_bump/core/constants/app_strings.dart';

class LocationSelector extends StatelessWidget {
  final String selectedLocation;
  final ValueChanged<String> onLocationChanged;

  const LocationSelector({
    super.key,
    required this.selectedLocation,
    required this.onLocationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.pin_drop_rounded, size: 18, color: AppColors.dustyRose),
            const SizedBox(width: 8),
            Text(
              'Bump Location (15 Zones)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedLocation,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.dustyRose),
              borderRadius: BorderRadius.circular(20),
              dropdownColor: Colors.white,
              elevation: 4,
              items: AppStrings.bumpLocations.map((String location) {
                final bool isExtreme = location.startsWith('Extreme');
                return DropdownMenuItem<String>(
                  value: location,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isExtreme ? AppColors.softRoseAccent : AppColors.dustyRose,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          location,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isExtreme ? FontWeight.w600 : FontWeight.w500,
                            color: AppColors.deepPlum,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  onLocationChanged(val);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Quick Chips for the top common zones
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              'Upper Left',
              'Center / Navel Area',
              'Upper Right',
              'Lower Center',
            ].map((loc) {
              final isSelected = selectedLocation == loc;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(loc),
                  selected: isSelected,
                  selectedColor: AppColors.blushPink,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? AppColors.dustyRose : AppColors.borderLight,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.deepPlum,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      onLocationChanged(loc);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
