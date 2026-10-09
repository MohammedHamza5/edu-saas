import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class FolderColorItem {
  final String id;
  final String nameKey;
  final String hex;
  final Color color;

  const FolderColorItem({
    required this.id,
    required this.nameKey,
    required this.hex,
    required this.color,
  });
}

class FolderColorPalette {
  FolderColorPalette._();

  static const List<FolderColorItem> items = [
    FolderColorItem(
      id: 'indigo',
      nameKey: 'colorIndigo',
      hex: '#6366F1',
      color: Color(0xFF6366F1),
    ),
    FolderColorItem(
      id: 'cyan',
      nameKey: 'colorCyan',
      hex: '#06B6D4',
      color: Color(0xFF06B6D4),
    ),
    FolderColorItem(
      id: 'emerald',
      nameKey: 'colorEmerald',
      hex: '#10B981',
      color: Color(0xFF10B981),
    ),
    FolderColorItem(
      id: 'amber',
      nameKey: 'colorAmber',
      hex: '#F59E0B',
      color: Color(0xFFF59E0B),
    ),
    FolderColorItem(
      id: 'ruby',
      nameKey: 'colorRuby',
      hex: '#EF4444',
      color: Color(0xFFEF4444),
    ),
    FolderColorItem(
      id: 'violet',
      nameKey: 'colorViolet',
      hex: '#8B5CF6',
      color: Color(0xFF8B5CF6),
    ),
    FolderColorItem(
      id: 'rose',
      nameKey: 'colorRose',
      hex: '#EC4899',
      color: Color(0xFFEC4899),
    ),
    FolderColorItem(
      id: 'slate',
      nameKey: 'colorSlate',
      hex: '#64748B',
      color: Color(0xFF64748B),
    ),
  ];

  static Color getFolderColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.primary;
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('0xFF$clean'));
      } else if (clean.length == 8) {
        return Color(int.parse('0x$clean'));
      }
    } catch (_) {}
    return AppColors.primary;
  }

  static Color getFolderBgColor(String? hex) {
    return getFolderColor(hex).withValues(alpha: 0.12);
  }

  static Color getFolderBorderColor(String? hex) {
    return getFolderColor(hex).withValues(alpha: 0.35);
  }
}
