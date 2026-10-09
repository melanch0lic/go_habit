import 'package:flutter/material.dart';
import 'package:go_habit/core/extension/theme_extension.dart';

/// A preset avatar: an emoji on a colored circle. Stored as [key] in `profile.avatar`.
@immutable
class AvatarPreset {
  final String key;
  final String emoji;
  final Color color;

  const AvatarPreset(this.key, this.emoji, this.color);

  static const all = [
    AvatarPreset('fox', '🦊', Color(0xFFFF8A65)),
    AvatarPreset('panda', '🐼', Color(0xFF90A4AE)),
    AvatarPreset('tiger', '🐯', Color(0xFFFFB74D)),
    AvatarPreset('frog', '🐸', Color(0xFF81C784)),
    AvatarPreset('owl', '🦉', Color(0xFFA1887F)),
    AvatarPreset('octopus', '🐙', Color(0xFFBA68C8)),
    AvatarPreset('unicorn', '🦄', Color(0xFFF06292)),
    AvatarPreset('turtle', '🐢', Color(0xFF4DB6AC)),
    AvatarPreset('bee', '🐝', Color(0xFFFFD54F)),
    AvatarPreset('whale', '🐳', Color(0xFF4FC3F7)),
    AvatarPreset('cat', '🐱', Color(0xFFFFCC80)),
    AvatarPreset('dog', '🐶', Color(0xFFBCAAA4)),
  ];

  /// Unknown keys (e.g. from a newer app version) fall back to the generated avatar.
  static AvatarPreset? byKey(String? key) => all.where((preset) => preset.key == key).firstOrNull;
}

/// A user's avatar: their preset, or by default a pixel pattern generated from the
/// nickname (in the style of the habit grid), so every user is recognizable without
/// uploading an image.
class UserAvatar extends StatelessWidget {
  final String? nickname;
  final String? avatar;
  final double size;

  const UserAvatar({required this.nickname, required this.avatar, this.size = 40, super.key});

  @override
  Widget build(BuildContext context) {
    final preset = AvatarPreset.byKey(avatar);
    final content = preset != null
        ? Container(
            alignment: Alignment.center,
            color: preset.color,
            child: Text(preset.emoji, style: TextStyle(fontSize: size * 0.55)),
          )
        : CustomPaint(
            painter: _PixelAvatarPainter(
              seed: (nickname ?? '?').toLowerCase(),
              color: context.theme.commonColors.green100,
            ),
          );
    return ExcludeSemantics(
      child: ClipOval(child: SizedBox.square(dimension: size, child: content)),
    );
  }
}

/// A symmetric 5×5 pattern derived from [seed].
class _PixelAvatarPainter extends CustomPainter {
  final String seed;
  final Color color;

  _PixelAvatarPainter({required this.seed, required this.color});

  static const _cells = 5;
  static const _background = Color.fromARGB(255, 33, 43, 39);

  /// FNV-1a: stable across runs and platforms (String.hashCode is not).
  static int _hash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _background);
    final hash = _hash(seed);
    // The inner area leaves a margin so the circle does not cut the pattern.
    final cell = size.width / (_cells + 2);
    final paint = Paint()..color = color;
    for (var row = 0; row < _cells; row++) {
      for (var column = 0; column < 3; column++) {
        if ((hash >> (row * 3 + column)) & 1 == 0) continue;
        for (final x in {column, _cells - 1 - column}) {
          canvas.drawRect(Rect.fromLTWH((x + 1) * cell, (row + 1) * cell, cell, cell), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PixelAvatarPainter oldDelegate) => oldDelegate.seed != seed || oldDelegate.color != color;
}
