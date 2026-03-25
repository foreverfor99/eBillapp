import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceRecord {
  const InvoiceRecord({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.amount,
    required this.vendor,
    required this.category,
    required this.hasWarranty,
    required this.warrantyExp,
    required this.issuedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String title;
  final double amount;
  final String vendor;
  final String category;
  final bool hasWarranty;
  final DateTime? warrantyExp;
  final DateTime? issuedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory InvoiceRecord.fromDocument(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final Map<String, dynamic> data = doc.data();
    return InvoiceRecord(
      id: doc.id,
      ownerId: (data['ownerId'] as String? ?? '').trim(),
      title: (data['title'] as String? ?? '').trim(),
      amount: _toDouble(data['amount']),
      vendor: (data['vendor'] as String? ?? '').trim(),
      category: (data['category'] as String? ?? '').trim(),
      hasWarranty: _toBool(data['hasWarranty']),
      warrantyExp: _toDateTime(data['warrantyExp']),
      issuedAt: _toDateTime(data['issuedAt']),
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  static double _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  static bool _toBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.toLowerCase().trim() == 'true';
    }
    return false;
  }
}

class InvoiceRepository {
  InvoiceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String invoicesCollection = 'invoices';

  final FirebaseFirestore _firestore;

  Stream<List<InvoiceRecord>> watchUserInvoices(String ownerId) {
    return _firestore
        .collection(invoicesCollection)
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) {
      final List<InvoiceRecord> records = snapshot.docs
          .map(InvoiceRecord.fromDocument)
          .where((invoice) => invoice.ownerId == ownerId)
          .toList();

      records.sort((a, b) {
        final DateTime aDate = a.issuedAt ?? a.createdAt ?? DateTime(1970);
        final DateTime bDate = b.issuedAt ?? b.createdAt ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });

      return records;
    });
  }

  Future<void> addInvoice({
    required String ownerId,
    required String title,
    required double amount,
    required String vendor,
    required DateTime issuedAt,
    String category = '',
    bool hasWarranty = false,
    DateTime? warrantyExp,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref =
    _firestore.collection(invoicesCollection).doc();

    await ref.set(
      <String, dynamic>{
        'ownerId': ownerId,
        'title': title.trim(),
        'amount': amount,
        'vendor': vendor.trim(),
        'category': category.trim(),
        'hasWarranty': hasWarranty,
        'warrantyExp':
        warrantyExp != null ? Timestamp.fromDate(warrantyExp) : null,
        'issuedAt': Timestamp.fromDate(issuedAt),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<int> countInvoicesForUser(String ownerId) async {
    final AggregateQuerySnapshot aggregate = await _firestore
        .collection(invoicesCollection)
        .where('ownerId', isEqualTo: ownerId)
        .count()
        .get();
    return aggregate.count ?? 0;
  }
}