import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:lamsa_app/core/images/image_urls.dart';

part 'catalog_models.g.dart';

@JsonEnum(fieldRename: FieldRename.snake)
enum StockStatus { inStock, low, out }

@JsonEnum()
enum ProductType { simple, variable, bundle }

@JsonEnum()
enum OptionType { color, select }

@JsonEnum()
enum AttributeType { text, number, select, multiselect, boolean, date }

// Money stays a string plus currency on the wire; parse with `Money.parse`.

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class BrandRef extends Equatable {
  const BrandRef({required this.id, required this.name, required this.slug});

  factory BrandRef.fromJson(Map<String, dynamic> json) =>
      _$BrandRefFromJson(json);

  final int id;
  final String name;
  final String slug;

  Map<String, dynamic> toJson() => _$BrandRefToJson(this);

  @override
  List<Object?> get props => [id, name, slug];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class CategoryRef extends Equatable {
  const CategoryRef({required this.id, required this.name, required this.slug});

  factory CategoryRef.fromJson(Map<String, dynamic> json) =>
      _$CategoryRefFromJson(json);

  final int id;
  final String name;
  final String slug;

  Map<String, dynamic> toJson() => _$CategoryRefToJson(this);

  @override
  List<Object?> get props => [id, name, slug];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class Swatch extends Equatable {
  const Swatch({required this.name, required this.hex});

  factory Swatch.fromJson(Map<String, dynamic> json) => _$SwatchFromJson(json);

  final String name;
  final String hex;

  Map<String, dynamic> toJson() => _$SwatchToJson(this);

  @override
  List<Object?> get props => [name, hex];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class CategoryNode extends Equatable {
  const CategoryNode({
    required this.id,
    required this.name,
    required this.slug,
    required this.productCount,
    this.description,
    this.image,
    this.children = const [],
  });

  factory CategoryNode.fromJson(Map<String, dynamic> json) =>
      _$CategoryNodeFromJson(json);

  final int id;
  final String name;
  final String slug;
  final String? description;
  @JsonKey(fromJson: ImageUrls.fromJson)
  final ImageUrls? image;
  final int productCount;
  final List<CategoryNode> children;

  Map<String, dynamic> toJson() => _$CategoryNodeToJson(this);

  @override
  List<Object?> get props =>
      [id, name, slug, description, image, productCount, children];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class AttributeDefinition extends Equatable {
  const AttributeDefinition({
    required this.key,
    required this.label,
    required this.type,
    this.unit,
    this.options,
  });

  factory AttributeDefinition.fromJson(Map<String, dynamic> json) =>
      _$AttributeDefinitionFromJson(json);

  final String key;
  final String label;
  @JsonKey(unknownEnumValue: AttributeType.text)
  final AttributeType type;
  final String? unit;
  final List<String>? options;

  Map<String, dynamic> toJson() => _$AttributeDefinitionToJson(this);

  @override
  List<Object?> get props => [key, label, type, unit, options];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class CategoryDetail extends Equatable {
  const CategoryDetail({
    required this.id,
    required this.name,
    required this.slug,
    required this.productCount,
    this.description,
    this.image,
    this.breadcrumb = const [],
    this.children = const [],
    this.attributes = const [],
  });

  factory CategoryDetail.fromJson(Map<String, dynamic> json) =>
      _$CategoryDetailFromJson(json);

  final int id;
  final String name;
  final String slug;
  final String? description;
  @JsonKey(fromJson: ImageUrls.fromJson)
  final ImageUrls? image;
  final int productCount;
  final List<CategoryRef> breadcrumb;
  final List<CategoryNode> children;
  final List<AttributeDefinition> attributes;

  Map<String, dynamic> toJson() => _$CategoryDetailToJson(this);

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        description,
        image,
        productCount,
        breadcrumb,
        children,
        attributes,
      ];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class Brand extends Equatable {
  const Brand({
    required this.id,
    required this.name,
    required this.slug,
    required this.productCount,
    this.description,
    this.logo,
    this.isOwnBrand = false,
  });

  factory Brand.fromJson(Map<String, dynamic> json) => _$BrandFromJson(json);

  final int id;
  final String name;
  final String slug;
  final String? description;
  @JsonKey(fromJson: ImageUrls.fromJson)
  final ImageUrls? logo;
  final bool isOwnBrand;
  final int productCount;

  Map<String, dynamic> toJson() => _$BrandToJson(this);

  @override
  List<Object?> get props =>
      [id, name, slug, description, logo, isOwnBrand, productCount];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class ProductCard extends Equatable {
  const ProductCard({
    required this.id,
    required this.slug,
    required this.name,
    required this.type,
    required this.currency,
    required this.price,
    this.brand,
    this.category,
    this.image,
    this.compareAtPrice,
    this.discountPercent,
    this.isNew = false,
    this.isOnSale = false,
    this.inStock = true,
    this.swatches = const [],
  });

  factory ProductCard.fromJson(Map<String, dynamic> json) =>
      _$ProductCardFromJson(json);

  final int id;
  final String slug;
  final String name;
  @JsonKey(unknownEnumValue: ProductType.simple)
  final ProductType type;
  final String currency;
  final BrandRef? brand;
  final CategoryRef? category;
  @JsonKey(fromJson: ImageUrls.fromJson)
  final ImageUrls? image;
  final String price;
  final String? compareAtPrice;
  final int? discountPercent;
  final bool isNew;
  final bool isOnSale;
  final bool inStock;
  final List<Swatch> swatches;

  Map<String, dynamic> toJson() => _$ProductCardToJson(this);

  @override
  List<Object?> get props => [
        id,
        slug,
        name,
        type,
        currency,
        brand,
        category,
        image,
        price,
        compareAtPrice,
        discountPercent,
        isNew,
        isOnSale,
        inStock,
        swatches,
      ];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class ProductPage extends Equatable {
  const ProductPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory ProductPage.fromJson(Map<String, dynamic> json) =>
      _$ProductPageFromJson(json);

  final List<ProductCard> items;
  final int page;
  final int pageSize;
  final int total;

  Map<String, dynamic> toJson() => _$ProductPageToJson(this);

  @override
  List<Object?> get props => [items, page, pageSize, total];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class ProductImage extends Equatable {
  const ProductImage({
    required this.id,
    this.altText,
    this.variantId,
    this.color,
    this.width,
    this.height,
    this.urls,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) =>
      _$ProductImageFromJson(json);

  final int id;
  final String? altText;
  final int? variantId;
  final String? color;
  final int? width;
  final int? height;
  @JsonKey(fromJson: ImageUrls.fromJson)
  final ImageUrls? urls;

  Map<String, dynamic> toJson() => _$ProductImageToJson(this);

  @override
  List<Object?> get props =>
      [id, altText, variantId, color, width, height, urls];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class AttributeValue extends Equatable {
  const AttributeValue({
    required this.key,
    required this.label,
    required this.display,
    this.unit,
  });

  factory AttributeValue.fromJson(Map<String, dynamic> json) =>
      _$AttributeValueFromJson(json);

  final String key;
  final String label;
  final String? unit;
  final String display;

  Map<String, dynamic> toJson() => _$AttributeValueToJson(this);

  @override
  List<Object?> get props => [key, label, unit, display];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class OptionValue extends Equatable {
  const OptionValue({required this.value, this.hex});

  factory OptionValue.fromJson(Map<String, dynamic> json) =>
      _$OptionValueFromJson(json);

  final String value;
  final String? hex;

  Map<String, dynamic> toJson() => _$OptionValueToJson(this);

  @override
  List<Object?> get props => [value, hex];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class VariantOption extends Equatable {
  const VariantOption({
    required this.key,
    required this.label,
    required this.type,
    this.values = const [],
  });

  factory VariantOption.fromJson(Map<String, dynamic> json) =>
      _$VariantOptionFromJson(json);

  final String key;
  final String label;
  @JsonKey(unknownEnumValue: OptionType.select)
  final OptionType type;
  final List<OptionValue> values;

  Map<String, dynamic> toJson() => _$VariantOptionToJson(this);

  @override
  List<Object?> get props => [key, label, type, values];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class Variant extends Equatable {
  const Variant({
    required this.id,
    required this.options,
    required this.currency,
    required this.price,
    required this.currentPrice,
    required this.stockStatus,
    this.salePrice,
    this.discountPercent,
    this.stockLeft,
    this.imageIds = const [],
  });

  factory Variant.fromJson(Map<String, dynamic> json) =>
      _$VariantFromJson(json);

  final int id;
  final Map<String, String> options;
  final String currency;
  final String price;
  final String? salePrice;
  final String currentPrice;
  final int? discountPercent;
  @JsonKey(unknownEnumValue: StockStatus.out)
  final StockStatus stockStatus;
  final int? stockLeft;
  final List<int> imageIds;

  Map<String, dynamic> toJson() => _$VariantToJson(this);

  @override
  List<Object?> get props => [
        id,
        options,
        currency,
        price,
        salePrice,
        currentPrice,
        discountPercent,
        stockStatus,
        stockLeft,
        imageIds,
      ];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class BundleItemProduct extends Equatable {
  const BundleItemProduct({
    required this.id,
    required this.slug,
    required this.name,
    this.image,
  });

  factory BundleItemProduct.fromJson(Map<String, dynamic> json) =>
      _$BundleItemProductFromJson(json);

  final int id;
  final String slug;
  final String name;
  @JsonKey(fromJson: ImageUrls.fromJson)
  final ImageUrls? image;

  Map<String, dynamic> toJson() => _$BundleItemProductToJson(this);

  @override
  List<Object?> get props => [id, slug, name, image];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class BundleItem extends Equatable {
  const BundleItem({
    required this.product,
    required this.quantity,
    this.variantLabel,
  });

  factory BundleItem.fromJson(Map<String, dynamic> json) =>
      _$BundleItemFromJson(json);

  final BundleItemProduct product;
  final String? variantLabel;
  final int quantity;

  Map<String, dynamic> toJson() => _$BundleItemToJson(this);

  @override
  List<Object?> get props => [product, variantLabel, quantity];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class ProductDetail extends Equatable {
  const ProductDetail({
    required this.id,
    required this.slug,
    required this.name,
    required this.type,
    required this.currency,
    required this.price,
    this.brand,
    this.category,
    this.image,
    this.compareAtPrice,
    this.discountPercent,
    this.isNew = false,
    this.isOnSale = false,
    this.inStock = true,
    this.swatches = const [],
    this.description,
    this.breadcrumb = const [],
    this.attributes = const [],
    this.images = const [],
    this.regularPrice,
    this.salePrice,
    this.currentPrice,
    this.stockStatus,
    this.stockLeft,
    this.variantOptions = const [],
    this.variants = const [],
    this.items = const [],
  });

  factory ProductDetail.fromJson(Map<String, dynamic> json) =>
      _$ProductDetailFromJson(json);

  final int id;
  final String slug;
  final String name;
  @JsonKey(unknownEnumValue: ProductType.simple)
  final ProductType type;
  final String currency;
  final BrandRef? brand;
  final CategoryRef? category;
  @JsonKey(fromJson: ImageUrls.fromJson)
  final ImageUrls? image;
  final String price;
  final String? compareAtPrice;
  final int? discountPercent;
  final bool isNew;
  final bool isOnSale;
  final bool inStock;
  final List<Swatch> swatches;
  final String? description;
  final List<CategoryRef> breadcrumb;
  final List<AttributeValue> attributes;
  final List<ProductImage> images;
  final String? regularPrice;
  final String? salePrice;
  final String? currentPrice;
  @JsonKey(unknownEnumValue: StockStatus.out)
  final StockStatus? stockStatus;
  final int? stockLeft;
  final List<VariantOption> variantOptions;
  final List<Variant> variants;

  /// Bundle components (only present for `type == bundle`).
  final List<BundleItem> items;

  Map<String, dynamic> toJson() => _$ProductDetailToJson(this);

  @override
  List<Object?> get props => [
        id,
        slug,
        name,
        type,
        currency,
        brand,
        category,
        image,
        price,
        compareAtPrice,
        discountPercent,
        isNew,
        isOnSale,
        inStock,
        swatches,
        description,
        breadcrumb,
        attributes,
        images,
        regularPrice,
        salePrice,
        currentPrice,
        stockStatus,
        stockLeft,
        variantOptions,
        variants,
        items,
      ];
}

// ---- Facets ----

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class BrandFacet extends Equatable {
  const BrandFacet({
    required this.slug,
    required this.name,
    required this.count,
  });

  factory BrandFacet.fromJson(Map<String, dynamic> json) =>
      _$BrandFacetFromJson(json);

  final String slug;
  final String name;
  final int count;

  Map<String, dynamic> toJson() => _$BrandFacetToJson(this);

  @override
  List<Object?> get props => [slug, name, count];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class PriceRange extends Equatable {
  const PriceRange({required this.currency, this.min, this.max});

  factory PriceRange.fromJson(Map<String, dynamic> json) =>
      _$PriceRangeFromJson(json);

  final String currency;
  final String? min;
  final String? max;

  Map<String, dynamic> toJson() => _$PriceRangeToJson(this);

  @override
  List<Object?> get props => [currency, min, max];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class FacetValue extends Equatable {
  const FacetValue({required this.value, required this.count, this.hex});

  factory FacetValue.fromJson(Map<String, dynamic> json) =>
      _$FacetValueFromJson(json);

  final String value;
  final int count;
  final String? hex;

  Map<String, dynamic> toJson() => _$FacetValueToJson(this);

  @override
  List<Object?> get props => [value, count, hex];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class AttributeFacet extends Equatable {
  const AttributeFacet({
    required this.key,
    required this.label,
    required this.type,
    this.unit,
    this.min,
    this.max,
    this.values,
  });

  factory AttributeFacet.fromJson(Map<String, dynamic> json) =>
      _$AttributeFacetFromJson(json);

  final String key;
  final String label;
  @JsonKey(unknownEnumValue: AttributeType.text)
  final AttributeType type;
  final String? unit;
  final num? min;
  final num? max;
  final List<FacetValue>? values;

  Map<String, dynamic> toJson() => _$AttributeFacetToJson(this);

  @override
  List<Object?> get props => [key, label, type, unit, min, max, values];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class OptionFacet extends Equatable {
  const OptionFacet({
    required this.key,
    required this.label,
    required this.type,
    this.values = const [],
  });

  factory OptionFacet.fromJson(Map<String, dynamic> json) =>
      _$OptionFacetFromJson(json);

  final String key;
  final String label;
  @JsonKey(unknownEnumValue: OptionType.select)
  final OptionType type;
  final List<FacetValue> values;

  Map<String, dynamic> toJson() => _$OptionFacetToJson(this);

  @override
  List<Object?> get props => [key, label, type, values];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class Facets extends Equatable {
  const Facets({
    this.brands = const [],
    this.prices = const [],
    this.attributes = const [],
    this.options = const [],
  });

  factory Facets.fromJson(Map<String, dynamic> json) => _$FacetsFromJson(json);

  final List<BrandFacet> brands;
  final List<PriceRange> prices;
  final List<AttributeFacet> attributes;
  final List<OptionFacet> options;

  Map<String, dynamic> toJson() => _$FacetsToJson(this);

  @override
  List<Object?> get props => [brands, prices, attributes, options];
}

// ---- Banners ----

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class BannerLink extends Equatable {
  const BannerLink({required this.type, this.value});

  factory BannerLink.fromJson(Map<String, dynamic> json) =>
      _$BannerLinkFromJson(json);

  /// `none | category | product | brand | new | sale | url` (others ignored).
  final String type;
  final String? value;

  Map<String, dynamic> toJson() => _$BannerLinkToJson(this);

  @override
  List<Object?> get props => [type, value];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class HomeBanner extends Equatable {
  const HomeBanner({
    required this.id,
    required this.title,
    required this.link,
    this.subtitle,
    this.image,
  });

  factory HomeBanner.fromJson(Map<String, dynamic> json) => _$HomeBannerFromJson(json);

  final int id;
  final String title;
  final String? subtitle;
  @JsonKey(fromJson: ImageUrls.fromJson)
  final ImageUrls? image;
  final BannerLink link;

  Map<String, dynamic> toJson() => _$HomeBannerToJson(this);

  @override
  List<Object?> get props => [id, title, subtitle, image, link];
}
