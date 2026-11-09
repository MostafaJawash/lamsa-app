/// Central Arabic UI text. Arabic only: no i18n framework underneath.
abstract final class Strings {
  static const appName = 'لمسة';

  // Screen titles.
  static const home = 'الرئيسية';
  static const category = 'القسم';
  static const product = 'تفاصيل المنتج';
  static const search = 'البحث';
  static const brands = 'العلامات التجارية';
  static const cart = 'السلة';
  static const favorites = 'المفضلة';
  static const orders = 'طلباتي';
  static const account = 'حسابي';
  static const notifications = 'الإشعارات';
  static const login = 'تسجيل الدخول';
  static const register = 'إنشاء حساب';
  static const completeProfile = 'إكمال الملف الشخصي';
  static const changePassword = 'تغيير كلمة المرور';

  // Auth fields and actions.
  static const phone = 'رقم الهاتف';
  static const password = 'كلمة المرور';
  static const name = 'الاسم';
  static const continueWithGoogle = 'المتابعة باستخدام جوجل';
  static const googleNotConfigured = 'تسجيل الدخول عبر جوجل غير مفعّل بعد.';
  static const logout = 'تسجيل الخروج';

  // Generic states.
  static const loading = 'جارٍ التحميل...';
  static const back = 'رجوع';
  static const retry = 'إعادة المحاولة';
  static const emptyDefault = 'لا توجد عناصر لعرضها.';
  static const errorGeneric = 'حدث خطأ غير متوقع. حاول مرة أخرى.';
  static const errorNetwork = 'تعذّر الاتصال بالخادم. تحقق من اتصالك بالإنترنت.';
  static const errorTimeout = 'استغرق الاتصال وقتًا طويلًا. حاول مرة أخرى.';

  // Placeholder home connectivity probe.
  static const serverReachable = 'الخادم متصل';
  static const serverUnreachable = 'الخادم غير متاح';
  static const checkingServer = 'جارٍ فحص الاتصال بالخادم...';
}
