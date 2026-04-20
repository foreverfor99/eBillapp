import 'package:flutter/material.dart';
import '../../services/invoice_repository.dart';

class ReceiptInvoiceCard extends StatelessWidget {
  const ReceiptInvoiceCard({super.key, required this.invoice});

  final InvoiceRecord invoice;

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE7DCCB),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4E9D8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF8B6A42),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.title.isEmpty
                              ? 'فاتورة بدون عنوان'
                              : invoice.title,
                          style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF2B241C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          invoice.vendor.isEmpty
                              ? 'مورد غير محدد'
                              : invoice.vendor,
                          style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF6C6257),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${invoice.amount.toStringAsFixed(2)} ر.س',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF8B6A42),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: List.generate(
                  36,
                      (index) => Expanded(
                    child: Container(
                      height: 1.2,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      color: index.isEven
                          ? const Color(0xFFD7C7B2)
                          : Colors.transparent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ReceiptMetaItem(
                      label: 'التاريخ',
                      value: _formatDate(invoice.issuedAt),
                    ),
                  ),
                  if (invoice.category.trim().isNotEmpty)
                    Expanded(
                      child: _ReceiptMetaItem(
                        label: 'الفئة',
                        value: invoice.category,
                      ),
                    ),
                  if (invoice.hasWarranty)
                    Expanded(
                      child: _ReceiptMetaItem(
                        label: 'الضمان',
                        value: invoice.warrantyExp != null
                            ? _formatDate(invoice.warrantyExp)
                            : 'يوجد ضمان',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: 78,
          left: -11,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5F5),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          top: 78,
          right: -11,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5F5),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReceiptMetaItem extends StatelessWidget {
  const _ReceiptMetaItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF8A8177),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2B241C),
            ),
          ),
        ],
      ),
    );
  }
}