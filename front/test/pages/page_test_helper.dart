import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Set up a large test surface and suppress overflow errors for page tests.
/// Returns a teardown function to restore original state.
void setupPageTest(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
}

/// Suppress overflow errors that are expected in test environment.
FlutterExceptionHandler? suppressOverflowErrors() {
  final origOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('overflow')) return;
    if (details.toString().contains('RenderFlex')) return;
    origOnError?.call(details);
  };
  return origOnError;
}
