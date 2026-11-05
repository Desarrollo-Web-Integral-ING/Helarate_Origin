import 'package:flutter/material.dart';

class BusinessIconHelper {
  static const Map<String, IconData> icons = {
    'storefront': Icons.storefront_rounded,
    'restaurant': Icons.restaurant_rounded,
    'coffee': Icons.local_cafe_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'icecream': Icons.icecream_rounded,
    'fastfood': Icons.fastfood_rounded,
    'fitness_center': Icons.fitness_center_rounded,
    'local_pharmacy': Icons.local_pharmacy_rounded,
    'directions_car': Icons.directions_car_rounded,
    'content_cut': Icons.content_cut_rounded,
    'devices': Icons.devices_other_rounded,
    'work': Icons.business_center_rounded,
  };

  static IconData getIcon(String? iconKey) {
    if (iconKey == null) return Icons.storefront_rounded;
    return icons[iconKey] ?? Icons.storefront_rounded;
  }
}

