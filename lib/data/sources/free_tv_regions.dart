/// Resolves ISO-3166 alpha-2 country codes to a coarse continent/region.
///
/// Used to enrich Free TV channels with a `region` label (Africa, Americas,
/// Asia, Europe, Oceania, Middle East) so the UI can offer region filters in
/// addition to country and category filters.
library;

abstract final class FreeTvRegions {
  static const String africa = 'Africa';
  static const String americas = 'Americas';
  static const String asia = 'Asia';
  static const String europe = 'Europe';
  static const String oceania = 'Oceania';
  static const String middleEast = 'Middle East';

  static const Set<String> _africa = {
    'DZ', 'AO', 'BJ', 'BW', 'BF', 'BI', 'CM', 'CV', 'CF', 'TD',
    'KM', 'CD', 'CG', 'CI', 'DJ', 'EG', 'GQ', 'ER', 'SZ', 'ET',
    'GA', 'GM', 'GH', 'GN', 'GW', 'KE', 'LS', 'LR', 'LY', 'MG',
    'MW', 'ML', 'MR', 'MU', 'YT', 'MA', 'MZ', 'NA', 'NE', 'NG',
    'RE', 'RW', 'SH', 'ST', 'SN', 'SC', 'SL', 'SO', 'ZA', 'SS',
    'SD', 'TZ', 'TG', 'TN', 'UG', 'EH', 'ZM', 'ZW',
  };

  static const Set<String> _americas = {
    'AI', 'AG', 'AR', 'AW', 'BS', 'BB', 'BZ', 'BM', 'BO', 'BR',
    'VG', 'CA', 'KY', 'CL', 'CO', 'CR', 'CU', 'CW', 'DM', 'DO',
    'EC', 'SV', 'FK', 'GF', 'GL', 'GD', 'GP', 'GT', 'GY', 'HT',
    'HN', 'JM', 'MQ', 'MX', 'MS', 'NI', 'PA', 'PY', 'PE', 'PR',
    'BL', 'KN', 'LC', 'MF', 'PM', 'VC', 'SR', 'TT', 'TC', 'US',
    'UY', 'VI', 'VE',
  };

  static const Set<String> _asia = {
    'AF', 'AM', 'AZ', 'BH', 'BD', 'BT', 'BN', 'KH', 'CN', 'CY',
    'GE', 'HK', 'IN', 'ID', 'IR', 'IQ', 'IL', 'JP', 'JO', 'KZ',
    'KP', 'KR', 'KW', 'KG', 'LA', 'LB', 'MO', 'MY', 'MV', 'MN',
    'MM', 'NP', 'OM', 'PK', 'PS', 'PH', 'QA', 'SA', 'SG', 'LK',
    'SY', 'TW', 'TJ', 'TH', 'TL', 'TR', 'TM', 'AE', 'UZ', 'VN',
    'YE',
  };

  static const Set<String> _oceania = {
    'AS', 'AU', 'CK', 'FJ', 'PF', 'GU', 'KI', 'MH', 'FM', 'NR',
    'NC', 'NZ', 'NU', 'NF', 'MP', 'PW', 'PG', 'PN', 'WS', 'SB',
    'TK', 'TO', 'TV', 'VU', 'WF',
  };

  /// Coarse region for a given country code, or null when unknown.
  static String? regionForCountryCode(String countryCode) {
    final cc = countryCode.trim().toUpperCase();
    if (cc.isEmpty) return null;
    if (_africa.contains(cc)) return africa;
    if (_americas.contains(cc)) return americas;
    if (_asia.contains(cc)) {
      // Middle East countries conventionally grouped with Asia for this app.
      if (_middleEast.contains(cc)) return middleEast;
      return asia;
    }
    if (_oceania.contains(cc)) return oceania;
    if (_europe.contains(cc)) return europe;
    return null;
  }

  static const Set<String> _europe = {
    'AL', 'AD', 'AT', 'BY', 'BE', 'BA', 'BG', 'HR', 'CY', 'CZ',
    'DK', 'EE', 'FO', 'FI', 'FR', 'DE', 'GI', 'GR', 'GG', 'HU',
    'IS', 'IE', 'IM', 'IT', 'JE', 'LV', 'LI', 'LT', 'LU', 'MT',
    'MD', 'MC', 'ME', 'NL', 'MK', 'NO', 'PL', 'PT', 'RO', 'RU',
    'SM', 'RS', 'SK', 'SI', 'ES', 'SE', 'CH', 'UA', 'GB', 'VA',
  };

  static const Set<String> _middleEast = {
    'AE', 'BH', 'IL', 'IQ', 'IR', 'JO', 'KW', 'LB',
    'OM', 'PS', 'QA', 'SA', 'SY', 'YE',
  };

  /// Well-known country code → display name used to enrich M3U-originated
  /// records that have a country code but no name.
  static String? countryNameForCode(String countryCode) {
    const names = <String, String>{
      'NG': 'Nigeria',
      'ZA': 'South Africa',
      'UK': 'United Kingdom',
      'GB': 'United Kingdom',
      'US': 'United States',
      'FR': 'France',
      'DE': 'Germany',
      'CA': 'Canada',
      'AU': 'Australia',
      'IN': 'India',
      'JP': 'Japan',
      'BR': 'Brazil',
      'MX': 'Mexico',
      'GH': 'Ghana',
      'KE': 'Kenya',
      'EG': 'Egypt',
      'MA': 'Morocco',
      'IE': 'Ireland',
      'NZ': 'New Zealand',
      'ES': 'Spain',
      'IT': 'Italy',
      'PT': 'Portugal',
      'NL': 'Netherlands',
      'BE': 'Belgium',
      'SE': 'Sweden',
      'NO': 'Norway',
      'DK': 'Denmark',
      'FI': 'Finland',
      'PL': 'Poland',
      'RU': 'Russia',
      'UA': 'Ukraine',
      'TR': 'Turkey',
      'AR': 'Argentina',
      'CL': 'Chile',
      'CO': 'Colombia',
      'PE': 'Peru',
      'VE': 'Venezuela',
      'EC': 'Ecuador',
      'TW': 'Taiwan',
      'HK': 'Hong Kong',
      'KR': 'Korea',
      'SG': 'Singapore',
      'MY': 'Malaysia',
      'TH': 'Thailand',
      'ID': 'Indonesia',
      'PH': 'Philippines',
      'VN': 'Vietnam',
      'SA': 'Saudi Arabia',
      'AE': 'United Arab Emirates',
      'QA': 'Qatar',
      'KW': 'Kuwait',
      'IL': 'Israel',
      'GR': 'Greece',
      'CH': 'Switzerland',
      'AT': 'Austria',
      'CZ': 'Czech Republic',
      'HU': 'Hungary',
      'RO': 'Romania',
      'BG': 'Bulgaria',
      'HR': 'Croatia',
      'RS': 'Serbia',
    };
    return names[countryCode.trim().toUpperCase()];
  }
}
