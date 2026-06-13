import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../customers/presentation/customers_screen.dart';
import '../../debts/presentation/debts_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../whatsapp/presentation/whatsapp_setup_screen.dart';
import '../controllers/dashboard_controller.dart';

class DashboardScreen extends StatelessWidget {
  DashboardScreen({Key? key}) : super(key: key);

  final DashboardController controller = Get.put(DashboardController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceLight,
        elevation: 0,
        title: const Text(
          'نظرة عامة',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        actions: [
          InkWell(
            onTap: () => Get.to(() => const ProfileScreen()),
            child: Obx(() {
              IconData iconData = Icons.person;
              switch (controller.avatarIcon.value) {
                case 'store': iconData = Icons.store; break;
                case 'business': iconData = Icons.business; break;
                case 'account_circle': iconData = Icons.account_circle; break;
                case 'face': iconData = Icons.face; break;
                case 'shopping_bag': iconData = Icons.shopping_bag; break;
              }
              return CircleAvatar(
                backgroundColor: AppTheme.primaryColor,
                child: Icon(iconData, color: Colors.white),
              );
            }),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.fetchStats,
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() => Text(
                'أهلاً بك، ${controller.userName.value} 👋',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              )).animate().fade().slideX(),
              const SizedBox(height: 8),
              Obx(() => Text(
                'إليك ملخص التحصيلات والديون لـ ${controller.companyName.value}.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              )).animate().fade(delay: 100.ms).slideX(),

              const SizedBox(height: 24),

              // KPI Cards
              Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiCard(
                            'إجمالي الديون',
                            '${controller.totalDebts.value.toStringAsFixed(0)} ر.ي',
                            Icons.account_balance_wallet,
                            AppTheme.danger,
                            200,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildKpiCard(
                            'تم تحصيله',
                            '${controller.totalCollected.value.toStringAsFixed(0)} ر.ي',
                            Icons.trending_up,
                            AppTheme.secondaryColor,
                            300,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiCard(
                            'فواتير متأخرة',
                            '${controller.overdueCount.value}',
                            Icons.warning_amber_rounded,
                            Colors.orange,
                            400,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildKpiCard(
                            'عملاء نشطين',
                            '${controller.activeCustomers.value}',
                            Icons.people_alt_outlined,
                            AppTheme.primaryColor,
                            500,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }),
              const SizedBox(height: 32),

              // Chart Section
              const Text(
                'التدفق النقدي (التحصيلات مقابل الديون الجديدة)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ).animate().fade(delay: 600.ms),
              const SizedBox(height: 16),

              Obx(
                    () => Container(
                      height: 300,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _buildChart(),
                    ),
                  )
                  .animate()
                  .fade(delay: 700.ms)
                  .scale(begin: const Offset(0.95, 0.95)),

              const SizedBox(height: 32),

              const Text(
                'أحدث العمليات',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ).animate().fade(delay: 800.ms),
              const SizedBox(height: 16),

              Obx(() {
                if (controller.recentActivity.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'لا توجد عمليات سابقة. قم بإضافة عميل ثم فاتورة دين لتبدأ.',
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.recentActivity.length,
                  itemBuilder: (context, index) {
                    final act = controller.recentActivity[index];
                    final isDebt = act['type'] == 'debt';
                    return _buildActivityItem(
                      act['title'],
                      '${act['amount']} ر.ي',
                      act['created_at'].toString().substring(
                        0,
                        10,
                      ), // Simplistic date
                      isDebt ? AppTheme.danger : AppTheme.secondaryColor,
                      isDebt ? Icons.receipt_rounded : Icons.payments,
                      800 + (index * 100),
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey.shade400,
        onTap: (index) async {
          if (index == 1) {
            await Get.to(() => CustomersScreen());
            controller.fetchStats();
          } else if (index == 2) {
            await Get.to(() => WhatsappSetupScreen());
          } else if (index == 3) {
            await Get.to(() => DebtsScreen());
            controller.fetchStats();
          } else if (index == 4) {
            await Get.to(() => const ProfileScreen());
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'العملاء'),
          BottomNavigationBarItem(
            icon: CircleAvatar(
              backgroundColor: AppTheme.primaryColor,
              child: Icon(Icons.qr_code_scanner, color: Colors.white),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'الديون',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: 'المزيد',
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    String title,
    String value,
    IconData icon,
    Color color,
    int delayMs,
  ) {
    return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        )
        .animate()
        .fade(delay: Duration(milliseconds: delayMs))
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildActivityItem(
    String title,
    String amount,
    String time,
    Color amountColor,
    IconData icon,
    int delayMs,
  ) {
    return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.backgroundLight,
                child: Icon(
                  icon,
                  color: amountColor.withOpacity(0.8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                amount,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: amountColor,
                ),
              ),
            ],
          ),
        )
        .animate()
        .fade(delay: Duration(milliseconds: delayMs))
        .slideX(begin: 0.1, end: 0);
  }

  Widget _buildChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey.shade200, strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                String title = '';

                switch (value.toInt()) {
                  case 1:
                    title = 'السبت';
                    break;
                  case 3:
                    title = 'الإثنين';
                    break;
                  case 5:
                    title = 'الأربعاء';
                    break;
                  case 7:
                    title = 'الجمعة';
                    break;
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value == 0)
                  return const Text(
                    '0',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  );
                String label;
                if (value >= 1000) {
                  label = '${(value / 1000).toStringAsFixed(1)}k';
                } else {
                  label = value.toInt().toString();
                }
                return Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                );
              },
              reservedSize: 42,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY:
            controller.chartCollections.fold<double>(
                      0,
                      (max, val) => val > max ? val : max,
                    ) +
                    controller.chartDebts.fold<double>(
                      0,
                      (max, val) => val > max ? val : max,
                    ) ==
                0
            ? 100
            : [
                    controller.chartCollections.fold<double>(
                      0,
                      (max, val) => val > max ? val : max,
                    ),
                    controller.chartDebts.fold<double>(
                      0,
                      (max, val) => val > max ? val : max,
                    ),
                  ].reduce((a, b) => a > b ? a : b) *
                  1.2,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              controller.chartCollections.length,
              (index) =>
                  FlSpot(index.toDouble(), controller.chartCollections[index]),
            ),
            isCurved: true,
            color: AppTheme.secondaryColor, // Collections
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.secondaryColor.withOpacity(0.1),
            ),
          ),
          LineChartBarData(
            spots: List.generate(
              controller.chartDebts.length,
              (index) => FlSpot(index.toDouble(), controller.chartDebts[index]),
            ),
            isCurved: true,
            color: AppTheme.danger, // New Debts
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}
