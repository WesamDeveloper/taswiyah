import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';

class CreateInvoiceScreen extends StatelessWidget {
  const CreateInvoiceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'فاتورة أو دين جديد',
          style: TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'بيانات الفاتورة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Search Customer
            TextField(
              decoration: InputDecoration(
                labelText: 'ابحث عن العميل',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.person_add),
                  onPressed: () {},
                ),
              ),
            ).animate().fade().slideX(),

            const SizedBox(height: 24),

            // Amount
            const TextField(
              decoration: InputDecoration(
                labelText: 'المبلغ الإجمالي',
                prefixIcon: Icon(Icons.attach_money),
                suffixText: 'ر.ي',
              ),
              keyboardType: TextInputType.number,
            ).animate().fade(delay: 100.ms).slideX(),

            const SizedBox(height: 24),

            // Invoice Type
            const Text(
              'طريقة الدفع',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTypeSelector('نقدي / كاش', Icons.money, false),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTypeSelector(
                    'دين (آجل)',
                    Icons.receipt_long,
                    true,
                  ),
                ),
              ],
            ).animate().fade(delay: 200.ms).slideY(),

            const SizedBox(height: 32),

            // Due Date (only if Debt)
            TextField(
              decoration: const InputDecoration(
                labelText: 'تاريخ السداد المتوقع',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () async {
                // Open Date Picker
              },
            ).animate().fade(delay: 300.ms).slideX(),

            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text('حفظ وتسجيل'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ).animate().scale(delay: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector(String title, IconData icon, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryColor.withOpacity(0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade600,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade600,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
