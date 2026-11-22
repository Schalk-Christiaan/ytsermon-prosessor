// @stelsel pixel_art
//   soort: module
//   wanneer: vorderingswyer, leë toestande, statusbalk en opstelskerm
//   groep: app | App-raam
//   skryf: —
//   doel: pixel-kuns uit karakter-roosters in Dart (geen beeldlêers): PixelSprite en PixelScene teken skerp vierkante op 'n heelgetal-skaal met 'n palet uit tema-rolle; een Ticker (≤8 rame/s) loop net as die toneel sigbaar en besig is, anders een stil raam
//   status: bou
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

/// Palette characters of the sprite grids; '.' is transparent. Each maps to a theme role, so the art follows light and dark.
const kPixelPalette = 'kwpstm';

Color _color(ColorScheme c, String ch) => switch (ch) {
  'k' => c.onSurface,
  'w' => c.surfaceContainerHighest,
  'p' => c.primary,
  's' => c.secondary,
  't' => c.tertiary,
  _ => c.outline, // 'm'
};

/// A small animated picture: [frames] of equal-length strings, one per row.
class Sprite {
  const Sprite(this.name, this.frames);
  final String name;
  final List<List<String>> frames;
  int get width => frames.first.first.length;
  int get height => frames.first.length;
}

/// A sprite placed at a grid position ([x], [y] in sprite pixels) in a scene.
class Placed {
  const Placed(this.sprite, [this.x = 0, this.y = 0]);
  final Sprite sprite;
  final int x, y;
}

/// Two-frame walking sheep (the Werk-skerm and status bar use it).
const sheep = Sprite('sheep', [
  [
    '...kkkkk....',
    '.kwwwwwwk.kk',
    'kwwwwwwwwkkk',
    'kwwwwwwwwkkk',
    '.kwwwwwwk.kk',
    '..k.k..k.k..',
    '..k.k..k.k..',
  ],
  [
    '...kkkkk....',
    '.kwwwwwwk.kk',
    'kwwwwwwwwkkk',
    'kwwwwwwwwkkk',
    '.kwwwwwwk.kk',
    '...k.k.k..k.',
    '...k.k.k..k.',
  ],
]);

/// Every sprite (the unit test checks each one).
const allSprites = [sheep];

/// Frame rate of the sprite animations.
const kPixelFps = 6;

/// One sprite, drawn at an integer [scale]; animates only while [animate] and the widget is visible (TickerMode) and motion is not reduced.
class PixelSprite extends StatelessWidget {
  const PixelSprite(
    this.sprite, {
    super.key,
    this.scale = 4,
    this.animate = true,
  });
  final Sprite sprite;
  final int scale;
  final bool animate;

  @override
  Widget build(BuildContext context) => PixelScene(
    width: sprite.width,
    height: sprite.height,
    scale: scale,
    animate: animate,
    layers: [Placed(sprite)],
  );
}

/// Several sprites on one [width]×[height] pixel grid, optionally with a ground line along the bottom row.
class PixelScene extends StatefulWidget {
  const PixelScene({
    super.key,
    required this.width,
    required this.height,
    required this.layers,
    this.scale = 4,
    this.animate = true,
    this.ground = false,
  });
  final int width, height, scale;
  final List<Placed> layers;
  final bool animate, ground;

  @override
  State<PixelScene> createState() => _PixelSceneState();
}

class _PixelSceneState extends State<PixelScene>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((d) {
    final f = d.inMilliseconds * kPixelFps ~/ 1000;
    if (f != _frame) setState(() => _frame = f);
  });
  int _frame = 0;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // The ticker follows TickerMode by itself (muted when hidden); start/stop here, never in build.
  void _sync() {
    final run = widget.animate && !MediaQuery.disableAnimationsOf(context);
    if (run != _ticker.isActive) {
      run ? _ticker.start() : _ticker.stop();
      if (!run) _frame = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PixelScene old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(
        widget.width * widget.scale.toDouble(),
        widget.height * widget.scale.toDouble(),
      ),
      painter: _Painter(
        widget.layers,
        _frame,
        widget.scale,
        widget.width,
        widget.height,
        widget.ground,
        Theme.of(context).colorScheme,
      ),
    );
  }
}

class _Painter extends CustomPainter {
  _Painter(
    this.layers,
    this.frame,
    this.scale,
    this.w,
    this.h,
    this.ground,
    this.colors,
  );
  final List<Placed> layers;
  final int frame, scale, w, h;
  final bool ground;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    void px(int x, int y, Color c) => canvas.drawRect(
      Rect.fromLTWH(
        (x * scale).toDouble(),
        (y * scale).toDouble(),
        scale.toDouble(),
        scale.toDouble(),
      ),
      paint..color = c,
    );
    if (ground) {
      for (var x = 0; x < w; x++) {
        px(x, h - 1, colors.outlineVariant);
      }
    }
    for (final l in layers) {
      final rows = l.sprite.frames[frame % l.sprite.frames.length];
      for (var y = 0; y < rows.length; y++) {
        for (var x = 0; x < rows[y].length; x++) {
          final ch = rows[y][x];
          if (ch != '.') px(l.x + x, l.y + y, _color(colors, ch));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_Painter o) =>
      o.frame != frame || o.colors != colors || o.layers != layers;
}
