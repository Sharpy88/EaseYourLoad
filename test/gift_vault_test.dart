import 'package:flutter_test/flutter_test.dart';
import 'package:mental_load_app/main.dart';

void main() {
  test('gift profiles round-trip with pin and ideas', () {
    final profile = GiftProfile(
      name: 'User One',
      pin: '1234',
      ideas: [Idea('Book', 'Mystery novel')],
    );

    final json = giftProfileToJson(profile);
    final roundTrip = giftProfileFromJson(json);

    expect(roundTrip.name, 'User One');
    expect(roundTrip.pin, '1234');
    expect(roundTrip.ideas.single.title, 'Book');
    expect(roundTrip.ideas.single.detail, 'Mystery novel');
  });
}
