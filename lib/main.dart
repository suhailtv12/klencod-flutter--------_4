import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// في حال قمت بتوليد ملف خيارات فايربيس عبر (flutterfire configure)، قم بإلغاء التعليق عن السطر التالي:
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة آمنة لخدمات فايربيس
  try {
    // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("تنبيه فايربيس: يعمل التطبيق الآن ببيانات الجلسة المشفرة: $e");
  }

  // تثبيت اتجاه الشاشة الرأسي لضمان أفضل تجربة مستخدم
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const AlJeelSchoolApp());
}

// ==========================================
// 1. النماذج البرمجية والأدوار (Data Models)
// ==========================================

enum UserRole { admin, parent, classLeader }
enum AttendanceStatus { present, absent, late, excused }
enum NotificationType { attendance, absence, alert, excuse }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String time;
  final NotificationType type;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.type,
    this.isRead = false,
  });
}

class Student {
  final String id;
  final String academicId;
  final String name;
  final String grade;
  final String parentPhone;
  AttendanceStatus todayStatus;
  String lastCheckInTime;
  final int totalAbsenceDays;
  final int totalLateDays;
  final int behaviorScore;

  Student({
    required this.id,
    required this.academicId,
    required this.name,
    required this.grade,
    required this.parentPhone,
    this.todayStatus = AttendanceStatus.present,
    this.lastCheckInTime = "07:15 ص",
    this.totalAbsenceDays = 1,
    this.totalLateDays = 2,
    this.behaviorScore = 98,
  });
}

class ExcuseRequest {
  final String id;
  final String studentName;
  final String date;
  final String reason;
  String status;

  ExcuseRequest({
    required this.id,
    required this.studentName,
    required this.date,
    required this.reason,
    this.status = "قيد المراجعة",
  });
}

// ==========================================
// 2. إدارة الحالة المركزية (Central App State)
// ==========================================

class SchoolState extends ChangeNotifier {
  UserRole? currentUserRole;
  String currentUserName = "";
  bool isLocked = false;

  final List<AppNotification> notifications = [
    AppNotification(
      id: '1',
      title: 'وصول آمن للمدرسة',
      body: 'سجل الطالب أحمد خالد دخوله عبر بوابة مدرسة الجيل الساعة 07:12 ص.',
      time: 'منذ ساعتين',
      type: NotificationType.attendance,
      isRead: false,
    ),
  ];

  int get unreadNotificationsCount => notifications.where((n) => !n.isRead).length;

  final List<Student> students = [
    Student(
      id: '1',
      academicId: '2026-0101',
      name: 'أحمد خالد علي الجيلاني',
      grade: 'الثالث الثانوي (علمي - أ)',
      parentPhone: '+967 770 000 001',
      todayStatus: AttendanceStatus.present,
      lastCheckInTime: '07:12 ص',
    ),
    Student(
      id: '2',
      academicId: '2026-0102',
      name: 'محمد وضاح غالب الصبري',
      grade: 'الثالث الثانوي (علمي - أ)',
      parentPhone: '+967 770 000 002',
      todayStatus: AttendanceStatus.absent,
      lastCheckInTime: '--:--',
      totalAbsenceDays: 3,
    ),
    Student(
      id: '3',
      academicId: '2026-0103',
      name: 'بلال نبيل عبد الله الحداد',
      grade: 'الثالث الثانوي (علمي - أ)',
      parentPhone: '+967 770 000 003',
      todayStatus: AttendanceStatus.late,
      lastCheckInTime: '07:48 ص',
    ),
    Student(
      id: '4',
      academicId: '2026-0104',
      name: 'حمزة سعيد صالح النجار',
      grade: 'الثالث الثانوي (علمي - أ)',
      parentPhone: '+967 770 000 004',
      todayStatus: AttendanceStatus.excused,
      lastCheckInTime: '--:--',
      totalAbsenceDays: 2,
    ),
  ];

