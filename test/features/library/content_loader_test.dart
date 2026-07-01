import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bulwark/features/library/data/content_loader.dart';

void main() {
  test('contentLibraryProvider loads the shipped assets end-to-end via rootBundle', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final library = await container.read(contentLibraryProvider.future);

    expect(library.all.length, 89);
    expect(library.presetById('newParent'), isNotNull);
  });
}
