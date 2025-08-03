import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';

class PageTurnerAudioHandler extends BaseAudioHandler {
  final ValueNotifier<int> currentPageIndex = ValueNotifier<int>(0);
  int _pageCount = 0;

  void setPageCount(int count) {
    _pageCount = count;
  }

  void setPageIndex(int index) {
    currentPageIndex.value = index;
  }

  @override
  Future<void> skipToNext() async {
    if (currentPageIndex.value < _pageCount - 1) {
      currentPageIndex.value++;
    }
    print("Media controller 'Next' button pressed! New index: ${currentPageIndex.value}");
  }

  @override
  Future<void> skipToPrevious() async {
    if (currentPageIndex.value > 0) {
      currentPageIndex.value--;
    }
    print("Media controller 'Previous' button pressed! New index: ${currentPageIndex.value}");
  }

  // These are required but we don't need to implement them for page turning.
  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {
    await super.stop();
    currentPageIndex.dispose();
  }
}
