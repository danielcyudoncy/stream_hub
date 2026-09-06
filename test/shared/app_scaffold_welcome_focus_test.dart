import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/utils/responsive_helper.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

void main() {
  setUp(() {
    Get.reset();
  });

  group('AppScaffold TV welcome CTA autofocus', () {
    testWidgets(
        'TV-width layout autofocuses the "Add Media Source" CTA even when platform TV detection is false',
        (tester) async {
      // 1920px wide -> ResponsiveHelper.isTV(context) is true via width alone.
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final ctaNode = FocusNode(debugLabel: 'CTA');
      var layoutCheck = false;

      // Mirror the TvHomePage welcome CTA: layout-based autofocus.
      await tester.pumpWidget(
        GetMaterialApp(
          home: AppScaffold(
            title: 'Home',
            showAppBar: false,
            body: Builder(
              builder: (context) {
                layoutCheck = ResponsiveHelper.isTvLayout(context);
                return Center(
                  child: TvFocusable(
                    focusNode: ctaNode,
                    autofocus: layoutCheck,
                    onTap: () {},
                    child: const Text('Add Media Source'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The layout-based autofocus must win regardless of the fragile
      // PlatformHelper.isTVDevice flag (which is false in this test by default).
      expect(layoutCheck, isTrue, reason: 'wide layout should be considered a TV layout');
      expect(
        FocusManager.instance.primaryFocus,
        ctaNode,
        reason: 'Add Media Source must be focused on launch in the TV layout',
      );

      ctaNode.dispose();
    });
  });
}