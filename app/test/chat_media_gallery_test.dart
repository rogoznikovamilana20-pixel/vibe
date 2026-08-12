import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibe_app/chat/chat_controller.dart';
import 'package:vibe_app/chat/chat_media_gallery_screen.dart';
import 'package:vibe_app/core/theme/vibe_theme.dart';
import 'package:vibe_app/core/widgets/vibe_avatar.dart';
import 'package:vibe_app/data/backend.dart';
import 'package:vibe_app/data/settings_service.dart';

import 'fake_vibe_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVibeBackend fake;
  late ChatController controller;

  VibeMessage media({
    required String id,
    required String kind, // 'photo' | 'video'
  }) {
    return VibeMessage(
      id: id,
      chatId: 'c1',
      senderId: 'peer',
      senderName: 'Пир',
      senderAvatar: null,
      text: null,
      voicePath: null,
      photoPath: kind == 'photo' ? 'media/c1/photo.jpg' : null,
      videoPath: kind == 'video' ? 'media/c1/video.mp4' : null,
      created: DateTime(2026, 8, 12, 10, 0),
      incoming: true,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    VibeNetImage.resolveUrl = (_) async => null;
    fake = FakeVibeBackend();
    controller = ChatController(
      chatId: 'c1',
      chatTitle: 'Чат',
      onError: (_) {},
      backend: fake,
    );
  });

  tearDown(() {
    controller.dispose();
    fake.close();
  });

  Future<void> pumpGallery(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: VibeTheme.light(),
        home: ChatMediaGalleryScreen(
          controller: controller,
          chatTitle: 'Чат',
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('галерея: сетка из фото и видео, пустое состояние', (tester) async {
    await pumpGallery(tester);
    expect(find.text('Пока нет медиа'), findsOneWidget);

    fake.messagesByChat['c1'] = [
      media(id: 'm1', kind: 'photo'),
      media(id: 'm2', kind: 'photo'),
      media(id: 'm3', kind: 'video'),
    ];
    await controller.load();

    await pumpGallery(tester);
    expect(find.text('Медиа · 3'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('галерея: тап по плитке открывает просмотрщик', (tester) async {
    fake.messagesByChat['c1'] = [
      media(id: 'm1', kind: 'photo'),
      media(id: 'm2', kind: 'video'),
    ];
    await controller.load();

    await pumpGallery(tester);
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MediaViewerScreen), findsOneWidget);
  });
}