  final List<ExcuseRequest> excuses = [
    ExcuseRequest(
      id: 'E1',
      studentName: 'محمد وضاح غالب الصبري',
      date: '2026-11-07',
      reason: 'عذر مرضي: مراجعة المستشفى',
    ),
  ];

  // دالة تسجيل الدخول والتحقق الذكي
  bool login(String username, String password) {
    username = username.trim().toLowerCase();
    password = password.trim();

    if (username == 'admin' && password == 'admin123') {
      currentUserRole = UserRole.admin;
      currentUserName = "الأستاذ / مدير المدرسة";
      notifyListeners();
      return true;
    } else if (username == 'parent' && password == 'parent123') {
      currentUserRole = UserRole.parent;
      currentUserName = "ولي أمر الطالب: أحمد خالد";
      notifyListeners();
      return true;
    } else if (username == 'leader' && password == 'leader123') {
      currentUserRole = UserRole.classLeader;
      currentUserName = "رئيس الفصل: حمزة الصالحي (3/ث - أ)";
      notifyListeners();
      return true;
    }
    return false;
  }

  void logout() {
    currentUserRole = null;
    currentUserName = "";
    notifyListeners();
  }

  void pushNotification(BuildContext context, {
    required String title,
    required String body,
    required NotificationType type,
  }) {
    final newNotif = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      time: 'الآن',
      type: type,
    );
    notifications.insert(0, newNotif);
    notifyListeners();

    // إظهار بانر الإشعار المنبثق أعلى الشاشة
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 20),
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF38BDF8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active, color: Color(0xFF38BDF8)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(body, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void updateAttendance(BuildContext context, String studentId, AttendanceStatus newStatus) {
    final index = students.indexWhere((s) => s.id == studentId);
    if (index != -1) {
      students[index].todayStatus = newStatus;
      final student = students[index];

      if (newStatus == AttendanceStatus.present) {
        student.lastCheckInTime = "07:15 ص";
        pushNotification(context,
          title: "حضور الطالب",
          body: "تم تسجيل حضور الطالب (${student.name}) داخل حرم المدرسة.",
          type: NotificationType.attendance,
        );
      } else if (newStatus == AttendanceStatus.absent) {
        pushNotification(context,
          title: "تنبيه غياب مؤكد",
          body: "تم رصد غياب الطالب (${student.name}) في طابور الصباح والحصة الأولى.",
          type: NotificationType.absence,
        );
      }
      notifyListeners();
    }
  }

  void addExcuse(BuildContext context, String studentName, String reason) {
    excuses.insert(0, ExcuseRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      studentName: studentName,
      date: DateTime.now().toString().split(' ')[0],
      reason: reason,
    ));
    pushNotification(context,
      title: "طلب عذر رسمي",
      body: "وصل عذر غياب جديد للطالب ($studentName) وهو قيد مراجعة الإدارة.",
      type: NotificationType.excuse,
    );
    notifyListeners();
  }

  void updateExcuseStatus(String excuseId, String newStatus) {
    final index = excuses.indexWhere((e) => e.id == excuseId);
    if (index != -1) {
      excuses[index].status = newStatus;
      notifyListeners();
    }
  }

  void markAllNotificationsAsRead() {
    for (var n in notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void clearNotifications() {
    notifications.clear();
    notifyListeners();
  }

  void toggleLock() {
    isLocked = !isLocked;
    notifyListeners();
  }
}

final schoolState = SchoolState();

// ==========================================
// 3. التطبيق الرئيسي (App Root)
// ==========================================

class AlJeelSchoolApp extends StatelessWidget {
  const AlJeelSchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: schoolState,
      builder: (context, _) {
        return MaterialApp(
          title: 'مدرسة الجيل الأساسية الثانوية',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1B3B6F),
              primary: const Color(0xFF1B3B6F),
              secondary: const Color(0xFF0284C7),
            ),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          ),
          home: schoolState.currentUserRole == null
              ? const UnifiedLoginScreen()
              : const MainAppShell(),
        );
      },
    );
  }
}

