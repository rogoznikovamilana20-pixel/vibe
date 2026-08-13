import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibe_app/core/widgets/vibe_icon_font.dart';

/// Превью всего набора VibeIcons — генерируется `flutter test --update-goldens`.
void main() {
  testWidgets('VibeIcons: превью набора', (tester) async {
    await tester.binding.setSurfaceSize(const Size(940, 260));
    tester.view.devicePixelRatio = 1.0;

    final entries = <(String, IconData)>[
      ('send', VibeIcons.send),
      ('back', VibeIcons.back),
      ('forward', VibeIcons.forward),
      ('check', VibeIcons.check),
      ('checkAll', VibeIcons.checkAll),
      ('edit', VibeIcons.edit),
      ('trash', VibeIcons.trash),
      ('pin', VibeIcons.pin),
      ('star', VibeIcons.star),
      ('heart', VibeIcons.heart),
      ('bolt', Icons.bolt),
      ('home', VibeIcons.home),
      ('phone', VibeIcons.phone),
      ('video', VibeIcons.video),
      ('camera', VibeIcons.camera),
      ('moreVertical', VibeIcons.moreVertical),
      ('moreHorizontal', VibeIcons.moreHorizontal),
      ('plus', VibeIcons.plus),
      ('close', VibeIcons.close),
      ('search', VibeIcons.search),
      ('mic', VibeIcons.mic),
      ('lock', VibeIcons.lock),
      ('folder', VibeIcons.folder),
      ('archive', VibeIcons.archive),
      ('user', VibeIcons.user),
      ('group', VibeIcons.group),
      ('copy', VibeIcons.copy),
      ('reply', VibeIcons.reply),
      ('download', VibeIcons.download),
      ('volume', VibeIcons.volume),
      ('play', VibeIcons.play),
      ('pause', VibeIcons.pause),
      ('eye', VibeIcons.eye),
      ('info', VibeIcons.info),
      ('file', VibeIcons.file),
      ('clock', VibeIcons.clock),
      ('bubble', VibeIcons.bubble),
      ('smile', VibeIcons.smile),
      ('settings', VibeIcons.settings),
      ('attach', VibeIcons.attach),
    ];

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0D0A1E),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (var r = 0; r < (entries.length + 7) ~/ 8; r++)
                  Row(
                    children: [
                      for (var c = 0; c < 8; c++)
                        if (r * 8 + c < entries.length)
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(entries[r * 8 + c].$2,
                                    size: 24, color: Colors.white),
                                Text(
                                  entries[r * 8 + c].$1,
                                  style: const TextStyle(
                                      fontSize: 8, color: Colors.white54),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    ));

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/vibe_icons_preview.png'),
    );
  });
}