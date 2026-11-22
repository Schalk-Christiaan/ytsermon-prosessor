// @stelsel pixel_scenes
//   soort: module
//   wanneer: Werk-skerm, statusbalk, opstelskerm en leë toestande
//   groep: app | App-raam
//   skryf: —
//   doel: die tonele uit Bybelverhale as pixel-kuns, een per JobPhase en toestand (Abraham se sterre, Noag se duif, die wyse manne se karavaan, Nehemia se muur, Dawid se klippe en harp, Jakob se leer, skape in die ry, reënboog, Jona, die saaier, herder); geen beeld van God of Christus; mense klein en sonder gesigte
//   status: bou
import 'package:flutter/material.dart';

import '../core/jobs.dart';
import 'pixel_art.dart';

const _person = Sprite('person', [
  ['.k.', 'kkk', '.p.', 'ppp', 'ppp', '.p.', 'k.k'],
]);
const _star = Sprite('star', [
  ['.t.', 'ttt', '.t.'],
  ['...', '.t.', '...'],
]);
const _dove = Sprite('dove', [
  ['...k....', '.kkkkkss', 'kkkkkk..', '..kk....'],
  ['........', 'kkkkkkss', '.kkkkk..', '..kk....'],
]);
const _camel = Sprite('camel', [
  [
    '......kk.',
    '.....kk..',
    '..mm.k...',
    '.mmmmmm..',
    '.mmmmmm..',
    '.k.k.k.k.',
    '.k.k.k.k.',
  ],
  [
    '......kk.',
    '.....kk..',
    '..mm.k...',
    '.mmmmmm..',
    '.mmmmmm..',
    'k.k.k.k..',
    'k.k.k.k..',
  ],
]);
const _brick = Sprite('brick', [
  ['ppp', 'ppp'],
]);
const _stone = Sprite('stone', [
  ['tt', 'tt'],
]);
const _harp = Sprite('harp', [
  ['.kkk.', 'k...k', 'k.k.k', 'k.k.k', 'k.k.k', 'kkkkk'],
]);
const _note = Sprite('note', [
  ['.pp', '.p.', 'pp.', 'pp.'],
  ['...', '.pp', '.p.', 'pp.'],
]);
const _ladder = Sprite('ladder', [
  [
    'k...k',
    'kkkkk',
    'k...k',
    'k...k',
    'kkkkk',
    'k...k',
    'k...k',
    'kkkkk',
    'k...k',
    'k...k',
    'kkkkk',
    'k...k',
  ],
]);
const _rainbow = Sprite('rainbow', [
  [
    '....pppppppp....',
    '..pp........pp..',
    '.p...ssssss...p.',
    '.p..s......s..p.',
    'p..s..tttt..s..p',
    'p.s..t....t..s.p',
  ],
]);
const _jonah = Sprite('jonah', [
  ['.........', 'kppppppk.'],
]);
const _staff = Sprite('staff', [
  ['m', 'm', 'm', 'm', 'm', 'm', 'm'],
]);
const _grain = Sprite('grain', [
  ['t.t.t'],
]);

/// The scene sprites (the unit test checks each one).
const sceneSprites = [
  _person,
  _star,
  _dove,
  _camel,
  _brick,
  _stone,
  _harp,
  _note,
  _ladder,
  _rainbow,
  _jonah,
  _staff,
  _grain,
];

const _w = 40, _h = 14, _scale = 3;
const _gy = _h - 1; // ground row

Widget _scene(
  List<Placed> l, {
  bool animate = true,
  bool ground = true,
  int width = _w,
}) => Semantics(
  excludeSemantics: true,
  child: PixelScene(
    width: width,
    height: _h,
    scale: _scale,
    animate: animate,
    ground: ground,
    layers: l,
  ),
);

Placed _stand(Sprite s, int x) => Placed(s, x, _gy - s.height);

/// The picture for a running [phase]; [progress] (0..1, null = unknown) moves the dove, the wall, the ladder; [shorts] picks Dawid's stones over Nehemia's wall for a cut.
Widget phaseScene(
  JobPhase phase, {
  double? progress,
  bool shorts = false,
  bool animate = true,
}) {
  final p = progress ?? 0;
  return _scene(animate: animate, switch (phase) {
    // Abraham counts the stars
    JobPhase.meta => [
      _stand(_person, 6),
      for (var i = 0; i < 4; i++) Placed(_star, 14 + i * 6, 1 + (i * 3) % 5),
    ],
    // Noah's dove brings the olive branch back to the ark
    JobPhase.download => [
      Placed(_dove, (p * (_w - 20)).round() + 2, 3),
      Placed(_brick, _w - 12, _gy - 2),
      Placed(_brick, _w - 9, _gy - 2),
      Placed(_brick, _w - 6, _gy - 2),
      Placed(_brick, _w - 9, _gy - 4),
    ],
    // the wise men follow the star
    JobPhase.plan => [
      Placed(_star, 28, 1),
      _stand(_camel, 4),
      _stand(_camel, 15),
    ],
    // Nehemiah builds the wall; or David picks five smooth stones
    JobPhase.cut when shorts => [
      _stand(_person, 4),
      for (var i = 0; i < 5; i++)
        if (i < (p * 5).floor()) Placed(_stone, 14 + i * 4, _gy - 2),
    ],
    JobPhase.cut => [
      _stand(_person, 4),
      for (var i = 0; i < (p * 24).floor(); i++)
        Placed(_brick, 10 + (i % 8) * 3, _gy - 2 * (i ~/ 8 + 1)),
    ],
    // David plays the harp for Saul
    JobPhase.audio => [
      _stand(_person, 6),
      _stand(_harp, 11),
      Placed(_note, 18, 3),
      Placed(_note, 24, 5),
    ],
    // Jacob's ladder: the figure climbs
    JobPhase.upload => [
      _stand(_ladder, 20),
      Placed(_person, 25, (_gy - 7 - (p * 5).round())),
    ],
  });
}

/// Sheep behind the shepherd, one per waiting item (at most 6).
Widget queueScene(int waiting) {
  final n = waiting.clamp(1, 6);
  return _scene(width: 14 + n * 13, animate: false, [
    _stand(_person, 4),
    Placed(_staff, 8, _gy - 7),
    for (var i = 0; i < n; i++) _stand(sheep, 14 + i * 13),
  ]);
}

/// Noah's rainbow over the finished work: once, then still.
Widget doneScene() =>
    _scene([Placed(_rainbow, 12, 2)], animate: false, ground: false);

/// Jonah on the beach: a second chance; still, never for lost work in a jokey way.
Widget errorScene() => _scene([Placed(_jonah, 12, _gy - 2)], animate: false);

/// The sower: nothing here yet, begin.
Widget sowerScene() => _scene([
  _stand(_person, 8),
  Placed(_grain, 13, _gy - 3),
  Placed(_grain, 20, _gy - 2),
], animate: false);

/// The shepherd at the fold, the sheep at rest: nothing to do.
Widget restScene() => _scene([
  _stand(_person, 4),
  Placed(_staff, 8, _gy - 7),
  _stand(sheep, 14),
  _stand(sheep, 19),
], animate: false);
