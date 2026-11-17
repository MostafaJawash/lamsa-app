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

  // Cart.
  static const cartSummary = 'ملخص الطلب';
  static const cartSubtotal = 'المجموع الفرعي';
  static const cartSavings = 'وفّرت';
  static const cartTotal = 'الإجمالي';
  static const cartDelivery = 'التوصيل';
  static const cartDeliveryNext = 'يُحدَّد في الخطوة التالية';
  static const cartFixFirst = 'حدّث سلتك أولًا لتتمكن من إتمام الطلب.';
  static const cartCheckoutHint = 'اختر طريقة التوصيل في الخطوة التالية.';
  static const cartRemove = 'احذف';
  static const cartEmptyTitle = 'سلتك فارغة';
  static const cartEmptyText = 'أضِف منتجات من الأقسام لتظهر هنا.';
  static const cartStartShopping = 'ابدأ التسوق';
  static const cartUnavailable = 'تعذّر تحميل سلتك الآن، يُرجى المحاولة لاحقًا';
  static const cartIssuesNotice = 'تغيّرت بعض المنتجات في سلتك';
  static const cartResolve = 'تحديث السلة';
  static const cartUpdated = 'تم تحديث سلتك';
  static const cartClear = 'إفراغ السلة';
  static const cartClearTitle = 'إفراغ السلة؟';
  static const cartClearText = 'ستُزال كل المنتجات من سلتك.';
  static const cartClearConfirm = 'إفراغ';
  static const cancel = 'إلغاء';
  static const cartUnknownProduct = 'منتج غير متوفر';
  static const quantity = 'الكمية';
  static const quantityLess = 'أقل';
  static const quantityMore = 'المزيد';
  static const lineTotal = 'المجموع';
  static String items(int n) => _plural(
        n,
        zero: 'لا توجد قطع',
        one: 'قطعة واحدة',
        two: 'قطعتان',
        few: '$n قطع',
        many: '$n قطعة',
        other: '$n قطعة',
      );

  // Cart: line issues and notices (codes from the backend).
  static const issueUnavailable = 'لم يعد المنتج متوفرًا';
  static const issueVariantUnavailable = 'لم يعد هذا الخيار متوفرًا';
  static const issueOutOfStock = 'نفدت الكمية';
  static String issueInsufficientStock(int n) => 'لم يتبقَّ سوى $n';
  static String issueQuantityLimit(int n) => 'الحد الأقصى $n';
  static const noticeQuantityCapped = 'عُدّلت الكمية وفقًا للمخزون المتوفر';
  static const noticeLinesMerged = 'دُمج منتجان متطابقان في سطر واحد';
  static const noticeLineRemoved = 'أُزيل منتج لم يعد متوفرًا';

  // Favorites.
  static const favoritesSub =
      'المنتجات التي حفظتها، يمكنك نقلها إلى السلة بضغطة واحدة.';
  static const favoritesMoveToCart = 'انقل إلى السلة';
  static const favoritesRemove = 'إزالة من المفضلة';
  static const favoritesEmptyTitle = 'المفضلة فارغة';
  static const favoritesEmptyText = 'اضغط على القلب في أي منتج لحفظه هنا.';
  static const favoritesBrowseNew = 'تصفّح الجديد';
  static const favoritesUnavailable =
      'تعذّر تحميل المفضلة الآن، يُرجى المحاولة لاحقًا';

  // Toasts.
  static const toastFavAdded = 'أُضيف إلى المفضلة';
  static const toastFavRemoved = 'أُزيل من المفضلة';
  static const toastFavAction = 'المفضلة';
  static const toastCartAdded = 'أُضيف إلى السلة';
  static const toastCartAction = 'عرض السلة';
  static const toastMoved = 'نُقل إلى السلة';
  static const toastMovedAction = 'السلة';
  static String toastMerged(int n) => 'أعدنا ${products(n)} إلى سلتك';
  static const toastMergedAdjusted = 'عُدّلت بعض المنتجات وفقًا للمخزون المتوفر';
  static String toastLow(int n) => 'لم يتبقَّ سوى $n';
  static String toastMax(int n) => 'الحد الأقصى $n';
  static const badgeOverflow = '99+';

  // Checkout.
  static const checkoutTitle = 'إتمام الطلب';
  static const checkoutAddress = 'عنوان التوصيل';
  static const checkoutDelivery = 'طريقة التوصيل';
  static const checkoutPayment = 'الدفع';
  static const checkoutCod = 'الدفع عند الاستلام';
  static const checkoutCodHint =
      'تدفع عند وصول الطلب، بالعملة أو العملات الظاهرة في مجموع طلبك.';
  static const checkoutExtras = 'ملاحظات الطلب';
  static const checkoutNotes = 'ملاحظات على الطلب';
  static const checkoutNotesHint = 'مثلًا: الاتصال قبل الوصول';
  static const checkoutGift = 'إضافة رسالة هدية';
  static const checkoutGiftLabel = 'رسالة الهدية';
  static const checkoutGiftHint = 'اكتب الرسالة التي تريد إرفاقها بالطلب';
  static const checkoutAddAddress = '+ إضافة عنوان جديد';
  static const checkoutNoAddress = 'أضف عنوان توصيل لمتابعة الطلب.';
  static const checkoutDeliveryNeedsAddress =
      'اختر عنوان التوصيل لتظهر طرق التوصيل المتاحة.';
  static const checkoutNoMethods = 'لا تتوفر طريقة توصيل لهذا العنوان حاليًا.';
  static const checkoutYourOrder = 'طلبك';
  static const checkoutDeliveryPending = 'يُحدَّد عند اختيار طريقة التوصيل';
  static const checkoutCarrierPaid =
      'تُدفع أجرة الشحن لشركة الشحن عند الاستلام';
  static const checkoutPaidToCarrier = 'تُدفع للناقل';
  static const checkoutFree = 'مجاني';
  static const checkoutConfirm = 'تأكيد الطلب';
  static const checkoutConfirming = 'جارٍ تأكيد الطلب…';
  static const checkoutNotifyHint = 'سيصلك إشعار عند كل تغيير في حالة الطلب.';
  static const checkoutNeedAddress = 'اختر عنوان التوصيل لإتمام الطلب.';
  static const checkoutNeedMethod = 'اختر طريقة التوصيل لإتمام الطلب.';
  static const checkoutPriceChanged =
      'تغيّرت الأسعار أو المجاميع منذ آخر عرض. راجع المجاميع الجديدة ثم أكّد الطلب مرة أخرى.';
  static const checkoutMethodChanged =
      'لم تعد طريقة التوصيل المختارة متاحة لهذا العنوان. اختر طريقة توصيل من القائمة ثم أكّد الطلب.';
  static const checkoutAddressInvalid =
      'تعذّر استخدام عنوان التوصيل المختار. اختر عنوانًا آخر أو أضف عنوانًا جديدًا.';
  static String checkoutNotesTooLong(int max) =>
      'يجب ألا تتجاوز الملاحظات $max حرف.';
  static const checkoutUnavailable =
      'تعذّر تحميل صفحة إتمام الطلب الآن، يُرجى المحاولة لاحقًا';

  // Order confirmation.
  static const successTitle = 'تم تأكيد طلبك';
  static const successNumber = 'رقم الطلب';
  static const successTrack = 'تتبّع الطلب';
  static const successContinue = 'متابعة التسوق';

  // Addresses.
  static const addresses = 'عناويني';
  static const addressesSub = 'احفظ عناوينك لتسريع إتمام طلباتك.';
  static const addressesAdd = '+ عنوان جديد';
  static const addressesAddFirst = 'إضافة عنوان';
  static const addressesNewTitle = 'عنوان جديد';
  static const addressesEditTitle = 'تعديل العنوان';
  static const addressesDefault = 'افتراضي';
  static const addressesSetDefault = 'تعيين كافتراضي';
  static const addressesEdit = 'تعديل';
  static const addressesDelete = 'حذف';
  static const addressesDeleteTitle = 'حذف العنوان؟';
  static String addressesDeleteText(String label) =>
      'سيُحذف عنوان «$label» من حسابك، ولن تتأثر طلباتك السابقة.';
  static const addressesEmptyTitle = 'لا توجد عناوين محفوظة';
  static const addressesEmptyText = 'أضف عنوانًا ليسهل عليك إتمام طلباتك.';
  static const addressesHasLocation = 'الموقع محدد على الخريطة';
  static const addressesUnavailable =
      'تعذّر تحميل عناوينك الآن، يُرجى المحاولة لاحقًا';
  static const governoratesUnavailable =
      'تعذّر تحميل قائمة المحافظات الآن، يُرجى المحاولة لاحقًا.';
  static const toastAddressSaved = 'تم حفظ العنوان';
  static const toastAddressDeleted = 'تم حذف العنوان';
  static const toastAddressDefault = 'تم تعيين العنوان كافتراضي';

  // Address form.
  static const afLabel = 'اسم العنوان (اختياري)';
  static const afLabelHint = 'مثلًا: البيت أو العمل';
  static const afGovernorate = 'المحافظة';
  static const afGovernorateHint = 'اختر المحافظة';
  static const afArea = 'المنطقة أو الحي (اختياري)';
  static const afDetails = 'تفاصيل العنوان';
  static const afDetailsHint = 'الشارع، البناء، الطابق، أقرب معلم';
  static const afDetailsHelp = 'اكتب ما يساعد المندوب على الوصول إليك.';
  static const afNotes = 'ملاحظات للتوصيل (اختياري)';
  static const afMakeDefault = 'تعيين كعنوان افتراضي';
  static const afSave = 'حفظ العنوان';
  static String afCounter(int n, int max) => '$n / $max';
  static String afErrLabelLong(int max) =>
      'يجب ألا يتجاوز اسم العنوان $max حرفًا.';
  static const afErrGovernorateRequired = 'اختر المحافظة.';
  static const afErrGovernorateUnknown = 'المحافظة المختارة غير مدعومة.';
  static String afErrAreaLong(int max) => 'يجب ألا تتجاوز المنطقة $max حرف.';
  static const afErrDetailsRequired = 'اكتب تفاصيل العنوان.';
  static String afErrDetailsShort(int min) => 'اكتب $min أحرف على الأقل.';
  static String afErrDetailsLong(int max) =>
      'يجب ألا تتجاوز التفاصيل $max حرف.';
  static String afErrNotesLong(int max) => 'يجب ألا تتجاوز الملاحظات $max حرف.';
  static const afErrLocationInvalid = 'الموقع المحدد غير صالح أو خارج سوريا.';
  static const afErrInvalid = 'القيمة غير صحيحة.';

  // Map picker.
  static const mapTitle = 'الموقع على الخريطة';
  static const mapOptional = 'اختياري';
  static const mapHelp =
      'اضغط على الخريطة لوضع الدبوس، ثم اسحبه لتعديل موقعه.';
  static const mapUseMyLocation = 'استخدم موقعي الحالي';
  static const mapRemoveLocation = 'إزالة الموقع';
  static const mapLocating = 'جارٍ تحديد موقعك…';
  static const mapLocated = 'تم تحديد موقعك على الخريطة.';
  static const mapPlaced = 'تم وضع الدبوس على الخريطة.';
  static const mapMoved = 'تم تحريك الدبوس.';
  static const mapRemoved = 'أُزيل الموقع من العنوان.';
  static const mapDenied =
      'لم يُسمح بالوصول إلى موقعك. فعّل إذن الموقع، أو ضع الدبوس يدويًا على الخريطة.';
  static const mapUnavailable =
      'تعذّر تحديد موقعك. ضع الدبوس يدويًا على الخريطة.';
  static const mapOutside = 'الموقع المحدد خارج سوريا. اختر نقطة داخل سوريا.';
  static const mapTilesFailed =
      'تعذّر تحميل الخريطة. يمكنك إكمال العنوان بدونها.';
  // The credit OpenStreetMap's tile policy asks for, in its own wording.
  static const mapAttribution = '© OpenStreetMap';

  // Orders.
  static String orderNumber(int id) => 'طلب #$id';
  static String orderPlacedOn(String date) => 'تاريخ الطلب: $date';
  static const ordersUnavailable =
      'تعذّر تحميل طلباتك الآن، يُرجى المحاولة لاحقًا';
  static const ordersFilterAll = 'الكل';
  static const ordersFilterActive = 'قيد التنفيذ';
  static const ordersFilterCompleted = 'مكتملة';
  static const ordersFilterCancelled = 'ملغاة';
  static const ordersEmptyTitle = 'لا توجد طلبات بعد';
  static const ordersEmptyFiltered = 'لا توجد طلبات في هذا التصنيف';
  static const ordersStartShopping = 'ابدأ التسوق';

  // Order detail.
  static const odTimeline = 'مراحل الطلب';
  static String odCancelReasonShown(String reason) => 'السبب: $reason';
  static const odItems = 'منتجات الطلب';
  static const odDelivery = 'طريقة التوصيل';
  static const odAddress = 'العنوان';
  static const odPickup = 'الاستلام';
  static const odPayment = 'الدفع';
  static const odCod = 'عند الاستلام';
  static const odPaid = 'تم الدفع';
  static const odRefunded = 'أُعيد المبلغ';
  static const odViewOnMap = 'عرض على الخريطة';
  static const odCancel = 'إلغاء الطلب';
  static const odCancelTitle = 'إلغاء الطلب؟';
  static const odCancelText =
      'سيُلغى طلبك وتعود المنتجات إلى المخزون. لا يمكن التراجع بعد التأكيد.';
  static const odCancelReason = 'سبب الإلغاء (اختياري)';
  static const odCancelConfirm = 'تأكيد الإلغاء';
  static const odKeep = 'تراجع';
  static const odReorder = 'إعادة الطلب';
  static const odReorderNothing = 'لم يُضَف أي منتج إلى السلة.';
  static const toastOrderCancelled = 'تم إلغاء الطلب';

  // Account menu and settings.
  static const accountOrders = 'طلباتي';
  static const accountAddresses = 'عناويني';
  static const accountProfile = 'بياناتي';
  static const accountPhone = 'رقم الهاتف';
  static const accountPassword = 'كلمة المرور';
  static const accountLogoutAll = 'تسجيل الخروج من كل الأجهزة';
  static const logoutAllTitle = 'الخروج من كل الأجهزة؟';
  static const logoutAllText =
      'ستنتهي جلساتك على كل الأجهزة، بما فيها هذا الجهاز، وستحتاج إلى تسجيل الدخول من جديد.';
  static const logoutAllConfirm = 'تسجيل الخروج';
  static const profileSave = 'حفظ البيانات';
  static const profileEmail = 'البريد الإلكتروني (اختياري)';
  static const phoneCurrent = 'رقمك الحالي:';
  static const phoneHintPhone =
      'رقم هاتفك هو ما تسجّل به الدخول. أدخل كلمة مرورك الحالية لتأكيد التغيير.';
  static const phoneHintGoogle =
      'حسابك مرتبط بـ Google، لذلك لا تحتاج إلى كلمة مرور لتغيير الرقم.';
  static const phoneNew = 'رقم الهاتف الجديد';
  static const phoneSave = 'تغيير الرقم';
  static const passwordHint =
      'عند تغيير كلمة المرور تنتهي جلساتك على الأجهزة الأخرى.';
  static const passwordGoogleAccount =
      'حسابك مرتبط بـ Google، ولا يملك كلمة مرور في المتجر.';
  static const errEmailInvalid = 'البريد الإلكتروني غير صحيح.';
  static String errEmailLong(int max) =>
      'يجب ألا يتجاوز البريد الإلكتروني $max حرفًا.';
  static const toastProfileSaved = 'تم حفظ بياناتك';
  static const toastPhoneChanged = 'تم تغيير رقم الهاتف';
  static const toastPasswordChanged = 'تم تغيير كلمة المرور';

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

  // Notifications.
  static const notifUnavailable =
      'تعذّر تحميل الإشعارات الآن، يُرجى المحاولة لاحقًا';
  static const notifEmptyTitle = 'لا توجد إشعارات بعد';
  static const notifEmptyText = 'ستظهر هنا تحديثات طلباتك وعروض المتجر.';
  static const notifMarkAll = 'تعليم الكل كمقروء';
  static const notifUnreadLabel = 'غير مقروء';
  static const notifBannerClose = 'إغلاق';
  static const notifJustNow = 'الآن';
  static String notifMinutesAgo(int n) => switch (n) {
        1 => 'قبل دقيقة',
        2 => 'قبل دقيقتين',
        >= 3 && <= 10 => 'قبل $n دقائق',
        _ => 'قبل $n دقيقة',
      };
  static String notifHoursAgo(int n) => switch (n) {
        1 => 'قبل ساعة',
        2 => 'قبل ساعتين',
        >= 3 && <= 10 => 'قبل $n ساعات',
        _ => 'قبل $n ساعة',
      };

  // Notification preferences.
  static const prefsTitle = 'تفضيلات الإشعارات';
  static const prefsLead = 'اختر الإشعارات التي تريد أن تصلك.';
  static const prefsMarketing = 'العروض والحملات';
  static const prefsMarketingHint =
      'عروض المتجر وأخباره. عند إيقافها تُخفى أيضًا من صندوق الإشعارات.';
  static const prefsFavorites = 'تنبيهات المفضلة';
  static const prefsFavoritesHint = 'عودة منتج مفضّل إلى المخزون أو انخفاض سعره.';
  static const prefsCartReminders = 'تذكير السلة';
  static const prefsCartRemindersHint = 'تذكير بسلة تركتها دون إتمام الطلب.';
  static const prefsOrderUpdates = 'تحديثات الطلب';
  static const prefsAlwaysOn = 'مفعّلة دائمًا';
  static const prefsOrderUpdatesHint =
      'حالة طلباتك (التأكيد والتجهيز والشحن والتسليم) تصلك دائمًا ولا يمكن إيقافها.';
  static const prefsStoreMessages =
      'رسائل المتجر المرسلة إليك مباشرة تصلك دائمًا أيضًا.';

  // Asking for the notification permission.
  static const pushAskTitle = 'فعّل الإشعارات';
  static const pushAskText = 'لتصلك تحديثات طلباتك فور حدوثها.';
  static const pushAskAction = 'تفعيل';
  static const pushDeniedText =
      'الإشعارات معطّلة لهذا التطبيق. فعّلها من إعدادات الجهاز (الإشعارات) لتصلك تحديثات طلباتك.';
  static const pushExplainTitle = 'تابع طلبك لحظة بلحظة';
  static const pushExplainText =
      'اسمح بالإشعارات لنخبرك عند تأكيد طلبك وتجهيزه وشحنه وتسليمه.';
  static const pushExplainAllow = 'السماح بالإشعارات';
  static const pushExplainLater = 'ليس الآن';
}
