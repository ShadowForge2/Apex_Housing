import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/theme_colors.dart';
import '../models/models.dart';

class PropertyCard extends StatefulWidget {
  final Property property;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool isFavorited;
  final bool isCompact;
  final bool isGrid;
  final double? imageHeight;

  const PropertyCard({
    super.key,
    required this.property,
    this.onTap,
    this.onFavorite,
    this.isFavorited = false,
    this.isCompact = false,
    this.isGrid = false,
    this.imageHeight,
  });

  @override
  State<PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<PropertyCard> {
  late bool _favorited;

  @override
  void initState() {
    super.initState();
    _favorited = widget.isFavorited;
  }

  @override
  void didUpdateWidget(covariant PropertyCard old) {
    super.didUpdateWidget(old);
    if (old.isFavorited != widget.isFavorited) _favorited = widget.isFavorited;
  }

  void _toggleFavorite() {
    setState(() => _favorited = !_favorited);
    widget.onFavorite?.call();
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final p = widget.property;
    if (widget.isGrid) return _buildMasonry(tc, p);
    if (widget.isCompact) return _buildCompact(tc, p);
    return _buildFeatured(tc, p);
  }

  Widget _buildFeatured(ThemeColors tc, Property p) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: tc.shadow, blurRadius: 15)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  child: Image.network(
                    p.images.first,
                    height: 180,
                    width: 260,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: tc.surfaceVariant,
                      child: Center(child: Icon(Icons.home, size: 48, color: tc.hint)),
                    ),
                  ),
                ),
                Positioned(top: 12, right: 12, child: _favoriteButton(tc)),
                Positioned(bottom: 12, left: 12, child: _badge(p.planType, tc)),
              ],
            ),
            _buildInfoSection(tc, p),
          ],
        ),
      ),
    );
  }

  Widget _buildMasonry(ThemeColors tc, Property p) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: tc.shadow, blurRadius: 15)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: widget.imageHeight ?? 200,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                      child: Image.network(
                        p.images.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: tc.surfaceVariant,
                          child: Center(child: Icon(Icons.home, size: 40, color: tc.hint)),
                        ),
                      ),
                    ),
                  ),
                  Positioned(top: 12, right: 12, child: _favoriteButton(tc)),
                  Positioned(bottom: 12, left: 12, child: _badge(p.planType, tc)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text('${p.city}, ${p.state}', style: TextStyle(color: tc.subtitle, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Text(p.priceFormatted, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary))),
                    const Icon(Icons.star, size: 16, color: AppColors.rating),
                    const SizedBox(width: 3),
                    Text(p.rating.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(ThemeColors tc, Property p) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: tc.shadow, blurRadius: 15)],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                p.images.first,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 80,
                  height: 80,
                  color: tc.surfaceVariant,
                  child: Icon(Icons.home, color: tc.hint),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 13, color: tc.hint),
                    const SizedBox(width: 3),
                    Text(p.city, style: TextStyle(fontSize: 12, color: tc.subtitle)),
                    if (p.distanceKm != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${p.distanceKm!.toStringAsFixed(1)} km',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 6),
                  Text(p.priceFormatted, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: tc.hint),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(ThemeColors tc, Property p) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.location_on_outlined, size: 14, color: tc.subtitle),
            const SizedBox(width: 4),
            Text('${p.city}, ${p.state}', style: TextStyle(color: tc.subtitle, fontSize: 13)),
            if (p.distanceKm != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${p.distanceKm!.toStringAsFixed(1)} km',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          Row(children: [
            if (p.rating > 0) ...[
              const Icon(Icons.star_rounded, size: 16, color: AppColors.rating),
              const SizedBox(width: 3),
              Text(p.rating.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
            ],
            Icon(Icons.king_bed_outlined, size: 14, color: tc.hint),
            const SizedBox(width: 3),
            Text('${p.bedrooms} Beds', style: TextStyle(fontSize: 12, color: tc.subtitle)),
            const SizedBox(width: 10),
            Icon(Icons.bathtub_outlined, size: 14, color: tc.hint),
            const SizedBox(width: 3),
            Text('${p.bathrooms} Baths', style: TextStyle(fontSize: 12, color: tc.subtitle)),
          ]),
        ],
      ),
    );
  }

  Widget _favoriteButton(ThemeColors tc) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleFavorite,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _favorited ? AppColors.error.withValues(alpha: 0.12) : tc.card,
          shape: BoxShape.circle,
          boxShadow: _favorited
              ? [BoxShadow(blurRadius: 8, color: AppColors.error.withValues(alpha: 0.25))]
              : [BoxShadow(blurRadius: 6, color: tc.shadow)],
        ),
        child: Icon(
          _favorited ? Icons.favorite_rounded : Icons.favorite_border,
          size: 18,
          color: _favorited ? AppColors.error : tc.hint,
        ),
      ),
    );
  }

  Widget _badge(String label, ThemeColors tc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tc.text)),
    );
  }
}
