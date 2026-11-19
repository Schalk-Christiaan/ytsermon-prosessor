import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/models.dart';

SermonPlan plan(List<Span> cuts) => SermonPlan(
  sermonStart: 100,
  sermonEnd: 1000,
  title: 't',
  description: '',
  shorts: [],
  cuts: cuts,
);

void main() {
  test('parts: the sermon minus the cuts, sorted and clipped', () {
    final p = plan([Span(600, 700), Span(50, 150), Span(900, 1200)]);
    expect(
      [for (final s in p.parts()) (s.start, s.end)],
      [(150, 600), (700, 900)],
    );
  });

  test('parts without cuts is the whole sermon; cuts survive JSON', () {
    expect([for (final s in plan([]).parts()) (s.start, s.end)], [(100, 1000)]);
    final j = plan([Span(200, 300)]).toJson();
    expect(SermonPlan.fromJson(j).cuts.single.end, 300);
    expect(SermonPlan.fromJson(j..remove('cuts')).cuts, isEmpty);
  });
}
