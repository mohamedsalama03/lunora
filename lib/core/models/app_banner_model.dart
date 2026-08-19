class AppBannerItem {
  const AppBannerItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.badgeText,
    this.ctaText,
    required this.imageUrl,
    this.mobileImageUrl,
    this.tabletImageUrl,
    this.desktopImageUrl,
    required this.type,
    required this.linkedId,
    required this.externalLink,
    required this.sortOrder,
  });

  final int id;
  final String? title;
  final String? subtitle;
  final String? badgeText;
  final String? ctaText;
  final String? imageUrl;
  final String? mobileImageUrl;
  final String? tabletImageUrl;
  final String? desktopImageUrl;
  final String type;
  final int? linkedId;
  final String? externalLink;
  final int sortOrder;

  String? imageUrlForWidth(double width) {
    if (width >= 900) {
      return desktopImageUrl ?? tabletImageUrl ?? mobileImageUrl ?? imageUrl;
    }
    if (width >= 600) {
      return tabletImageUrl ?? desktopImageUrl ?? mobileImageUrl ?? imageUrl;
    }

    return mobileImageUrl ?? imageUrl ?? tabletImageUrl ?? desktopImageUrl;
  }

  bool get hasAnyImage =>
      imageUrl != null ||
      mobileImageUrl != null ||
      tabletImageUrl != null ||
      desktopImageUrl != null;

  factory AppBannerItem.fromJson(Map<String, dynamic> json) {
    return AppBannerItem(
      id: _asInt(json['id']),
      title: _asNullableString(json['title']),
      subtitle:
          _asNullableString(json['subtitle']) ??
          _asNullableString(json['description']),
      badgeText:
          _asNullableString(json['badge_text']) ??
          _asNullableString(json['badge']),
      ctaText:
          _asNullableString(json['cta_text']) ??
          _asNullableString(json['button_text']) ??
          _asNullableString(json['button_label']),
      imageUrl: _asNullableString(json['image_url']),
      mobileImageUrl:
          _asNullableString(json['mobile_image_url']) ??
          _asNullableString(json['image_url_mobile']) ??
          _asNullableString(json['image_mobile_url']),
      tabletImageUrl:
          _asNullableString(json['tablet_image_url']) ??
          _asNullableString(json['image_url_tablet']) ??
          _asNullableString(json['image_tablet_url']),
      desktopImageUrl:
          _asNullableString(json['desktop_image_url']) ??
          _asNullableString(json['image_url_desktop']) ??
          _asNullableString(json['image_desktop_url']),
      type: _asNullableString(json['type']) ?? 'none',
      linkedId: _asNullableInt(json['linked_id']),
      externalLink: _asNullableString(json['external_link']),
      sortOrder: _asInt(json['sort_order']),
    );
  }
}

class AppBannersResponse {
  const AppBannersResponse({required this.data});

  final List<AppBannerItem> data;

  factory AppBannersResponse.fromJson(Map<String, dynamic> json) {
    final items = json['data'] as List<dynamic>? ?? const <dynamic>[];

    return AppBannersResponse(
      data: items
          .whereType<Map>()
          .map(
            (item) => AppBannerItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.hasAnyImage)
          .toList(growable: false),
    );
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String? _asNullableString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
