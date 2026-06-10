import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../theme/app_theme.dart';

class ExportDialog extends StatefulWidget {
  final Function(String format, DateTime? startDate, DateTime? endDate) onExport;

  const ExportDialog({Key? key, required this.onExport}) : super(key: key);

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  String _selectedFormat = 'pdf';
  String _selectedPeriod = 'all';

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'تصدير كشف حساب',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Format Selection
            const Text('صيغة الملف', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildOptionCard(
                    title: 'PDF',
                    icon: Icons.picture_as_pdf,
                    isSelected: _selectedFormat == 'pdf',
                    color: Colors.red,
                    onTap: () => setState(() => _selectedFormat = 'pdf'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOptionCard(
                    title: 'Excel',
                    icon: Icons.table_view,
                    isSelected: _selectedFormat == 'excel',
                    color: Colors.green,
                    onTap: () => setState(() => _selectedFormat = 'excel'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Period Selection
            const Text('الفترة الزمنية', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedPeriod,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  items: const [
                    DropdownMenuItem(value: 'today', child: Text('اليوم')),
                    DropdownMenuItem(value: 'week', child: Text('آخر أسبوع')),
                    DropdownMenuItem(value: 'month', child: Text('آخر شهر')),
                    DropdownMenuItem(value: 'year', child: Text('آخر سنة')),
                    DropdownMenuItem(value: 'all', child: Text('جميع البيانات')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedPeriod = val;
                        _calculateDates();
                      });
                    }
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back();
                      widget.onExport(_selectedFormat, _startDate, _endDate);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                    child: const Text('تصدير الآن', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? color : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _calculateDates() {
    final now = DateTime.now();
    _endDate = now;
    
    switch (_selectedPeriod) {
      case 'today':
        _startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        _startDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        _startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'year':
        _startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      case 'all':
        _startDate = null;
        _endDate = null;
        break;
    }
  }
}
