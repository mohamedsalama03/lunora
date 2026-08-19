class LogoModel {
  final bool hasLogo;
  final String? logoUrl;
  final String? updatedAt;

  const LogoModel({required this.hasLogo, this.logoUrl, this.updatedAt});

  factory LogoModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return LogoModel(
      hasLogo: data['has_logo'] as bool,
      logoUrl: data['logo_url'] as String?,
      updatedAt: data['updated_at'] as String?,
    );
  }
}
