import 'package:flutter/foundation.dart';

class Formatters {
  static String formatViews(int views, {bool isArabic = false}) {
    if (views >= 1000000000) {
      final val = (views / 1000000000).toStringAsFixed(1);
      return isArabic ? '$val مليار' : '${val}B';
    } else if (views >= 1000000) {
      final val = (views / 1000000).toStringAsFixed(1);
      return isArabic ? '$val مليون' : '${val}M';
    } else if (views >= 1000) {
      final val = (views / 1000).toStringAsFixed(1);
      return isArabic ? '$val ألف' : '${val}K';
    }
    return views.toString();
  }

  static String formatRelativeTime(DateTime? date, {bool isArabic = false}) {
    if (date == null) return '';
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return isArabic ? 'منذ $years سنة' : '$years yr ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return isArabic ? 'منذ $months شهر' : '$months mo ago';
    } else if (difference.inDays > 0) {
      return isArabic ? 'منذ ${difference.inDays} يوم' : '${difference.inDays} d ago';
    } else if (difference.inHours > 0) {
      return isArabic ? 'منذ ${difference.inHours} ساعة' : '${difference.inHours} h ago';
    } else if (difference.inMinutes > 0) {
      return isArabic ? 'منذ ${difference.inMinutes} دقيقة' : '${difference.inMinutes} m ago';
    }
    return isArabic ? 'الآن' : 'Just now';
  }

  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  static String parseIso8601Duration(String isoDuration) {
    if (isoDuration.isEmpty) return '';
    try {
      final match = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?').firstMatch(isoDuration);
      if (match == null) return isoDuration;

      final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
      final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;

      return formatDuration(Duration(hours: hours, minutes: minutes, seconds: seconds));
    } catch (e) {
      debugPrint('[Formatters] Error: $e');
      return isoDuration;
    }
  }

  static String formatBytes(int bytes, {int decimals = 1}) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}
