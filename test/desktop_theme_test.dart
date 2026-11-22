// Step 3: the desktop theme (dense, 32 px controls, radius 4, hover, pointer cursor).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/app/theme.dart';

void main() {
  testWidgets('buttons and fields are 32 px high, radius 4', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: Column(
            children: [
              FilledButton(
                key: const ValueKey('f'),
                onPressed: () {},
                child: const Text('Oplaai'),
              ),
              OutlinedButton(
                key: const ValueKey('o'),
                onPressed: () {},
                child: const Text('Kanselleer'),
              ),
              const SizedBox(width: 200, child: TextField(key: ValueKey('t'))),
            ],
          ),
        ),
      ),
    );
    for (final k in ['f', 'o', 't']) {
      expect(t.getSize(find.byKey(ValueKey(k))).height, 32, reason: k);
    }
    final th = buildTheme(Brightness.light);
    expect(th.visualDensity.vertical, 0);
    expect(th.visualDensity.horizontal, -2);
    expect(th.materialTapTargetSize, MaterialTapTargetSize.shrinkWrap);
    expect(
      (th.cardTheme.shape as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(4),
    );
    expect(
      (th.dialogTheme.shape as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(8),
    );
  });
}