// ==========================================
// 4. واجهة تسجيل الدخول الموحدة
// ==========================================

class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key});

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;

  void _handleLogin() {
    final success = schoolState.login(
      _usernameController.text,
      _passwordController.text,
    );

    if (!success) {
      setState(() {
        _errorMessage = "اسم المستخدم أو كلمة المرور غير صحيحة!";
      });
    }
  }

  void _quickFill(String u, String p) {
    setState(() {
      _usernameController.text = u;
      _passwordController.text = p;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1B3B6F)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amberAccent.withOpacity(0.5), width: 2),
                    ),
                    child: const Icon(Icons.school_rounded, size: 60, color: Colors.amberAccent),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "مدرسة الجيل الأساسية الثانوية",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Text(
                    "بوابة الحضور والمتابعة الذكية الموحدة",
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "تسجيل الدخول",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B3B6F)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12))),
                              ],
                            ),
                          ),
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: "اسم المستخدم / الرقم الأكاديمي",
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: "كلمة المرور",
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B3B6F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _handleLogin,
                          child: const Text("دخول إلى النظام", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text("اختر حساباً تجريبياً للدخول الفوري:", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.admin_panel_settings, size: 16, color: Colors.blue),
                        label: const Text("إدارة المدرسة"),
                        onPressed: () => _quickFill('admin', 'admin123'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.family_restroom, size: 16, color: Colors.green),
                        label: const Text("ولي الأمر"),
                        onPressed: () => _quickFill('parent', 'parent123'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.badge, size: 16, color: Colors.amber),
                        label: const Text("رئيس الفصل"),
                        onPressed: () => _quickFill('leader', 'leader123'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 5. الهيكل الرئيسي للتطبيق (App Shell)
// ==========================================

class MainAppShell extends StatefulWidget {
  const MainAppShell({super.key});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  int _parentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (schoolState.isLocked) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_rounded, size: 70, color: Color(0xFF38BDF8)),
                const SizedBox(height: 16),
                const Text("الجلسة مقفلة بأمان", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.fingerprint),
                  label: const Text("فتح القفل بالبصمة"),
                  onPressed: () => schoolState.toggleLock(),
                )
              ],
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1B3B6F),
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                schoolState.currentUserName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                _getRoleDescription(schoolState.currentUserRole!),
                style: const TextStyle(fontSize: 11, color: Colors.amberAccent),
              ),
            ],
          ),
          actions: [
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                  onPressed: () => _openNotificationCenter(context),
                ),
                if (schoolState.unreadNotificationsCount > 0)
                  Positioned(
                    top: 10,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      child: Text(
                        '${schoolState.unreadNotificationsCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
              ],
            ),
            IconButton(
              icon: const Icon(Icons.lock_outline, color: Colors.white),
              onPressed: () => schoolState.toggleLock(),
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              tooltip: "تسجيل الخروج",
              onPressed: () => schoolState.logout(),
            ),
          ],
        ),
        body: _buildDashboardByRole(),
        bottomNavigationBar: schoolState.currentUserRole == UserRole.parent
            ? BottomNavigationBar(
                currentIndex: _parentTabIndex,
                selectedItemColor: const Color(0xFF1B3B6F),
                onTap: (index) => setState(() => _parentTabIndex = index),
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: "اليوم"),
                  BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: "السجل الشهري"),
                  BottomNavigationBarItem(icon: Icon(Icons.assignment_turned_in), label: "تقديم عذر"),
                ],
              )
            : null,
      ),
    );
  }

  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return "صلاحيات الإدارة والتحكم الكامل";
      case UserRole.parent:
        return "بوابة ولي الأمر للمتابعة اليومية";
      case UserRole.classLeader:
        return "صلاحيات رصد الفصل والبوابة المدرسية";
    }
  }

  Widget _buildDashboardByRole() {
    switch (schoolState.currentUserRole!) {
      case UserRole.admin:
        return const AdminDashboardView();
      case UserRole.parent:
        if (_parentTabIndex == 1) return const ParentMonthlyCalendarView();
        if (_parentTabIndex == 2) return const ParentExcuseSubmissionView();
        return const ParentDashboardView();
      case UserRole.classLeader:
        return const ClassLeaderDashboardView();
    }
  }

  void _openNotificationCenter(BuildContext context) {
    schoolState.markAllNotificationsAsRead();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("مركز التنبيهات والإشعارات", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {
                      schoolState.clearNotifications();
                      Navigator.pop(ctx);
                    },
                    child: const Text("مسح الكل", style: TextStyle(color: Colors.red)),
                  )
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: schoolState.notifications.isEmpty
                  ? const Center(child: Text("لا توجد إشعارات جديدة حالياً"))
                  : ListView.builder(
                      itemCount: schoolState.notifications.length,
                      itemBuilder: (context, index) {
                        final notif = schoolState.notifications[index];
                        return ListTile(
                          leading: const CircleAvatar(backgroundColor: Color(0xFFE0F2FE), child: Icon(Icons.notifications, color: Color(0xFF0284C7))),
                          title: Text(notif.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text("${notif.body}\n${notif.time}"),
                          isThreeLine: true,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 6. لوحة رئيس الفصل (Class Leader View)
// ==========================================

class ClassLeaderDashboardView extends StatelessWidget {
  const ClassLeaderDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF0369A1)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner_rounded, size: 45, color: Colors.white),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("مسح بطاقات الطلاب (QR)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      Text("وجّه الكاميرا نحو بطاقة الزميل لرصد حضوره فورياً", style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0369A1)),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RealGateScannerScreen()));
                  },
                  child: const Text("فتح الكاميرا"),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text("كشف رصد الفصل (3 ثانوي - أ)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: schoolState.students.length,
              itemBuilder: (context, index) {
                final student = schoolState.students[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text("الحالة: ${student.todayStatus.name} - الوقت: ${student.lastCheckInTime}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () => schoolState.updateAttendance(context, student.id, AttendanceStatus.present),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => schoolState.updateAttendance(context, student.id, AttendanceStatus.absent),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// 7. لوحة إدارة المدرسة الكاملة (Admin View)
// ==========================================

class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildKpiCard("الحضور اليوم", "${schoolState.students.where((s) => s.todayStatus == AttendanceStatus.present).length}", Colors.green),
              const SizedBox(width: 8),
              _buildKpiCard("الغياب اليوم", "${schoolState.students.where((s) => s.todayStatus == AttendanceStatus.absent).length}", Colors.red),
              const SizedBox(width: 8),
              _buildKpiCard("إجمالي الشعبة", "${schoolState.students.length}", Colors.blue),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("سجل الحضور والغياب العام", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF1B3B6F)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RealGateScannerScreen())),
              )
            ],
          ),
          const SizedBox(height: 10),
          ...schoolState.students.map((student) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("الرقم: ${student.academicId} • وقت الرصد: ${student.lastCheckInTime}"),
              trailing: DropdownButton<AttendanceStatus>(
                value: student.todayStatus,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: AttendanceStatus.present, child: Text("حاضر", style: TextStyle(color: Colors.green))),
                  DropdownMenuItem(value: AttendanceStatus.absent, child: Text("غائب", style: TextStyle(color: Colors.red))),
                  DropdownMenuItem(value: AttendanceStatus.late, child: Text("متأخر", style: TextStyle(color: Colors.orange))),
                  DropdownMenuItem(value: AttendanceStatus.excused, child: Text("معذور", style: TextStyle(color: Colors.blue))),
                ],
                onChanged: (newStatus) {
                  if (newStatus != null) schoolState.updateAttendance(context, student.id, newStatus);
                },
              ),
            ),
          )),
          const SizedBox(height: 20),
          const Text("طلبات الأعذار المعلقة", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...schoolState.excuses.map((excuse) => Card(
            color: const Color(0xFFFFFBEB),
            child: ListTile(
              leading: const Icon(Icons.assignment_late_outlined, color: Colors.amber),
              title: Text(excuse.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${excuse.reason}\nالحالة: ${excuse.status}"),
              trailing: excuse.status == "قيد المراجعة"
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () => schoolState.updateExcuseStatus(excuse.id, "مقبول"),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => schoolState.updateExcuseStatus(excuse.id, "مرفوض"),
                        ),
                      ],
                    )
                  : Text(excuse.status, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 8. لوحة ولي الأمر (Parent View)
// ==========================================

class ParentDashboardView extends StatelessWidget {
  const ParentDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final student = schoolState.students.first;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1B3B6F), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const CircleAvatar(radius: 26, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white)),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(student.grade, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: student.todayStatus == AttendanceStatus.present ? Colors.green.shade50 : Colors.red.shade50,
            child: ListTile(
              leading: Icon(
                student.todayStatus == AttendanceStatus.present ? Icons.check_circle : Icons.warning_rounded,
                color: student.todayStatus == AttendanceStatus.present ? Colors.green : Colors.red,
                size: 32,
              ),
              title: Text(
                student.todayStatus == AttendanceStatus.present ? "ابنكم متواجد داخل المدرسة الآن" : "ابنكم مسجل كـ غائب اليوم",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text("وقت تسجيل البوابة: ${student.lastCheckInTime}"),
            ),
          ),
        ],
      ),
    );
  }
}

