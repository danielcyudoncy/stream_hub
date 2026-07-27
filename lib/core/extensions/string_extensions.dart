import '../utils/validators.dart';

extension StringExtensions on String {
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  bool get isValidEmail => Validators.isValidEmail(this);
  bool get isValidUrl => Validators.isValidUrl(this);
  bool get isValidMacAddress => Validators.isValidMacAddress(this);

  int toInt({int defaultValue = 0}) {
    return int.tryParse(this) ?? defaultValue;
  }

  double toDouble({double defaultValue = 0.0}) {
    return double.tryParse(this) ?? defaultValue;
  }

  String get cleanUrl {
    var url = trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    return url;
  }
}
