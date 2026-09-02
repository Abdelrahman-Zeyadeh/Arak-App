import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../models/download_task.dart';
import '../services/download_queue_service.dart';

class DownloadTaskTile extends StatelessWidget {
  final DownloadTask task;

  const DownloadTaskTile({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor = AppColors.primary;
    if (task.status == DownloadStatus.completed) statusColor = AppColors.success;
    if (task.status == DownloadStatus.failed) statusColor = AppColors.error;
    if (task.status == DownloadStatus.canceled) statusColor = Colors.grey;

    final progressPercent = (task.progress * 100).clamp(0, 100).toInt();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon or Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: task.thumbnailUrl.isNotEmpty
                      ? Image.network(task.thumbnailUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => _buildFallbackIcon())
                      : _buildFallbackIcon(),
                ),
              ),
              const SizedBox(width: 12),
              // Title & Format
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: task.format.isAudioOnly ? AppColors.audioGradient : AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            task.format.displayLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (task.speedStr.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E283E) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              task.speedStr,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        if (task.etaStr.isNotEmpty)
                          Text(
                            'ETA: ${task.etaStr}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Percentage Badge & Action
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    task.status == DownloadStatus.pending ? 'Queue' : '$progressPercent%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (task.status == DownloadStatus.downloading || task.status == DownloadStatus.pending)
                    InkWell(
                      onTap: () => DownloadQueueService().cancelTask(task.id),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.x, size: 14, color: AppColors.error),
                      ),
                    )
                  else if (task.status == DownloadStatus.failed || task.status == DownloadStatus.canceled)
                    InkWell(
                      onTap: () => DownloadQueueService().retryTask(task.id),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.rotateCcw, size: 14, color: AppColors.primary),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Animated Glowing Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: task.status == DownloadStatus.completed
                  ? 1.0
                  : (task.status == DownloadStatus.pending ? null : task.progress),
              backgroundColor: isDark ? const Color(0xFF1E283E) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation(statusColor),
              minHeight: 6,
            ),
          ),
          if (task.errorMessage != null && task.errorMessage!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              task.errorMessage!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: const Center(
        child: Icon(LucideIcons.download, size: 22, color: Colors.white),
      ),
    );
  }
}
