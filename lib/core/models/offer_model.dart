class OfferViewer {
  final bool isAuthenticated;
  final int? customerId;
  final bool isTopCustomer;
  final bool hasPersonalizedOffers;

  OfferViewer({
    required this.isAuthenticated,
    required this.customerId,
    required this.isTopCustomer,
    required this.hasPersonalizedOffers,
  });

  factory OfferViewer.fromJson(Map<String, dynamic> json) {
    return OfferViewer(
      isAuthenticated: json['is_authenticated'] as bool? ?? false,
      customerId: json['customer_id'] as int?,
      isTopCustomer: json['is_top_customer'] as bool? ?? false,
      hasPersonalizedOffers: json['has_personalized_offers'] as bool? ?? false,
    );
  }
}

class OfferItem {
  final int id;
  final String title;
  final String? subtitle;
  final String? description;
  final String? badgeText;
  final String? highlightText;
  final String? couponCode;
  final String? ctaText;
  final String ctaUrl;
  final String ctaWebUrl;
  final String ctaType;
  final String displayMode;
  final String targetAudience;
  final bool isActive;
  final int sortOrder;
  final String? mobileBgImage;
  final String? desktopBgImage;
  final String source;

  OfferItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.badgeText,
    required this.highlightText,
    required this.couponCode,
    required this.ctaText,
    required this.ctaUrl,
    required this.ctaWebUrl,
    required this.ctaType,
    required this.displayMode,
    required this.targetAudience,
    required this.isActive,
    required this.sortOrder,
    this.mobileBgImage,
    this.desktopBgImage,
    required this.source,
  });

  factory OfferItem.fromJson(Map<String, dynamic> json) {
    return OfferItem(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String?,
      badgeText: json['badge_text'] as String?,
      highlightText: json['highlight_text'] as String?,
      couponCode: json['coupon_code'] as String?,
      ctaText: json['cta_text'] as String?,
      ctaUrl: json['cta_url'] as String? ?? '/products',
      ctaWebUrl: json['cta_web_url'] as String? ?? '',
      ctaType: json['cta_type'] as String? ?? 'internal',
      displayMode: json['display_mode'] as String? ?? 'normal',
      targetAudience: json['target_audience'] as String? ?? 'all_customers',
      isActive: json['is_active'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
      mobileBgImage: json['mobile_bg_image'] as String?,
      desktopBgImage: json['desktop_bg_image'] as String?,
      source: json['source'] as String? ?? 'general',
    );
  }
}

class OffersResponse {
  final OfferViewer viewer;
  final List<OfferItem> normalOffers;
  final List<OfferItem> popupOffers;
  final int normalOffersCount;
  final int popupOffersCount;
  final DateTime? fetchedAt;

  OffersResponse({
    required this.viewer,
    required this.normalOffers,
    required this.popupOffers,
    required this.normalOffersCount,
    required this.popupOffersCount,
    required this.fetchedAt,
  });

  factory OffersResponse.fromJson(Map<String, dynamic> json) {
    final data = Map<String, dynamic>.from(json['data'] as Map);

    return OffersResponse(
      viewer: OfferViewer.fromJson(
        Map<String, dynamic>.from(data['viewer'] as Map),
      ),
      normalOffers: (data['normal_offers'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                OfferItem.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      popupOffers: (data['popup_offers'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                OfferItem.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      normalOffersCount:
          (data['counts'] as Map<String, dynamic>?)?['normal_offers'] as int? ??
          0,
      popupOffersCount:
          (data['counts'] as Map<String, dynamic>?)?['popup_offers'] as int? ??
          0,
      fetchedAt: data['fetched_at'] != null
          ? DateTime.tryParse(data['fetched_at'] as String)
          : null,
    );
  }
}
