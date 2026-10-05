class OverduePeriod {
  final int days;
  final String label;
  final String title;

  const OverduePeriod({
    required this.days,
    required this.label,
    required this.title,
  });

  static const List<OverduePeriod> predefined = [
    OverduePeriod(days: 7, label: 'أسبوع', title: 'أكثر من أسبوع (7 أيام)'),
    OverduePeriod(days: 15, label: '15 يوماً', title: 'أكثر من 15 يوماً'),
    OverduePeriod(days: 30, label: 'شهر', title: 'أكثر من شهر (30 يوماً)'),
    OverduePeriod(days: 60, label: 'شهرين', title: 'أكثر من شهرين (60 يوماً)'),
    OverduePeriod(days: 90, label: '3 أشهر', title: 'أكثر من 3 أشهر (90 يوماً)'),
    OverduePeriod(days: 180, label: '6 أشهر', title: 'أكثر من 6 أشهر (180 يوماً)'),
    OverduePeriod(days: 365, label: 'سنة', title: 'أكثر من سنة (365 يوماً)'),
  ];

  static const int defaultDays = 30;

  static String getLabelForDays(int days) {
    for (final p in predefined) {
      if (p.days == days) return p.title;
    }
    return 'أكثر من $days يوماً';
  }

  static String getShortLabelForDays(int days) {
    for (final p in predefined) {
      if (p.days == days) return p.label;
    }
    return '$days يوم';
  }
}