class ParentMonthlyCalendarView extends StatelessWidget {
  const ParentMonthlyCalendarView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("سجل الحضور الشهري", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: 30,
              itemBuilder: (context, index) {
                final day = index + 1;
                return Container(
                  decoration: BoxDecoration(
                    color: (day % 7 == 5 || day % 7 == 6) ? Colors.grey.shade200 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text("$day", style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

class ParentExcuseSubmissionView extends StatefulWidget {
  const ParentExcuseSubmissionView({super.key});

  @override
  State<ParentExcuseSubmissionView> createState() => _ParentExcuseSubmissionViewState();
}

class _ParentExcuseSubmissionViewState extends State<ParentExcuseSubmissionView> {
  final _reasonController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _reasonController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: "سبب الغياب بالتفصيل", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B3B6F),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 45),
            ),
            onPressed: () {
              if (_reasonController.text.isNotEmpty) {
                schoolState.addExcuse(context, "أحمد خالد علي الجيلاني", _reasonController.text);
                _reasonController.clear();
              }
            },
            child: const Text("إرسال العذر للإدارة"),
          )
        ],
      ),
    );
  }
}

// ==========================================
// 9. ماسح الكاميرا الحقيقي للبطاقات (MobileScanner)
// ==========================================

class RealGateScannerScreen extends StatefulWidget {
  const RealGateScannerScreen({super.key});

  @override
  State<RealGateScannerScreen> createState() => _RealGateScannerScreenState();
}

class _RealGateScannerScreenState extends State<RealGateScannerScreen> {
  late MobileScannerController _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(detectionSpeed: DetectionSpeed.normal);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue;
    if (code == null) return;

    setState(() => _isProcessing = true);
    HapticFeedback.heavyImpact();

    Student? matched;
    try {
      matched = schoolState.students.firstWhere((s) => s.academicId == code || code.contains(s.academicId));
    } catch (_) {
      matched = null;
    }

    if (matched != null) {
      schoolState.updateAttendance(context, matched.id, AttendanceStatus.present);
      _showResultDialog("تم تسجيل الحضور بنجاح", matched.name, Colors.green);
    } else {
      _showResultDialog("بطاقة غير معروفة!", "الكود ($code) غير مسجل في مدرسة الجيل", Colors.red);
    }
  }

  void _showResultDialog(String title, String desc, Color color) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          content: Text(desc),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _isProcessing = false);
              },
              child: const Text("متابعة المسح"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("كاميرا مسح بطاقات مدرسة الجيل"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(border: Border.all(color: Colors.amberAccent, width: 2), borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}