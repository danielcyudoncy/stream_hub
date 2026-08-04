import 'package:stream_hub/data/models/account_metadata.dart';

/// Optional capability for [MediaSource]s whose backend reports subscription
/// account metadata (creation/expiry dates, plan status, connection limit).
///
/// Controllers detect this interface via `is AccountMetadataProvider` so the
/// shared [MediaSource] contract stays untouched for sources without a panel.
abstract class AccountMetadataProvider {
  AccountMetadata? get accountMetadata;
}
