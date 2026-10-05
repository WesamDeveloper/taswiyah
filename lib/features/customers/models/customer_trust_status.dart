enum CustomerTrustStatus {
  unknown,
  trusted,
  untrusted;

  static CustomerTrustStatus fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'trusted':
        return CustomerTrustStatus.trusted;
      case 'untrusted':
        return CustomerTrustStatus.untrusted;
      case 'unknown':
      default:
        return CustomerTrustStatus.unknown;
    }
  }

  static CustomerTrustStatus fromDbValue(String? value) => fromString(value);

  String get dbValue => name;

  String get label {
    switch (this) {
      case CustomerTrustStatus.trusted:
        return 'موثوق';
      case CustomerTrustStatus.untrusted:
        return 'غير موثوق';
      case CustomerTrustStatus.unknown:
        return 'غير محدد';
    }
  }
}

enum CustomerTrustFilter {
  all,
  trusted,
  untrusted;

  String get label {
    switch (this) {
      case CustomerTrustFilter.all:
        return 'الكل';
      case CustomerTrustFilter.trusted:
        return 'موثوق';
      case CustomerTrustFilter.untrusted:
        return 'غير موثوق';
    }
  }

  /// Returns the corresponding dbValue to query SQLite ('trusted', 'untrusted', or null for 'all')
  String? get dbValue {
    switch (this) {
      case CustomerTrustFilter.all:
        return null;
      case CustomerTrustFilter.trusted:
        return 'trusted';
      case CustomerTrustFilter.untrusted:
        return 'untrusted';
    }
  }
}
