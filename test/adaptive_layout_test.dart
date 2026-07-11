import 'package:bible_app/widgets/adaptive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdaptiveLayoutInfo navigation behavior', () {
    test('treats widths below 768 as phone in portrait and landscape', () {
      final portraitPhone = _layoutFor(const Size(390, 844));
      final landscapePhone = _layoutFor(const Size(740, 390));

      expect(portraitPhone.isPhone, isTrue);
      expect(portraitPhone.useSideNavigation, isFalse);
      expect(landscapePhone.isPhone, isTrue);
      expect(landscapePhone.useSideNavigation, isFalse);
    });

    test('uses side navigation at 768 logical pixels and wider', () {
      final tablet = _layoutFor(const Size(768, 1024));
      final desktop = _layoutFor(const Size(1200, 800));

      expect(tablet.isLargeScreen, isTrue);
      expect(tablet.useSideNavigation, isTrue);
      expect(desktop.isLargeScreen, isTrue);
      expect(desktop.useSideNavigation, isTrue);
    });
  });
}

AdaptiveLayoutInfo _layoutFor(Size size) {
  return AdaptiveLayoutInfo(
    constraints: BoxConstraints.tight(size),
    orientation: size.width >= size.height
        ? Orientation.landscape
        : Orientation.portrait,
  );
}
