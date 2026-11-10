import 'dart:typed_data';

import 'package:autorent/core/services/supabase_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('storage is off by default: no network call, nothing thrown', () async {
    expect(SupabaseStorage.enabled, isFalse);
    expect(await SupabaseStorage.uploadBytes('a.jpg', Uint8List(3)), isFalse);
    await SupabaseStorage.delete('a.jpg');
  });

  test('public URL points to the vehicle-photos bucket and is encoded', () {
    expect(SupabaseStorage.publicUrl('demo_audi q3.jpg'),
        'https://yrgxysnybsllsipayoad.supabase.co/storage/v1/object/public/vehicle-photos/demo_audi%20q3.jpg');
  });
}
