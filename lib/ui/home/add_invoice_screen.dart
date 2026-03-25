import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/invoice_repository.dart';
import '../../services/ocr_service.dart';
import '../../theme/app_colors.dart';
import '../widgets/app_primary_button.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_text_field.dart';

class AddInvoiceScreen extends StatefulWidget {
  const AddInvoiceScreen({super.key});

  @override
  State<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
}

class _AddInvoiceScreenState extends State<AddInvoiceScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _vendorController = TextEditingController();

  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  final OcrService _ocrService = OcrService();
  final ImagePicker _imagePicker = ImagePicker();

  DateTime _issuedAt = DateTime.now();
  bool _isSaving = false;
  bool _isScanning = false;

  File? _selectedImage;
  String? _ocrStatus;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _vendorController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _issuedAt,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 5),
    );

    if (selected != null && mounted) {
      setState(() => _issuedAt = selected);
    }
  }

  Future<void> _pickReceiptImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile == null || !mounted) return;

      final File imageFile = File(pickedFile.path);

      setState(() {
        _selectedImage = imageFile;
        _isScanning = true;
        _ocrStatus = 'جاري قراءة الفاتورة...';
      });

      final OcrResult result = await _ocrService.scanReceipt(imageFile);

      if (!mounted) return;

      if (result.merchant.trim().isNotEmpty) {
        _titleController.text = result.merchant.trim();
        _vendorController.text = result.merchant.trim();
      }

      if (result.amount != null) {
        _amountController.text = result.amount!.toStringAsFixed(2);
      }

      if (result.date != null) {
        _issuedAt = result.date!;
      }

      setState(() {
        _ocrStatus = 'تمت قراءة الصورة. راجعي البيانات قبل الحفظ.';
      });
    } catch (_) {
      if (!mounted) return;
      _showMessage('تعذر قراءة الفاتورة من الصورة.');
      setState(() {
        _ocrStatus = 'تعذر قراءة الفاتورة.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _saveInvoice() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('لا توجد جلسة مستخدم نشطة.');
      return;
    }

    final String title = _titleController.text.trim();
    final String vendor = _vendorController.text.trim();
    final String amountText = _amountController.text.trim();
    final double? amount = double.tryParse(amountText);

    if (title.isEmpty) {
      _showMessage('أدخل عنوان الفاتورة.');
      return;
    }
    if (vendor.isEmpty) {
      _showMessage('أدخل اسم الجهة / المورد.');
      return;
    }
    if (amount == null || amount <= 0) {
      _showMessage('أدخل مبلغًا صحيحًا أكبر من صفر.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _invoiceRepository.addInvoice(
        ownerId: user.uid,
        title: title,
        amount: amount,
        vendor: vendor,
        issuedAt: _issuedAt,
      );

      if (!mounted) {
        return;
      }

      _showMessage('تمت إضافة الفاتورة بنجاح.');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        _showMessage('تعذر حفظ الفاتورة الآن. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBarTitle: 'إضافة فاتورة',
      title: 'فاتورة جديدة',
      subtitle: 'أدخل تفاصيل الفاتورة أو اقرأها من صورة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isScanning
                      ? null
                      : () => _pickReceiptImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('التقاط صورة'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isScanning
                      ? null
                      : () => _pickReceiptImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('اختيار من المعرض'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
          ),
          if (_selectedImage != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                _selectedImage!,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
          ],
          if (_ocrStatus != null) ...[
            const SizedBox(height: 10),
            Text(
              _ocrStatus!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          AppTextField(
            controller: _titleController,
            label: 'عنوان الفاتورة',
            hint: 'مثال: فاتورة كهرباء',
            icon: Icons.receipt_long_rounded,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _amountController,
            label: 'المبلغ',
            hint: '0.00',
            icon: Icons.payments_outlined,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            forceLtr: true,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _vendorController,
            label: 'المورد / الجهة',
            hint: 'اسم المتجر أو الشركة',
            icon: Icons.storefront_outlined,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Align(
              alignment: Alignment.centerRight,
              child: Text('تاريخ الإصدار: ${_formatDate(_issuedAt)}'),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: _isScanning ? 'جاري قراءة الفاتورة...' : 'حفظ الفاتورة',
            isLoading: _isSaving,
            onPressed: (_isSaving || _isScanning) ? null : _saveInvoice,
          ),
        ],
      ),
    );
  }
}