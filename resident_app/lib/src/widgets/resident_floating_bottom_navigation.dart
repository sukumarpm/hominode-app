import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ResidentNavigationItem {
  const ResidentNavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Frosted floating navigation used by the Resident shell.
class ResidentFloatingBottomNavigation extends StatelessWidget {
  const ResidentFloatingBottomNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<ResidentNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: EdgeInsets.only(left: 5.w, right: 5.w, bottom: 7.h),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(35.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 13, sigmaY: 13),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .78),
            borderRadius: BorderRadius.circular(35.r),
            border: Border.all(color: Colors.white.withValues(alpha: .96)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF193A65).withValues(alpha: .15),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: _NavigationButton(
                    item: items[index],
                    selected: selectedIndex == index,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ResidentNavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: item.label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('resident-nav-button-${item.label}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(32.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 0, vertical: 4.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                key: selected
                    ? ValueKey('resident-nav-active-${item.label}')
                    : null,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: 42.w,
                height: 35.h,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF24364B)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                  size: 22.w,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                item.label,
                softWrap: true,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF172B4D)
                      : const Color(0xFF52627A),
                  fontSize: 10.sp,
                  height: 1.1,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
