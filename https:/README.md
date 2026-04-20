# eBill App | تطبيق eBill
eBill is a smart invoice management app built with **Flutter** and  
It helps users scan receipts, extract invoice data automatically usingglish

eB track warranties, and manage expenses through a modern mobile interface.

### Features
- Scan receipts using camera or gallery
- Extract invoice data automatically with OCR
- Editable invoice form after scanning
- Automatic category filling
- Manual invoice entry
- Warranty support with expiry date
- Active Warranties section
- Warranty quick action
- Bottom Navigation Bar
- Receipt-style invoice UI
- Monthly expense overview and chart

### Tech Stack
- Flutter
- Firebase Authentication
- Cloud Firestore
- Google ML Kit OCR
- fl_chart

### Implemented Enhancements
#### Invoice Module
- Added OCR integration to read invoice data from images
- Auto-filled:
  - title
  - vendor
  - amount
  - date
  - category
- Added editable category field in Add Invoice
- Improved invoice UI to simulate a real paper receipt

#### Warranty Module
- Added warranty toggle in Add Invoice
- Added warranty expiry date picker
- Saved warranty data with invoices
- Added Active Warranties card on Home
- Added Warranty quick action
- Added Warranty screen with countdown display

#### Navigation & UI
- Added Bottom Navigation Bar
- Improved invoice display design
- Improved home screen usability and structure

### How to Run
```bash
flutter pub get
flutter run
Notes
Firebase must be configured before running the project
OCR results depend on image quality and text clarity
Warranty data appears only if enabled while creating the invoice


تطبيق eBill هو تطبيق ذكي لإدارة الفواتير تم تطويره باستخدام Flutter و Firebase.
يساعد المستخدم على تصوير الفواتير، استخراج البيانات تلقائيًا باستخدام OCR، تتبع الضمان، وإدارة المصروفات من خلال واجهة حديثة.
المميزات
تصوير الفواتير بالكاميرا أو اختيارها من المعرض
استخراج بيانات الفاتورة تلقائيًا عبر OCR
نموذج قابل للتعديل بعد قراءة الفاتورة
تعبئة التصنيف تلقائيًا
إضافة الفاتورة يدويًا
دعم الضمان مع تاريخ الانتهاء
قسم الضمانات النشطة
زر سريع للضمان
شريط تنقل سفلي
تصميم عرض الفاتورة بشكل يشبه الفاتورة الحقيقية
ملخص للمصروفات مع رسم بياني شهري
التقنيات المستخدمة
Flutter
Firebase Authentication
Cloud Firestore
Google ML Kit OCR
fl_chart
التطويرات المنفذة
قسم الفواتير
ربط OCR لقراءة بيانات الفاتورة من الصور
تعبئة تلقائية للبيانات التالية:
عنوان الفاتورة
المورد
المبلغ
التاريخ
التصنيف
إضافة حقل التصنيف داخل صفحة إضافة الفاتورة
تحسين شكل الفاتورة ليحاكي الفاتورة الورقية الحقيقية
قسم الضمان
إضافة خيار تفعيل الضمان داخل صفحة إضافة الفاتورة
إضافة اختيار تاريخ انتهاء الضمان
حفظ بيانات الضمان مع الفاتورة
إضافة بطاقة الضمانات النشطة في الصفحة الرئيسية
إضافة زر سريع للضمان
إضافة شاشة خاصة بالضمان مع عرض المدة المتبقية
التنقل والواجهة
إضافة شريط تنقل سفلي
تحسين تصميم عرض الفاتورة
تحسين تنظيم الصفحة الرئيسية وسهولة الاستخدام
طريقة التشغيل
flutter pub get
flutter run
