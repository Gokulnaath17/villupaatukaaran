import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/discover_controller.dart';
import '../theme/theme_controller.dart';

/// Sticky top search bar with auto-suggestions
class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DiscoverController>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Search Input Container
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.cardSurface,
            border: Border.all(color: AppTheme.border, width: 1.0),
            borderRadius: BorderRadius.zero,
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.search, size: 20, color: AppTheme.yellowAccent),
                splashRadius: 18,
                tooltip: 'Search',
                onPressed: () => controller.performSearch(controller.searchInputController.text),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: controller.searchInputController,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Search songs, folk ballads, artists...',
                    hintStyle: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: controller.onSearchChanged,
                  onSubmitted: controller.performSearch,
                ),
              ),
              Obx(() {
                if (controller.activeQuery.value.isNotEmpty) {
                  return IconButton(
                    icon: const Icon(Icons.close, size: 16, color: AppTheme.textSecondary),
                    splashRadius: 16,
                    onPressed: controller.clearSearch,
                  );
                }
                return const SizedBox.shrink();
              }),
            ],
          ),
        ),

        // Auto-suggestions Dropdown (rendered immediately below input if available)
        Obx(() {
          final sugs = controller.suggestions;
          if (sugs.isEmpty || controller.isSearching.value) {
            return const SizedBox.shrink();
          }

          return Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: AppTheme.cardSurfaceElevated,
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.zero,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sugs.length.clamp(0, 6),
              itemBuilder: (ctx, i) {
                final suggestion = sugs[i];
                return InkWell(
                  onTap: () {
                    controller.searchInputController.text = suggestion;
                    controller.performSearch(suggestion);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.north_west, size: 14, color: AppTheme.textMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            suggestion,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

