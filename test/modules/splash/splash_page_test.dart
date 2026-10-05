import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/constants/app_assets.dart';
import 'package:stream_hub/modules/splash/splash_controller.dart';
import 'package:stream_hub/modules/splash/splash_page.dart';

class MockSplashController extends GetxController implements SplashController {
  @override
  final RxString statusMessage = 'Loading...'.obs;
}

void main() {
  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('SplashPage renders AppAssets.logo and StreamHub Pro headline', (
    WidgetTester tester,
  ) async {
    Get.put<SplashController>(MockSplashController());

    await tester.pumpWidget(
      const GetMaterialApp(
        home: SplashPage(),
      ),
    );

    expect(find.text('StreamHub Pro'), findsOneWidget);
    expect(find.text('Premium IPTV Client'), findsOneWidget);

    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);

    final imageWidget = tester.widget<Image>(imageFinder);
    expect(imageWidget.image, isA<AssetImage>());
    expect((imageWidget.image as AssetImage).assetName, equals(AppAssets.logo));
  });
}
