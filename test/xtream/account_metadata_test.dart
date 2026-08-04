import 'package:flutter_test/flutter_test.dart';
import 'package:stream_hub/data/models/account_metadata.dart';

void main() {
  group('AccountMetadata', () {
    test('parses created_at and exp_date epoch seconds', () {
      final meta = AccountMetadata.fromUserInfo({
        'created_at': '1783507521',
        'exp_date': '1817721921',
        'status': 'Active',
        'is_trial': '0',
        'max_connections': '1',
      });

      expect(meta.createdAt, DateTime.fromMillisecondsSinceEpoch(1783507521000));
      expect(meta.expiresAt, DateTime.fromMillisecondsSinceEpoch(1817721921000));
      expect(meta.status, 'Active');
      expect(meta.isTrial, isFalse);
      expect(meta.maxConnections, 1);
    });

    test('treats exp_date 0 as never expiring', () {
      final meta = AccountMetadata.fromUserInfo({
        'created_at': 1783507521,
        'exp_date': '0',
      });

      expect(meta.createdAt, isNotNull);
      expect(meta.expiresAt, isNull);
    });

    test('tolerates missing fields', () {
      final meta = AccountMetadata.fromUserInfo({
        'username': 'demo',
        'auth': 1,
      });

      expect(meta.createdAt, isNull);
      expect(meta.expiresAt, isNull);
      expect(meta.status, isNull);
      expect(meta.isTrial, isNull);
      expect(meta.maxConnections, isNull);
    });

    test('parses integer and boolean variants', () {
      final meta = AccountMetadata.fromUserInfo({
        'created_at': 1000000000,
        'exp_date': 2000000000,
        'is_trial': true,
        'max_connections': 3,
      });

      expect(meta.isTrial, isTrue);
      expect(meta.maxConnections, 3);
    });
  });
}
