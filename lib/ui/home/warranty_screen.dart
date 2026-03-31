import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/invoice_repository.dart';
import '../../theme/app_colors.dart';

class WarrantyScreen extends StatelessWidget {
  const WarrantyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('لا توجد جلسة مستخدم نشطة.')),
      );
    }

    final InvoiceRepository repository = InvoiceRepository();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الضمانات')),
        body: StreamBuilder<List<InvoiceRecord>>(
          stream: repository.watchUserInvoices(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              );
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text('تعذر تحميل الضمانات الآن.'),
              );
            }

            final List<InvoiceRecord> activeWarranties = (snapshot.data ?? const [])
                .where((invoice) => invoice.isWarrantyActive())
                .toList();

            if (activeWarranties.isEmpty) {
              return const Center(
                child: Text('لا توجد ضمانات سارية حاليًا.'),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) =>
                  _WarrantyCard(invoice: activeWarranties[index]),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: activeWarranties.length,
            );
          },
        ),
      ),
    );
  }
}

class _WarrantyCard extends StatelessWidget {
  const _WarrantyCard({required this.invoice});

  final InvoiceRecord invoice;

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            invoice.title.isEmpty ? 'فاتورة بدون عنوان' : invoice.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text('المورد: ${invoice.vendor.isEmpty ? "-" : invoice.vendor}'),
          const SizedBox(height: 4),
          Text('تاريخ انتهاء الضمان: ${_formatDate(invoice.warrantyExpiresAt)}'),
        ],
      ),
    );
  }
}
