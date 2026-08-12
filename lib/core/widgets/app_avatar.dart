import 'package:flutter/material.dart';

class AppAvatar extends StatelessWidget {
  static const String collectionAsset =
      'assets/images/avatar_collection_clean.png';
  static const int avatarCount = 16;

  final int? avatarIndex;
  final String? photoUrl;
  final double size;
  final Color borderColor;
  final double borderWidth;
  final Color backgroundColor;

  const AppAvatar({
    super.key,
    this.avatarIndex,
    this.photoUrl,
    this.size = 72,
    this.borderColor = const Color(0xFF18B8AD),
    this.borderWidth = 1.5,
    this.backgroundColor = const Color(0xFFE5F8F5),
  });

  bool get _hasCollectionAvatar =>
      avatarIndex != null && avatarIndex! >= 0 && avatarIndex! < avatarCount;

  @override
  Widget build(BuildContext context) {
    final String resolvedPhotoUrl = (photoUrl ?? '').trim();

    return Semantics(
      image: true,
      label: _hasCollectionAvatar
          ? 'AGo avatar ${avatarIndex! + 1}'
          : 'Profile picture',
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(borderWidth),
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: ClipOval(
          child: _hasCollectionAvatar
              ? AvatarCollectionCrop(
                  index: avatarIndex!,
                  size: size - (borderWidth * 2),
                )
              : resolvedPhotoUrl.isNotEmpty
              ? Image.network(
                  resolvedPhotoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return AvatarCollectionCrop(
                      index: 0,
                      size: size - (borderWidth * 2),
                    );
                  },
                )
              : AvatarCollectionCrop(index: 0, size: size - (borderWidth * 2)),
        ),
      ),
    );
  }
}

class AvatarCollectionCrop extends StatelessWidget {
  final int index;
  final double size;

  const AvatarCollectionCrop({
    super.key,
    required this.index,
    required this.size,
  }) : assert(index >= 0 && index < AppAvatar.avatarCount);

  @override
  Widget build(BuildContext context) {
    final int row = index ~/ 4;
    final int column = index % 4;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: -column * size,
            top: -row * size,
            width: size * 4,
            height: size * 4,
            child: Image.asset(
              AppAvatar.collectionAsset,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            ),
          ),
        ],
      ),
    );
  }
}
