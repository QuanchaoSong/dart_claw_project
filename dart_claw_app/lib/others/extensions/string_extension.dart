extension ForImageAsset on String {
  String imageAssetPath({imageFormat = "png"}) {
    return ("assets/images/" + this + "." + imageFormat);
  }
}

extension Convenience on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  String ensuredString() {
    return this ?? '';
  }

  bool isValidEmail() {
    if (this == null || this!.isEmpty) return false;

    String emailPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    RegExp regex = RegExp(emailPattern);
    return regex.hasMatch(this!);
  }

  bool isValidPhoneNumber() {
    if (this == null || this!.isEmpty) return false;

    String phonePattern = r'^\+?[0-9]{7,15}$';
    RegExp regex = RegExp(phonePattern);
    return regex.hasMatch(this!);
  }
}
