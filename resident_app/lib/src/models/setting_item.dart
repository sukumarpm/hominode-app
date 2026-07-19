// lib/src/models/setting_item.dart
// Data model for settings items

import 'package:flutter/material.dart';

enum SettingType {
  navigation,
  toggle,
  status,
  destructive,
}

class SettingItem {
  final String id;
  final String title;
  final SettingType type;
  final IconData? icon;
  final String? subtitle;
  final String? statusText;
  final Color? statusColor;
  final bool? toggleValue;
  final VoidCallback? onTap;
  final Function(bool)? onToggleChanged;

  const SettingItem({
    required this.id,
    required this.title,
    required this.type,
    this.icon,
    this.subtitle,
    this.statusText,
    this.statusColor,
    this.toggleValue,
    this.onTap,
    this.onToggleChanged,
  });

  SettingItem copyWith({
    String? id,
    String? title,
    SettingType? type,
    IconData? icon,
    String? subtitle,
    String? statusText,
    Color? statusColor,
    bool? toggleValue,
    VoidCallback? onTap,
    Function(bool)? onToggleChanged,
  }) {
    return SettingItem(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      subtitle: subtitle ?? this.subtitle,
      statusText: statusText ?? this.statusText,
      statusColor: statusColor ?? this.statusColor,
      toggleValue: toggleValue ?? this.toggleValue,
      onTap: onTap ?? this.onTap,
      onToggleChanged: onToggleChanged ?? this.onToggleChanged,
    );
  }
}

class SettingSection {
  final String title;
  final List<SettingItem> items;

  const SettingSection({
    required this.title,
    required this.items,
  });
}
