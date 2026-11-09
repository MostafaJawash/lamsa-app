/// Arabic fallback copy for every error code in the backend README, used only
/// when the response carries no Arabic `message` of its own.
abstract final class ErrorMessages {
  static const generic = 'حدث خطأ غير متوقع. حاول مرة أخرى.';

  static String forCode(String code) => _byCode[code] ?? generic;

  static bool hasCode(String code) => _byCode.containsKey(code);

  static Iterable<String> get codes => _byCode.keys;

  static const _byCode = <String, String>{
    // Client-side.
    'NETWORK_ERROR': 'تعذّر الاتصال بالخادم. تحقق من اتصالك بالإنترنت.',
    'TIMEOUT': 'استغرق الاتصال وقتًا طويلًا. حاول مرة أخرى.',
    'UNKNOWN_ERROR': generic,

    // Generic HTTP.
    'VALIDATION_ERROR': 'بعض البيانات غير صحيحة.',
    'INTERNAL_ERROR': 'حدث خطأ في الخادم. حاول لاحقًا.',
    'NOT_FOUND': 'العنصر المطلوب غير موجود.',
    'METHOD_NOT_ALLOWED': 'هذا الإجراء غير مسموح.',
    'HTTP_ERROR': generic,
    'SERVICE_BUSY': 'الخدمة مشغولة حاليًا. حاول بعد قليل.',

    // Auth and session.
    'NOT_AUTHENTICATED': 'يجب تسجيل الدخول للمتابعة.',
    'TOKEN_INVALID': 'انتهت الجلسة. سجّل الدخول من جديد.',
    'TOKEN_EXPIRED': 'انتهت صلاحية الجلسة. سجّل الدخول من جديد.',
    'TOKEN_REUSED': 'تم إنهاء الجلسة لأسباب أمنية. سجّل الدخول من جديد.',
    'INVALID_CREDENTIALS': 'رقم الهاتف أو كلمة المرور غير صحيحة.',
    'CURRENT_PASSWORD_INCORRECT': 'كلمة المرور الحالية غير صحيحة.',
    'TOO_MANY_ATTEMPTS': 'محاولات كثيرة. انتظر قليلًا ثم حاول مجددًا.',
    'ACCOUNT_DISABLED': 'هذا الحساب معطّل. تواصل مع المتجر.',
    'USER_NOT_FOUND': 'الحساب غير موجود.',
    'ADMIN_ONLY': 'هذا الإجراء غير متاح لحسابك.',
    'PASSWORD_CHANGE_REQUIRED': 'يجب تغيير كلمة المرور قبل المتابعة.',
    'GOOGLE_TOKEN_INVALID': 'تعذّر التحقق من حساب جوجل. حاول مرة أخرى.',
    'ALREADY_REGISTERED': 'هذا الحساب مسجّل مسبقًا.',
    'INVALID_PHONE': 'رقم الهاتف غير صالح.',
    'PHONE_TAKEN': 'رقم الهاتف مستخدم في حساب آخر.',
    'WEAK_PASSWORD': 'كلمة المرور ضعيفة. استخدم 8 أحرف على الأقل وليس أرقامًا فقط.',
    'SAME_PASSWORD': 'كلمة المرور الجديدة يجب أن تختلف عن الحالية.',
    'NOT_A_PASSWORD_ACCOUNT': 'هذا الحساب مرتبط بجوجل ولا يستخدم كلمة مرور.',
    'CURRENT_PASSWORD_REQUIRED': 'أدخل كلمة المرور الحالية.',

    // Addresses.
    'ADDRESS_NOT_FOUND': 'العنوان غير موجود.',
    'ADDRESS_LIMIT_REACHED': 'وصلت إلى الحد الأقصى من العناوين.',
    'INVALID_LOCATION': 'الموقع المحدد خارج سوريا.',

    // Catalog management (admin-side codes, kept so no lookup is unmapped).
    'CANNOT_MODIFY_SELF': 'لا يمكنك تعديل حسابك بهذه الطريقة.',
    'CATEGORY_NOT_FOUND': 'القسم غير موجود.',
    'BRAND_NOT_FOUND': 'العلامة التجارية غير موجودة.',
    'PRODUCT_NOT_FOUND': 'المنتج غير موجود.',
    'VARIANT_NOT_FOUND': 'الخيار المحدد غير موجود.',
    'IMAGE_NOT_FOUND': 'الصورة غير موجودة.',
    'ATTRIBUTE_NOT_FOUND': 'الخاصية غير موجودة.',
    'SLUG_TAKEN': 'المعرّف مستخدم مسبقًا.',
    'SKU_TAKEN': 'رمز المنتج مستخدم مسبقًا.',
    'CATEGORY_NOT_EMPTY': 'لا يمكن حذف قسم يحتوي على عناصر.',
    'CATEGORY_DEPTH_EXCEEDED': 'تجاوز القسم الحد الأقصى للتفرّع.',
    'BRAND_HAS_PRODUCTS': 'لا يمكن حذف علامة تجارية لها منتجات.',
    'ATTRIBUTE_KEY_TAKEN': 'مفتاح الخاصية مستخدم مسبقًا.',
    'ATTRIBUTE_IN_USE': 'الخاصية مستخدمة ولا يمكن حذفها.',
    'OPTION_IN_USE': 'الخيار مستخدم ولا يمكن حذفه.',
    'VARIANT_OPTION_IN_USE': 'الخيار مستخدم في نسخة منتج ولا يمكن حذفه.',
    'UNKNOWN_ATTRIBUTE': 'خاصية غير معروفة.',
    'INVALID_ATTRIBUTE_VALUE': 'قيمة الخاصية غير صالحة.',
    'MISSING_REQUIRED_ATTRIBUTE': 'خاصية مطلوبة ناقصة.',
    'INVALID_VARIANT_OPTIONS': 'خيارات النسخة غير صالحة.',
    'DUPLICATE_VARIANT': 'هذه النسخة موجودة مسبقًا.',
    'PRODUCT_TYPE_IMMUTABLE': 'لا يمكن تغيير نوع المنتج.',
    'INVALID_PRODUCT_FOR_TYPE': 'بيانات المنتج لا تناسب نوعه.',
    'PRODUCT_NOT_PUBLISHABLE': 'المنتج غير جاهز للنشر.',
    'PRODUCT_HAS_ORDERS': 'لا يمكن حذف منتج له طلبات.',
    'PRODUCT_IN_BUNDLE': 'المنتج جزء من حزمة ولا يمكن حذفه.',
    'VARIANT_HAS_ORDERS': 'لا يمكن حذف نسخة لها طلبات.',
    'VARIANT_IN_BUNDLE': 'النسخة جزء من حزمة ولا يمكن حذفها.',
    'INVALID_BUNDLE_ITEM': 'عنصر الحزمة غير صالح.',
    'BUNDLE_CURRENCY_MISMATCH': 'يجب أن تكون عناصر الحزمة بعملة واحدة.',
    'UNSUPPORTED_CURRENCY': 'العملة غير مدعومة.',
    'STOCK_NEGATIVE': 'لا يمكن أن يكون المخزون سالبًا.',
    'IMAGE_LIMIT_REACHED': 'وصلت إلى الحد الأقصى من الصور.',
    'IMAGE_ORDER_MISMATCH': 'ترتيب الصور غير صحيح.',
    'FILE_TOO_LARGE': 'حجم الملف كبير جدًا.',
    'INVALID_IMAGE': 'الصورة غير صالحة.',
    'INVALID_FILTER': 'خيارات التصفية غير صالحة.',

    // Cart, favorites and orders.
    'CART_ITEM_NOT_FOUND': 'العنصر غير موجود في السلة.',
    'VARIANT_REQUIRED': 'اختر أحد الخيارات أولًا.',
    'VARIANT_NOT_ALLOWED': 'هذا المنتج لا يحتوي على خيارات.',
    'QUANTITY_LIMIT_EXCEEDED': 'تجاوزت الكمية الحد المسموح.',
    'INSUFFICIENT_STOCK': 'الكمية المطلوبة غير متوفرة.',
    'OUT_OF_STOCK': 'المنتج غير متوفر حاليًا.',
    'CART_LIMIT_REACHED': 'وصلت السلة إلى الحد الأقصى من العناصر.',
    'FAVORITES_LIMIT_REACHED': 'وصلت المفضلة إلى الحد الأقصى من العناصر.',
    'ORDER_NOT_FOUND': 'الطلب غير موجود.',
    'CART_EMPTY': 'السلة فارغة.',
    'CART_HAS_ISSUES': 'في السلة عناصر تحتاج إلى مراجعة قبل إتمام الطلب.',
    'DELIVERY_METHOD_NOT_FOUND': 'طريقة التوصيل غير موجودة.',
    'DELIVERY_METHOD_NOT_AVAILABLE': 'طريقة التوصيل غير متاحة لمحافظتك.',
    'ADDRESS_REQUIRED': 'اختر عنوان التوصيل.',
    'PRICE_CHANGED': 'تغيّر سعر بعض المنتجات. راجع السلة.',
    'ORDER_NOT_CANCELLABLE': 'لا يمكن إلغاء هذا الطلب.',
    'INVALID_STATUS_TRANSITION': 'لا يمكن تغيير حالة الطلب إلى هذه الحالة.',

    // Notifications and banners.
    'NOTIFICATION_NOT_FOUND': 'الإشعار غير موجود.',
    'NOTIFICATION_NOT_EDITABLE': 'لا يمكن تعديل هذا الإشعار.',
    'INVALID_SCHEDULE': 'موعد الجدولة غير صالح.',
    'INVALID_LINK': 'الرابط غير صالح.',
    'BANNER_NOT_FOUND': 'البانر غير موجود.',
    'BANNER_ORDER_MISMATCH': 'ترتيب البانرات غير صحيح.',
  };
}
