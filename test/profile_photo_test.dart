import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pikzen/features/profile/screens/edit_profile_screen.dart';
import 'package:pikzen/shared/widgets/profile_photo.dart';

// Smallest valid JPEG header/footer is enough for the encoder's type check.
final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0xFF, 0xD9]);

void main() {
  test('photos encode as data URIs and reject unknown formats', () {
    final encoded = ProfilePhotoData.encode(_jpeg)!;
    expect(encoded, startsWith('data:image/jpeg;base64,'));
    expect(ProfilePhotoData.decode(encoded), _jpeg);
    expect(ProfilePhotoData.encode(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });

  testWidgets('camera button picks, saves and removes a profile photo', (
    tester,
  ) async {
    final writes = <Map<String, Object?>>[];
    final sources = <ImageSource>[];
    await tester.pumpWidget(
      MaterialApp(
        home: EditProfileScreen(
          identityForTesting: (
            uid: 'customer-1',
            email: 'c@example.com',
            displayName: 'Demo Customer',
            photoUrl: null,
            emailVerified: true,
          ),
          profileLoader: (_) async => {
            'role': 'customer',
            'fullName': 'Demo Customer',
            'phone': '',
          },
          profileWriter: (_, changes) async => writes.add(changes),
          ordersForCustomer: (_) => Stream.value(const []),
          photoPicker: (source) async {
            sources.add(source);
            return _jpeg;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Change profile photo'));
    await tester.pumpAndSettle();
    expect(find.text('Take Photo'), findsOneWidget);
    expect(find.text('Remove Photo'), findsNothing);
    await tester.tap(find.text('Choose from Gallery'));
    await tester.pumpAndSettle();

    expect(sources, [ImageSource.gallery]);
    expect(writes.single['photoUrl'], startsWith('data:image/jpeg;base64,'));
    expect(find.text('Profile photo updated.'), findsOneWidget);
    expect(find.text('Change Photo'), findsOneWidget);

    await tester.tap(find.byTooltip('Change profile photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove Photo'));
    await tester.pumpAndSettle();
    expect(writes.last, {'photoUrl': ''});
    expect(find.text('Add Photo'), findsOneWidget);
  });
}
