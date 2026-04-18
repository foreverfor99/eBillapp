import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../main.dart';
import '../../services/auth_service.dart';
import '../../services/invoice_repository.dart';
import '../../theme/app_colors.dart';
import '../auth/verify_email_otp_screen.dart';
import '../auth/verify_phone_screen.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _bootstrapUserDocument();
  }

  Future<void> _bootstrapUserDocument() async {
    try {
      await _authService.ensureCurrentUserDocument();
    } catch (_) {
      // Keep home usable even when self-heal fails temporarily.
    }
  }

  Future<void> _openAddInvoice() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddInvoiceScreen()),
    );
  }

  void _openWarranties() {
    setState(() => _selectedTabIndex = 1);
  }

  void _onBottomNavTap(int index) {
    setState(() => _selectedTabIndex = index);
  }

  void _closeDrawerIfOpen() {
    _scaffoldKey.currentState?.closeDrawer();
  }

  Future<void> _logoutFromDrawer() async {
    _closeDrawerIfOpen();
    try {
      await _authService.signOut();
    } catch (_) {}
    if (!mounted) {
      return;
    }
    rootNavKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _openEmailOtpFromDrawer() async {
    _closeDrawerIfOpen();
    final User? user = FirebaseAuth.instance.currentUser;
    final String? email = user?.email;
    if (email == null || email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد بريد مرتبط بالحساب.')),
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VerifyEmailOtpScreen(email: email),
      ),
    );
  }

  Future<void> _openPhoneVerifyFromDrawer() async {
    _closeDrawerIfOpen();
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final DocumentSnapshot<Map<String, dynamic>> snap = await FirebaseFirestore
        .instance
        .collection('users')
        .doc(user.uid)
        .get();
    final String phone =
        (snap.data()?['phoneNumber'] as String? ?? '').trim();
    if (phone.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أضف رقم الجوال من الملف الشخصي ثم ارجع لهنا.'),
        ),
      );
      setState(() => _selectedTabIndex = 2);
      return;
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VerifyPhoneScreen(phoneNumber: phone),
      ),
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

    final String appBarTitle = switch (_selectedTabIndex) {
      1 => 'الضمانات',
      2 => 'الملف الشخصي',
      _ => 'الرئيسية',
    };

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _MainNavigationDrawer(
          user: user,
          onPickHome: () {
            _closeDrawerIfOpen();
            setState(() => _selectedTabIndex = 0);
          },
          onPickWarranties: () {
            _closeDrawerIfOpen();
            setState(() => _selectedTabIndex = 1);
          },
          onPickProfile: () {
            _closeDrawerIfOpen();
            setState(() => _selectedTabIndex = 2);
          },
          onAddInvoice: () async {
            _closeDrawerIfOpen();
            await _openAddInvoice();
          },
          onEmailOtp: _openEmailOtpFromDrawer,
          onPhoneVerify: _openPhoneVerifyFromDrawer,
          onLogout: _logoutFromDrawer,
        ),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'القائمة',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: Row(
            children: [
              Image.asset(
                'assets/brand/wallet_logo.png',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  appBarTitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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
          child: IndexedStack(
            index: _selectedTabIndex,
            children: [
              _HomeDashboard(
                invoiceRepository: _invoiceRepository,
                ownerId: user.uid,
                onAddInvoice: _openAddInvoice,
                onOpenWarranty: _openWarranties,
              ),
              _WarrantyTab(
                invoiceRepository: _invoiceRepository,
                ownerId: user.uid,
              ),
              const ProfileScreen(),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedTabIndex,
          onTap: _onBottomNavTap,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.verified_user_outlined),
              activeIcon: Icon(Icons.verified_user_rounded),
              label: 'Warranty',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.invoiceRepository,
    required this.ownerId,
    required this.onAddInvoice,
    required this.onOpenWarranty,
  });

  final InvoiceRepository invoiceRepository;
  final String ownerId;
  final VoidCallback onAddInvoice;
  final VoidCallback onOpenWarranty;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _QuickActionsCard(
          onAddInvoice: onAddInvoice,
          onOpenWarranty: onOpenWarranty,
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<InvoiceRecord>>(
          stream: invoiceRepository.watchUserInvoices(ownerId),
          builder: (context, snapshot) {
            final List<InvoiceRecord> invoices = snapshot.data ?? const [];
            final int activeWarranties = invoices
                .where((invoice) => invoice.isWarrantyActive())
                .length;
            return _ActiveWarrantiesCard(count: activeWarranties);
          },
        ),
        const SizedBox(height: 16),
        Text(
          'فواتيري',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<InvoiceRecord>>(
          stream: invoiceRepository.watchUserInvoices(ownerId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              );
            }

            if (snapshot.hasError) {
              return const _ErrorCard(
                message: 'تعذر تحميل الفواتير الآن. حاول مرة أخرى.',
              );
            }

            final List<InvoiceRecord> invoices =
                List<InvoiceRecord>.from(snapshot.data ?? const []);
            if (invoices.isEmpty) {
              return _EmptyInvoicesState(onAddPressed: onAddInvoice);
            }

            return Column(
              children: invoices
                  .map((invoice) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _InvoiceCard(invoice: invoice),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _WarrantyTab extends StatelessWidget {
  const _WarrantyTab({
    required this.invoiceRepository,
    required this.ownerId,
  });

  final InvoiceRepository invoiceRepository;
  final String ownerId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InvoiceRecord>>(
      stream: invoiceRepository.watchUserInvoices(ownerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }

        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تحميل الضمانات الآن.'));
        }

        final List<InvoiceRecord> activeWarranties = (snapshot.data ?? const [])
            .where((invoice) => invoice.isWarrantyActive())
            .toList();

        if (activeWarranties.isEmpty) {
          return const Center(child: Text('لا توجد ضمانات سارية حاليًا.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) =>
              _WarrantyCard(invoice: activeWarranties[index]),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemCount: activeWarranties.length,
        );
      },
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.onAddInvoice,
    required this.onOpenWarranty,
  });

  final VoidCallback onAddInvoice;
  final VoidCallback onOpenWarranty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF1F6A47),
            Color(0xFF174F37),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2D8B5F)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'اختصارات سريعة للوصول للمهام الأساسية.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'إضافة فاتورة',
                  icon: Icons.add_rounded,
                  onPressed: onAddInvoice,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Warranty',
                  icon: Icons.verified_user_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: onOpenWarranty,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveWarrantiesCard extends StatelessWidget {
  const _ActiveWarrantiesCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_rounded,
            color: AppColors.accentSoft,
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Warranties',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count ضمان ما زال ساريًا',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.accentSoft,
                    fontWeight: FontWeight.w800,
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
                if (invoice.category.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'التصنيف: ${invoice.category}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
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
            invoice.amount.toStringAsFixed(2),
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
          if (invoice.category.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('التصنيف: ${invoice.category}'),
          ],
          const SizedBox(height: 4),
          Text('تاريخ انتهاء الضمان: ${_formatDate(invoice.warrantyExpiresAt)}'),
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

class _MainNavigationDrawer extends StatelessWidget {
  const _MainNavigationDrawer({
    required this.user,
    required this.onPickHome,
    required this.onPickWarranties,
    required this.onPickProfile,
    required this.onAddInvoice,
    required this.onEmailOtp,
    required this.onPhoneVerify,
    required this.onLogout,
  });

  final User user;
  final VoidCallback onPickHome;
  final VoidCallback onPickWarranties;
  final VoidCallback onPickProfile;
  final Future<void> Function() onAddInvoice;
  final Future<void> Function() onEmailOtp;
  final Future<void> Function() onPhoneVerify;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final String? email = user.email;
    return Drawer(
      backgroundColor: AppColors.backgroundElevated,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                border: const Border(
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'eBill Wallet',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    email ?? user.uid,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined, color: AppColors.accentSoft),
              title: const Text('الرئيسية'),
              onTap: onPickHome,
            ),
            ListTile(
              leading: const Icon(Icons.verified_user_outlined, color: AppColors.accentSoft),
              title: const Text('الضمانات'),
              onTap: onPickWarranties,
            ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded, color: AppColors.accentSoft),
              title: const Text('الملف الشخصي'),
              onTap: onPickProfile,
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded, color: AppColors.accentSoft),
              title: const Text('إضافة فاتورة'),
              onTap: () => onAddInvoice(),
            ),
            const Divider(color: AppColors.border),
            ListTile(
              leading: const Icon(Icons.mark_email_unread_outlined, color: AppColors.accentSoft),
              title: const Text('تحقق البريد (OTP)'),
              subtitle: const Text('يتطلب تشغيل خادم البريد'),
              onTap: () => onEmailOtp(),
            ),
            ListTile(
              leading: const Icon(Icons.phone_android_rounded, color: AppColors.accentSoft),
              title: const Text('تحقق الجوال'),
              subtitle: const Text('رقم الجوال من بياناتك في الملف الشخصي'),
              onTap: () => onPhoneVerify(),
            ),
            const Divider(color: AppColors.border),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.danger)),
              onTap: () => onLogout(),
            ),
          ],
        ),
      ),
    );
  }
}
