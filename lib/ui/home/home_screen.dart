import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/invoice_repository.dart';
import '../../theme/app_colors.dart';
import '../profile/profile_screen.dart';
import '../widgets/app_button.dart';
import 'add_invoice_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final InvoiceRepository _invoiceRepository = InvoiceRepository();

  @override
  void initState() {
    super.initState();
    _bootstrapUserDocument();
  }

  Future<void> _bootstrapUserDocument() async {
    try {
      await _authService.ensureCurrentUserDocument();
    } catch (_) {
      // Keep the home screen usable even if this fails temporarily.
    }
  }

  Future<void> _openAddInvoice() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddInvoiceScreen()),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('لا توجد جلسة مستخدم نشطة.'),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset(
                'assets/brand/wallet_logo.png',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              const Text('الرئيسية'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'الملف الشخصي',
              onPressed: _openProfile,
              icon: const Icon(Icons.person_outline_rounded),
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0A120F),
                AppColors.background,
                Color(0xFF050A08),
              ],
            ),
          ),
          child: StreamBuilder<List<InvoiceRecord>>(
            stream: _invoiceRepository.watchUserInvoices(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                );
              }

              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: _ErrorCard(
                    message: 'تعذر تحميل الفواتير الآن. حاول مرة أخرى.',
                  ),
                );
              }

              final List<InvoiceRecord> invoices =
              List<InvoiceRecord>.from(snapshot.data ?? const []);

              final double totalAmount = invoices.fold(
                0.0,
                    (sum, invoice) => sum + invoice.amount,
              );

              final int invoiceCount = invoices.length;

              final DateTime now = DateTime.now();
              final List<InvoiceRecord> monthlyInvoices =
              invoices.where((invoice) {
                final DateTime? date = invoice.issuedAt ?? invoice.createdAt;
                if (date == null) return false;
                return date.year == now.year && date.month == now.month;
              }).toList();

              final double monthlyAmount = monthlyInvoices.fold(
                0.0,
                    (sum, invoice) => sum + invoice.amount,
              );

              final InvoiceRecord? latestInvoice =
              invoices.isNotEmpty ? invoices.first : null;

              final List<double> weeklyBars = _buildWeeklyBars(monthlyInvoices);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _DashboardHeader(
                    userName: user.displayName != null &&
                        user.displayName!.trim().isNotEmpty
                        ? user.displayName!.trim()
                        : 'مستخدم eBill',
                  ),
                  const SizedBox(height: 18),
                  _SpendingHeroCard(
                    totalAmount: monthlyAmount,
                  ),
                  const SizedBox(height: 18),
                  _QuickActionsSection(
                    onAddInvoice: _openAddInvoice,
                  ),
                  const SizedBox(height: 18),
                  _DashboardStatsSection(
                    invoiceCount: invoiceCount,
                    totalAmount: totalAmount,
                    latestInvoiceTitle: latestInvoice?.title ?? '-',
                    latestInvoiceAmount: latestInvoice?.amount ?? 0.0,
                  ),
                  const SizedBox(height: 18),
                  _MonthlyChartCard(values: weeklyBars),
                  const SizedBox(height: 18),
                  Text(
                    'آخر الفواتير',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (invoices.isEmpty)
                    _EmptyInvoicesState(onAddPressed: _openAddInvoice)
                  else
                    Column(
                      children: invoices
                          .take(5)
                          .map(
                            (invoice) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _InvoiceCard(invoice: invoice),
                        ),
                      )
                          .toList(),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<double> _buildWeeklyBars(List<InvoiceRecord> invoices) {
    final List<double> buckets = [0, 0, 0, 0];

    for (final invoice in invoices) {
      final DateTime? date = invoice.issuedAt ?? invoice.createdAt;
      if (date == null) continue;

      final int day = date.day;
      if (day <= 7) {
        buckets[0] += invoice.amount;
      } else if (day <= 14) {
        buckets[1] += invoice.amount;
      } else if (day <= 21) {
        buckets[2] += invoice.amount;
      } else {
        buckets[3] += invoice.amount;
      }
    }

    return buckets;
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good Evening 👋',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your spending overview, $userName',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SpendingHeroCard extends StatelessWidget {
  const _SpendingHeroCard({required this.totalAmount});

  final double totalAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF8B6A42),
            Color(0xFFB39160),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.credit_card,
            size: 35,
            color: Colors.white,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SAR ${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Total spent this month',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection({
    required this.onAddInvoice,
  });

  final VoidCallback onAddInvoice;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 15),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
          childAspectRatio: 2.5,
          children: [
            _ActionCard(
              icon: Icons.camera_alt,
              title: 'Scan',
              onTap: onAddInvoice,
            ),
            const _ActionCard(
              icon: Icons.search,
              title: 'Search',
            ),
            const _ActionCard(
              icon: Icons.upload,
              title: 'Export',
            ),
            const _ActionCard(
              icon: Icons.settings,
              title: 'Settings',
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.backgroundElevated.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF8B6A42)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardStatsSection extends StatelessWidget {
  const _DashboardStatsSection({
    required this.invoiceCount,
    required this.totalAmount,
    required this.latestInvoiceTitle,
    required this.latestInvoiceAmount,
  });

  final int invoiceCount;
  final double totalAmount;
  final String latestInvoiceTitle;
  final double latestInvoiceAmount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'عدد الفواتير',
                value: invoiceCount.toString(),
                icon: Icons.receipt_long_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                title: 'إجمالي الصرف',
                value: totalAmount.toStringAsFixed(2),
                icon: Icons.payments_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundElevated.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'آخر فاتورة',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                latestInvoiceTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${latestInvoiceAmount.toStringAsFixed(2)} ر.س',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.accentSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accentSoft),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyChartCard extends StatelessWidget {
  const _MonthlyChartCard({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final double maxValue = values.isEmpty
        ? 10
        : values.reduce((a, b) => a > b ? a : b);

    final double maxY = maxValue <= 0 ? 10 : maxValue * 1.2;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'March Spending',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const labels = ['W1', 'W2', 'W3', 'W4'];
                        final int index = value.toInt();
                        if (index < 0 || index >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels[index],
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(
                  values.length,
                      (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: values[i],
                        color: const Color(0xFF8B6A42),
                        width: 12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});

  final InvoiceRecord invoice;

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.title.isEmpty ? 'فاتورة بدون عنوان' : invoice.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  invoice.vendor.isEmpty ? 'مورد غير محدد' : invoice.vendor,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'تاريخ الإصدار: ${_formatDate(invoice.issuedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${invoice.amount.toStringAsFixed(2)} ر.س',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.accentSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyInvoicesState extends StatelessWidget {
  const _EmptyInvoicesState({required this.onAddPressed});

  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_rounded,
            size: 42,
            color: AppColors.accentSoft,
          ),
          const SizedBox(height: 10),
          Text(
            'لا توجد فواتير حتى الآن',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'ابدأ الآن بإضافة أول فاتورة لتحصل على سجل مرتب وواضح.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'إضافة أول فاتورة',
            icon: Icons.add_circle_outline_rounded,
            onPressed: onAddPressed,
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.danger),
      ),
    );
  }
}