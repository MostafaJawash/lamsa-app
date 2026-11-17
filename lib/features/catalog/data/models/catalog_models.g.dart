// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrandRef _$BrandRefFromJson(Map<String, dynamic> json) => BrandRef(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  slug: json['slug'] as String,
);

Map<String, dynamic> _$BrandRefToJson(BrandRef instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'slug': instance.slug,
};

CategoryRef _$CategoryRefFromJson(Map<String, dynamic> json) => CategoryRef(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  slug: json['slug'] as String,
);

Map<String, dynamic> _$CategoryRefToJson(CategoryRef instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
    };

Swatch _$SwatchFromJson(Map<String, dynamic> json) =>
    Swatch(name: json['name'] as String, hex: json['hex'] as String);

Map<String, dynamic> _$SwatchToJson(Swatch instance) => <String, dynamic>{
  'name': instance.name,
  'hex': instance.hex,
};

CategoryNode _$CategoryNodeFromJson(Map<String, dynamic> json) => CategoryNode(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  slug: json['slug'] as String,
  productCount: (json['product_count'] as num).toInt(),
  description: json['description'] as String?,
  image: ImageUrls.fromJson(json['image']),
  children:
      (json['children'] as List<dynamic>?)
          ?.map((e) => CategoryNode.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$CategoryNodeToJson(CategoryNode instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'description': instance.description,
      'image': instance.image?.toJson(),
      'product_count': instance.productCount,
      'children': instance.children.map((e) => e.toJson()).toList(),
    };

AttributeDefinition _$AttributeDefinitionFromJson(Map<String, dynamic> json) =>
    AttributeDefinition(
      key: json['key'] as String,
      label: json['label'] as String,
      type: $enumDecode(
        _$AttributeTypeEnumMap,
        json['type'],
        unknownValue: AttributeType.text,
      ),
      unit: json['unit'] as String?,
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$AttributeDefinitionToJson(
  AttributeDefinition instance,
) => <String, dynamic>{
  'key': instance.key,
  'label': instance.label,
  'type': _$AttributeTypeEnumMap[instance.type]!,
  'unit': instance.unit,
  'options': instance.options,
};

const _$AttributeTypeEnumMap = {
  AttributeType.text: 'text',
  AttributeType.number: 'number',
  AttributeType.select: 'select',
  AttributeType.multiselect: 'multiselect',
  AttributeType.boolean: 'boolean',
  AttributeType.date: 'date',
};

CategoryDetail _$CategoryDetailFromJson(Map<String, dynamic> json) =>
    CategoryDetail(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      slug: json['slug'] as String,
      productCount: (json['product_count'] as num).toInt(),
      description: json['description'] as String?,
      image: ImageUrls.fromJson(json['image']),
      breadcrumb:
          (json['breadcrumb'] as List<dynamic>?)
              ?.map((e) => CategoryRef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      children:
          (json['children'] as List<dynamic>?)
              ?.map((e) => CategoryNode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      attributes:
          (json['attributes'] as List<dynamic>?)
              ?.map(
                (e) => AttributeDefinition.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$CategoryDetailToJson(CategoryDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'description': instance.description,
      'image': instance.image?.toJson(),
      'product_count': instance.productCount,
      'breadcrumb': instance.breadcrumb.map((e) => e.toJson()).toList(),
      'children': instance.children.map((e) => e.toJson()).toList(),
      'attributes': instance.attributes.map((e) => e.toJson()).toList(),
    };

Brand _$BrandFromJson(Map<String, dynamic> json) => Brand(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  slug: json['slug'] as String,
  productCount: (json['product_count'] as num).toInt(),
  description: json['description'] as String?,
  logo: ImageUrls.fromJson(json['logo']),
  isOwnBrand: json['is_own_brand'] as bool? ?? false,
);

Map<String, dynamic> _$BrandToJson(Brand instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'slug': instance.slug,
  'description': instance.description,
  'logo': instance.logo?.toJson(),
  'is_own_brand': instance.isOwnBrand,
  'product_count': instance.productCount,
};

ProductCard _$ProductCardFromJson(Map<String, dynamic> json) => ProductCard(
  id: (json['id'] as num).toInt(),
  slug: json['slug'] as String,
  name: json['name'] as String,
  type: $enumDecode(
    _$ProductTypeEnumMap,
    json['type'],
    unknownValue: ProductType.simple,
  ),
  currency: json['currency'] as String,
  price: json['price'] as String,
  brand: json['brand'] == null
      ? null
      : BrandRef.fromJson(json['brand'] as Map<String, dynamic>),
  category: json['category'] == null
      ? null
      : CategoryRef.fromJson(json['category'] as Map<String, dynamic>),
  image: ImageUrls.fromJson(json['image']),
  compareAtPrice: json['compare_at_price'] as String?,
  discountPercent: (json['discount_percent'] as num?)?.toInt(),
  isNew: json['is_new'] as bool? ?? false,
  isOnSale: json['is_on_sale'] as bool? ?? false,
  inStock: json['in_stock'] as bool? ?? true,
  swatches:
      (json['swatches'] as List<dynamic>?)
          ?.map((e) => Swatch.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$ProductCardToJson(ProductCard instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'name': instance.name,
      'type': _$ProductTypeEnumMap[instance.type]!,
      'currency': instance.currency,
      'brand': instance.brand?.toJson(),
      'category': instance.category?.toJson(),
      'image': instance.image?.toJson(),
      'price': instance.price,
      'compare_at_price': instance.compareAtPrice,
      'discount_percent': instance.discountPercent,
      'is_new': instance.isNew,
      'is_on_sale': instance.isOnSale,
      'in_stock': instance.inStock,
      'swatches': instance.swatches.map((e) => e.toJson()).toList(),
    };

const _$ProductTypeEnumMap = {
  ProductType.simple: 'simple',
  ProductType.variable: 'variable',
  ProductType.bundle: 'bundle',
};

ProductPage _$ProductPageFromJson(Map<String, dynamic> json) => ProductPage(
  items: (json['items'] as List<dynamic>)
      .map((e) => ProductCard.fromJson(e as Map<String, dynamic>))
      .toList(),
  page: (json['page'] as num).toInt(),
  pageSize: (json['page_size'] as num).toInt(),
  total: (json['total'] as num).toInt(),
);

Map<String, dynamic> _$ProductPageToJson(ProductPage instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'page': instance.page,
      'page_size': instance.pageSize,
      'total': instance.total,
    };

ProductImage _$ProductImageFromJson(Map<String, dynamic> json) => ProductImage(
  id: (json['id'] as num).toInt(),
  altText: json['alt_text'] as String?,
  variantId: (json['variant_id'] as num?)?.toInt(),
  color: json['color'] as String?,
  width: (json['width'] as num?)?.toInt(),
  height: (json['height'] as num?)?.toInt(),
  urls: ImageUrls.fromJson(json['urls']),
);

Map<String, dynamic> _$ProductImageToJson(ProductImage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'alt_text': instance.altText,
      'variant_id': instance.variantId,
      'color': instance.color,
      'width': instance.width,
      'height': instance.height,
      'urls': instance.urls?.toJson(),
    };

AttributeValue _$AttributeValueFromJson(Map<String, dynamic> json) =>
    AttributeValue(
      key: json['key'] as String,
      label: json['label'] as String,
      display: json['display'] as String,
      unit: json['unit'] as String?,
    );

Map<String, dynamic> _$AttributeValueToJson(AttributeValue instance) =>
    <String, dynamic>{
      'key': instance.key,
      'label': instance.label,
      'unit': instance.unit,
      'display': instance.display,
    };

OptionValue _$OptionValueFromJson(Map<String, dynamic> json) =>
    OptionValue(value: json['value'] as String, hex: json['hex'] as String?);

Map<String, dynamic> _$OptionValueToJson(OptionValue instance) =>
    <String, dynamic>{'value': instance.value, 'hex': instance.hex};

VariantOption _$VariantOptionFromJson(Map<String, dynamic> json) =>
    VariantOption(
      key: json['key'] as String,
      label: json['label'] as String,
      type: $enumDecode(
        _$OptionTypeEnumMap,
        json['type'],
        unknownValue: OptionType.select,
      ),
      values:
          (json['values'] as List<dynamic>?)
              ?.map((e) => OptionValue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$VariantOptionToJson(VariantOption instance) =>
    <String, dynamic>{
      'key': instance.key,
      'label': instance.label,
      'type': _$OptionTypeEnumMap[instance.type]!,
      'values': instance.values.map((e) => e.toJson()).toList(),
    };

const _$OptionTypeEnumMap = {
  OptionType.color: 'color',
  OptionType.select: 'select',
};

Variant _$VariantFromJson(Map<String, dynamic> json) => Variant(
  id: (json['id'] as num).toInt(),
  options: Map<String, String>.from(json['options'] as Map),
  currency: json['currency'] as String,
  price: json['price'] as String,
  currentPrice: json['current_price'] as String,
  stockStatus: $enumDecode(
    _$StockStatusEnumMap,
    json['stock_status'],
    unknownValue: StockStatus.out,
  ),
  salePrice: json['sale_price'] as String?,
  discountPercent: (json['discount_percent'] as num?)?.toInt(),
  stockLeft: (json['stock_left'] as num?)?.toInt(),
  imageIds:
      (json['image_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
);

Map<String, dynamic> _$VariantToJson(Variant instance) => <String, dynamic>{
  'id': instance.id,
  'options': instance.options,
  'currency': instance.currency,
  'price': instance.price,
  'sale_price': instance.salePrice,
  'current_price': instance.currentPrice,
  'discount_percent': instance.discountPercent,
  'stock_status': _$StockStatusEnumMap[instance.stockStatus]!,
  'stock_left': instance.stockLeft,
  'image_ids': instance.imageIds,
};

const _$StockStatusEnumMap = {
  StockStatus.inStock: 'in_stock',
  StockStatus.low: 'low',
  StockStatus.out: 'out',
};

BundleItemProduct _$BundleItemProductFromJson(Map<String, dynamic> json) =>
    BundleItemProduct(
      id: (json['id'] as num).toInt(),
      slug: json['slug'] as String,
      name: json['name'] as String,
      image: ImageUrls.fromJson(json['image']),
    );

Map<String, dynamic> _$BundleItemProductToJson(BundleItemProduct instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'name': instance.name,
      'image': instance.image?.toJson(),
    };

BundleItem _$BundleItemFromJson(Map<String, dynamic> json) => BundleItem(
  product: BundleItemProduct.fromJson(json['product'] as Map<String, dynamic>),
  quantity: (json['quantity'] as num).toInt(),
  variantLabel: json['variant_label'] as String?,
);

Map<String, dynamic> _$BundleItemToJson(BundleItem instance) =>
    <String, dynamic>{
      'product': instance.product.toJson(),
      'variant_label': instance.variantLabel,
      'quantity': instance.quantity,
    };

ProductDetail _$ProductDetailFromJson(Map<String, dynamic> json) =>
    ProductDetail(
      id: (json['id'] as num).toInt(),
      slug: json['slug'] as String,
      name: json['name'] as String,
      type: $enumDecode(
        _$ProductTypeEnumMap,
        json['type'],
        unknownValue: ProductType.simple,
      ),
      currency: json['currency'] as String,
      price: json['price'] as String,
      brand: json['brand'] == null
          ? null
          : BrandRef.fromJson(json['brand'] as Map<String, dynamic>),
      category: json['category'] == null
          ? null
          : CategoryRef.fromJson(json['category'] as Map<String, dynamic>),
      image: ImageUrls.fromJson(json['image']),
      compareAtPrice: json['compare_at_price'] as String?,
      discountPercent: (json['discount_percent'] as num?)?.toInt(),
      isNew: json['is_new'] as bool? ?? false,
      isOnSale: json['is_on_sale'] as bool? ?? false,
      inStock: json['in_stock'] as bool? ?? true,
      swatches:
          (json['swatches'] as List<dynamic>?)
              ?.map((e) => Swatch.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      description: json['description'] as String?,
      breadcrumb:
          (json['breadcrumb'] as List<dynamic>?)
              ?.map((e) => CategoryRef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      attributes:
          (json['attributes'] as List<dynamic>?)
              ?.map((e) => AttributeValue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      images:
          (json['images'] as List<dynamic>?)
              ?.map((e) => ProductImage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      regularPrice: json['regular_price'] as String?,
      salePrice: json['sale_price'] as String?,
      currentPrice: json['current_price'] as String?,
      stockStatus: $enumDecodeNullable(
        _$StockStatusEnumMap,
        json['stock_status'],
        unknownValue: StockStatus.out,
      ),
      stockLeft: (json['stock_left'] as num?)?.toInt(),
      variantOptions:
          (json['variant_options'] as List<dynamic>?)
              ?.map((e) => VariantOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      variants:
          (json['variants'] as List<dynamic>?)
              ?.map((e) => Variant.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => BundleItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ProductDetailToJson(
  ProductDetail instance,
) => <String, dynamic>{
  'id': instance.id,
  'slug': instance.slug,
  'name': instance.name,
  'type': _$ProductTypeEnumMap[instance.type]!,
  'currency': instance.currency,
  'brand': instance.brand?.toJson(),
  'category': instance.category?.toJson(),
  'image': instance.image?.toJson(),
  'price': instance.price,
  'compare_at_price': instance.compareAtPrice,
  'discount_percent': instance.discountPercent,
  'is_new': instance.isNew,
  'is_on_sale': instance.isOnSale,
  'in_stock': instance.inStock,
  'swatches': instance.swatches.map((e) => e.toJson()).toList(),
  'description': instance.description,
  'breadcrumb': instance.breadcrumb.map((e) => e.toJson()).toList(),
  'attributes': instance.attributes.map((e) => e.toJson()).toList(),
  'images': instance.images.map((e) => e.toJson()).toList(),
  'regular_price': instance.regularPrice,
  'sale_price': instance.salePrice,
  'current_price': instance.currentPrice,
  'stock_status': _$StockStatusEnumMap[instance.stockStatus],
  'stock_left': instance.stockLeft,
  'variant_options': instance.variantOptions.map((e) => e.toJson()).toList(),
  'variants': instance.variants.map((e) => e.toJson()).toList(),
  'items': instance.items.map((e) => e.toJson()).toList(),
};

BrandFacet _$BrandFacetFromJson(Map<String, dynamic> json) => BrandFacet(
  slug: json['slug'] as String,
  name: json['name'] as String,
  count: (json['count'] as num).toInt(),
);

Map<String, dynamic> _$BrandFacetToJson(BrandFacet instance) =>
    <String, dynamic>{
      'slug': instance.slug,
      'name': instance.name,
      'count': instance.count,
    };

PriceRange _$PriceRangeFromJson(Map<String, dynamic> json) => PriceRange(
  currency: json['currency'] as String,
  min: json['min'] as String?,
  max: json['max'] as String?,
);

Map<String, dynamic> _$PriceRangeToJson(PriceRange instance) =>
    <String, dynamic>{
      'currency': instance.currency,
      'min': instance.min,
      'max': instance.max,
    };

FacetValue _$FacetValueFromJson(Map<String, dynamic> json) => FacetValue(
  value: json['value'] as String,
  count: (json['count'] as num).toInt(),
  hex: json['hex'] as String?,
);

Map<String, dynamic> _$FacetValueToJson(FacetValue instance) =>
    <String, dynamic>{
      'value': instance.value,
      'count': instance.count,
      'hex': instance.hex,
    };

AttributeFacet _$AttributeFacetFromJson(Map<String, dynamic> json) =>
    AttributeFacet(
      key: json['key'] as String,
      label: json['label'] as String,
      type: $enumDecode(
        _$AttributeTypeEnumMap,
        json['type'],
        unknownValue: AttributeType.text,
      ),
      unit: json['unit'] as String?,
      min: json['min'] as num?,
      max: json['max'] as num?,
      values: (json['values'] as List<dynamic>?)
          ?.map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AttributeFacetToJson(AttributeFacet instance) =>
    <String, dynamic>{
      'key': instance.key,
      'label': instance.label,
      'type': _$AttributeTypeEnumMap[instance.type]!,
      'unit': instance.unit,
      'min': instance.min,
      'max': instance.max,
      'values': instance.values?.map((e) => e.toJson()).toList(),
    };

OptionFacet _$OptionFacetFromJson(Map<String, dynamic> json) => OptionFacet(
  key: json['key'] as String,
  label: json['label'] as String,
  type: $enumDecode(
    _$OptionTypeEnumMap,
    json['type'],
    unknownValue: OptionType.select,
  ),
  values:
      (json['values'] as List<dynamic>?)
          ?.map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$OptionFacetToJson(OptionFacet instance) =>
    <String, dynamic>{
      'key': instance.key,
      'label': instance.label,
      'type': _$OptionTypeEnumMap[instance.type]!,
      'values': instance.values.map((e) => e.toJson()).toList(),
    };

Facets _$FacetsFromJson(Map<String, dynamic> json) => Facets(
  brands:
      (json['brands'] as List<dynamic>?)
          ?.map((e) => BrandFacet.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  prices:
      (json['prices'] as List<dynamic>?)
          ?.map((e) => PriceRange.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  attributes:
      (json['attributes'] as List<dynamic>?)
          ?.map((e) => AttributeFacet.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  options:
      (json['options'] as List<dynamic>?)
          ?.map((e) => OptionFacet.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$FacetsToJson(Facets instance) => <String, dynamic>{
  'brands': instance.brands.map((e) => e.toJson()).toList(),
  'prices': instance.prices.map((e) => e.toJson()).toList(),
  'attributes': instance.attributes.map((e) => e.toJson()).toList(),
  'options': instance.options.map((e) => e.toJson()).toList(),
};

BannerLink _$BannerLinkFromJson(Map<String, dynamic> json) =>
    BannerLink(type: json['type'] as String, value: json['value'] as String?);

Map<String, dynamic> _$BannerLinkToJson(BannerLink instance) =>
    <String, dynamic>{'type': instance.type, 'value': instance.value};

HomeBanner _$HomeBannerFromJson(Map<String, dynamic> json) => HomeBanner(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  link: BannerLink.fromJson(json['link'] as Map<String, dynamic>),
  subtitle: json['subtitle'] as String?,
  image: ImageUrls.fromJson(json['image']),
);

Map<String, dynamic> _$HomeBannerToJson(HomeBanner instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'subtitle': instance.subtitle,
      'image': instance.image?.toJson(),
      'link': instance.link.toJson(),
    };
