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
  static const errorNetwork =
      'تعذّر الاتصال بالخادم. تحقق من اتصالك بالإنترنت.';
  static const errorTimeout = 'استغرق الاتصال وقتًا طويلًا. حاول مرة أخرى.';

  static const comingSoon = 'قريبًا';

  // Auth: fields and actions.
  static const authOr = 'أو';
  static const authPending = 'لحظة…';
  static const fieldName = 'الاسم';
  static const fieldNameHint = 'مثلًا: ليلى أحمد';
  static const fieldPhone = 'رقم الهاتف';
  static const fieldPhoneHint = '933 123 456';
  static const fieldCountryCode = 'رمز البلد';
  static const fieldPassword = 'كلمة المرور';
  static const fieldNewPassword = 'كلمة المرور الجديدة';
  static const fieldConfirmPassword = 'تأكيد كلمة المرور الجديدة';
  static const fieldCurrentPassword = 'كلمة المرور الحالية';
  static const fieldTemporaryPassword = 'كلمة المرور المؤقتة';
  static const showPassword = 'إظهار كلمة المرور';
  static const hidePassword = 'إخفاء كلمة المرور';

  // Auth: password rules (live hints).
  static const rulesLabel = 'شروط كلمة المرور';
  static const ruleLength = '8 أحرف على الأقل';
  static const ruleNotDigits = 'ليست أرقامًا فقط';
  static const ruleNotPhone = 'ليست رقم هاتفك';
  static const ruleMet = 'متحقق';
  static const ruleUnmet = 'غير متحقق';

  // Auth: validation errors.
  static const errNameRequired = 'اكتب اسمك.';
  static const errNameTooLong = 'الاسم طويل جدًا.';
  static const errPhoneRequired = 'أدخل رقم هاتفك.';
  static const errPhoneInvalid = 'رقم الهاتف غير صحيح.';
  static const errPasswordRequired = 'أدخل كلمة المرور.';
  static const errPasswordShort =
      'يجب أن تتكون كلمة المرور من 8 أحرف على الأقل.';
  static const errPasswordLong = 'يجب ألا تتجاوز كلمة المرور 128 حرفًا.';
  static const errPasswordDigits = 'يجب ألا تتكون كلمة المرور من أرقام فقط.';
  static const errPasswordPhone = 'يجب ألا تكون كلمة المرور رقم هاتفك.';
  static const errConfirmMismatch = 'كلمتا المرور غير متطابقتين.';
  static const errSamePassword = 'يجب أن تختلف كلمة المرور الجديدة عن الحالية.';
  static String authRetryIn(int seconds) =>
      'يمكنك المحاولة مرة أخرى بعد $seconds ثانية.';
  static const authContactStore = 'تواصل مع المتجر:';

  // Auth: login / register / complete profile.
  static const loginLead = 'أدخل رقم هاتفك وكلمة المرور.';
  static const loginSubmit = 'دخول';
  static const loginNoAccount = 'ليس لديك حساب؟';
  static const loginRegister = 'سجّل';
  static const loginForgot = 'نسيت كلمة المرور؟';
  static const loginContinueAsGuest = 'تصفّح كضيف';
  static const sessionExpired = 'انتهت الجلسة، سجّل الدخول من جديد.';
  static const registerLead = 'سجّل باسمك ورقم هاتفك لتتمكن من الطلب بسهولة.';
  static const registerSubmit = 'إنشاء حساب';
  static const registerHaveAccount = 'لديك حساب؟';
  static const registerLogin = 'سجّل دخولك';
  static const loginInstead = 'سجّل دخولك';
  static const completeLead =
      'خطوة أخيرة: أدخل اسمك ورقم هاتفك لنتواصل معك بشأن طلباتك.';
  static const completeGoogleAccount = 'حساب Google:';
  static const completeSubmit = 'متابعة';
  static const completeExpired = 'انتهت مهلة التسجيل بـ Google. ابدأ من جديد.';
  static const completeRestart = 'العودة إلى تسجيل الدخول';

  // Auth: Google. The "dev" button is development scaffolding only.
  static const googleContinue = 'المتابعة مع Google';
  static const googleDev = 'دخول تجريبي بـ Google';
  static const googleDevName = 'مستخدم تجريبي';
  static const googleFailed = 'تعذّرت المتابعة مع Google. حاول مرة أخرى.';

  // Auth: forgot password (no self-service reset).
  static const forgotTitle = 'نسيت كلمة المرور؟';
  static const forgotBody =
      'لا تتوفر استعادة تلقائية لكلمة المرور. اتصل بالمتجر لتحصل على كلمة مرور مؤقتة بعد التحقق من هويتك، ثم اختر كلمة مرور جديدة عند تسجيل الدخول.';
  static const forgotCall = 'اتصل بالمتجر';
  static const forgotWhatsapp = 'راسلنا على واتساب';
  static const forgotNoContact =
      'تواصل مع المتجر وأخبرهم أنك نسيت كلمة المرور.';
  static const close = 'إغلاق';

  // Auth: forced / voluntary password change.
  static const changeLead = 'اختر كلمة مرور جديدة لحسابك.';
  static const changeForcedNote =
      'منحك المتجر كلمة مرور مؤقتة. يجب اختيار كلمة مرور جديدة قبل المتابعة.';
  static const changeSubmit = 'حفظ كلمة المرور';

  // Account tab.
  static const gateTitle = 'سجّل الدخول لمتابعة التسوق';
  static const gateText = 'سجّل دخولك أو أنشئ حسابًا للوصول إلى هذه الصفحة.';
  static const accountVia = 'سجّلت الدخول عبر';
  static const accountViaPhone = 'رقم الهاتف';
  static const accountViaGoogle = 'Google';
  static const accountEmail = 'البريد الإلكتروني';
  static const accountUnavailable =
      'تعذّر تحميل معلومات حسابك حاليًا. يُرجى المحاولة لاحقًا.';

  // Catalog: navigation and titles.
  static const categories = 'الأقسام';
  static const newArrivals = 'جديد';
  static const sale = 'التخفيضات';
  static const searchHint = 'ابحث عن منتج أو ماركة';
  static const searchSubmit = 'بحث';
  static const searchTryHint = 'جرّب البحث عن:';
  static const searchSuggestions = ['أحمر شفاه', 'شامبو', 'عطر', 'سدر'];
  static const searchEmptyTitle = 'لا توجد نتائج';
  static const searchEmptyText = 'جرّب كلمة أخرى، مثل اسم ماركة أو نوع منتج.';
  static String searchResultsFor(String q) => 'نتائج «$q»';

  // Home.
  static const homeNewArrivals = 'وصل حديثًا';
  static const homeByCategory = 'تسوّق حسب القسم';
  static const homeOnSale = 'عروض لفترة محدودة';
  static const homeBrands = 'الماركات';
  static const seeAll = 'عرض الكل';
  static const allBrands = 'كل الماركات';
  static const homeEmptyNew = 'سنضيف منتجات جديدة قريبًا';
  static const homeEmptySale = 'لا توجد عروض حاليًا، تابعنا قريبًا';
  static const sectionFailed = 'تعذّر عرض هذا القسم حاليًا.';
  static const bannerSaleTitle = 'تخفيضات الموسم';
  static const bannerSaleSubtitle = 'خصومات تصل إلى ٣٠٪ على مكياج وعطور مختارة';
  static const bannerNewTitle = 'وصل حديثًا';
  static const bannerNewSubtitle = 'منتجات جديدة كل أسبوع';
  static const bannerCtaSale = 'تسوّق العروض';
  static const bannerCtaNew = 'تصفّح الجديد';
  static const bannerCtaDefault = 'اكتشف';

  // Product card.
  static const cardNew = 'جديد';
  static const cardSoldOut = 'نفدت الكمية';
  static const cardColors = 'الألوان المتوفرة';
  static String discountBadge(int percent) => '−$percent٪';

  // Lists and filters.
  static const listAll = 'الكل';
  static const listBrand = 'الماركة';
  static const listPrice = 'السعر';
  static const listSort = 'الترتيب';
  static const sortNewest = 'الأحدث';
  static const sortPriceAsc = 'الأرخص';
  static const sortPriceDesc = 'الأغلى';
  static const sortRelevance = 'الأكثر صلة';
  static const filtersTitle = 'الفلاتر';
  static const filtersButton = 'تصفية';
  static const clearAll = 'مسح الكل';
  static const showResults = 'عرض النتائج';
  static const minPrice = 'من';
  static const maxPrice = 'إلى';
  static const currencyLabel = 'العملة';
  static const currencySyp = 'ل.س';
  static const currencyUsd = r'$';
  static const onSaleOnly = 'عليه خصم';
  static const yes = 'نعم';
  static const no = 'لا';
  static const filtersLoading = 'جارٍ تحميل الفلاتر...';
  static const filtersUnavailable = 'تعذّر تحميل الفلاتر.';
  static const activeFilters = 'الفلاتر المختارة';
  static const invalidFilters = 'تجاهلنا بعض الفلاتر لأنها غير صالحة.';
  static const emptyFiltered = 'لا توجد منتجات تطابق هذه الفلاتر';
  static const emptyFilteredText = 'غيّر الفلاتر أو امسحها لعرض كل المنتجات.';
  static const clearFilters = 'مسح الفلاتر';
  static const emptyCategory = 'سنضيف منتجات إلى هذا القسم قريبًا';
  static const emptyBrand = 'سنضيف منتجات من هذه الماركة قريبًا';
  static const emptyNew = 'سنضيف منتجات جديدة قريبًا';
  static const emptySale = 'لا توجد عروض حاليًا، تابعنا قريبًا';
  static const listUnavailable = 'تعذّر تحميل المنتجات حاليًا';
  static const loadMoreFailed = 'تعذّر تحميل المزيد';
  static const subNew = 'أحدث المنتجات التي وصلت.';
  static const subSale = 'خصومات لفترة محدودة، والكمية محدودة.';
  static const subcategories = 'الأقسام الفرعية';
  static const brandOwn = 'ماركة المتجر';
  static const brandsEmpty = 'سنضيف ماركات قريبًا';
  static const categoriesEmpty = 'سنضيف أقسامًا قريبًا';
  static String priceFrom(String min) => 'من $min';
  static String priceTo(String max) => 'حتى $max';
  static String priceBetween(String min, String max) => '$min – $max';
  static String priceRangeChip(String range) => 'السعر: $range';
  static String removeFilter(String label) => 'إزالة الفلتر: $label';

  // Product screen.
  static const productInStock = 'متوفر';
  static const productOut = 'نفدت الكمية';
  static const productOutShort = '(نفد)';
  static const productOutHint = 'أضِفه إلى المفضلة وسنُعلمك عند توفّره من جديد';
  static const productAddToCart = 'أضِف إلى السلة';
  static const productFavorite = 'المفضلة';
  static const productTabDescription = 'الوصف';
  static const productTabDetails = 'التفاصيل';
  static const productNoDescription = 'لا يتوفر وصف لهذا المنتج بعد.';
  static const productBundleTitle = 'محتويات علبة الهدايا';
  static const productRelated = 'قد يعجبك أيضًا';
  static const productUnavailable = 'تعذّر تحميل هذا المنتج حاليًا';
  static const productNotFound = 'هذا المنتج غير متوفر.';
  static const categoryNotFound = 'هذا القسم غير متوفر.';
  static const brandNotFound = 'هذه الماركة غير متوفرة.';
  static String productLow(int n) => 'لم يتبقَّ سوى $n';
  static String productSave(String amount) => 'وفّر $amount';
  static String productImage(int n) => 'صورة $n';
  static String bundleQuantity(int n) => '× $n';

  // Plurals (ported from lamsa-web `plurals.*`).
  static String products(int n) => _plural(
    n,
    zero: 'لا توجد منتجات',
    one: 'منتج واحد',
    two: 'منتجان',
    few: '$n منتجات',
    many: '$n منتجًا',
    other: '$n منتج',
  );

  static String brandsCount(int n) => _plural(
    n,
    zero: 'لا توجد ماركات',
    one: 'ماركة واحدة',
    two: 'ماركتان',
    few: '$n ماركات',
    many: '$n ماركة',
    other: '$n ماركة',
  );

  /// Arabic CLDR plural categories (zero / one / two / few / many / other).
  static String _plural(
    int n, {
    required String zero,
    required String one,
    required String two,
    required String few,
    required String many,
    required String other,
  }) {
    if (n == 0) return zero;
    if (n == 1) return one;
    if (n == 2) return two;
    final mod100 = n % 100;
    if (mod100 >= 3 && mod100 <= 10) return few;
    if (mod100 >= 11) return many;
    return other;
  }
}
