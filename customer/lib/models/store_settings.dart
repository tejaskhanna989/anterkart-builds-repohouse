class StoreSettings {
  final String storeName;
  final double deliveryFee;
  final double minOrder;
  final String currency;
  final String razorpayKey;
  final String tenantName;
  final String? tenantLogo;
  final String tenantPhone;
  final bool codEnabled;
  final bool razorpayEnabled;

  StoreSettings({this.storeName = 'Otamzo', this.deliveryFee = 40, this.minOrder = 99, this.currency = 'INR', this.razorpayKey = '', this.tenantName = '', this.tenantLogo, this.tenantPhone = '', this.codEnabled = true, this.razorpayEnabled = false});

  factory StoreSettings.fromJson(Map<String, dynamic> j) => StoreSettings(
    storeName: j['store_name'] ?? 'Otamzo',
    deliveryFee: double.tryParse('${j['delivery_fee']}') ?? 40,
    minOrder: double.tryParse('${j['min_order']}') ?? 99,
    currency: j['currency'] ?? 'INR',
    razorpayKey: j['razorpay_key'] ?? '',
    tenantName: j['tenant_name'] ?? '',
    tenantLogo: j['tenant_logo'],
    tenantPhone: j['tenant_phone'] ?? '',
    codEnabled: j['cod_enabled'] != false,
    razorpayEnabled: j['razorpay_enabled'] == true,
  );
}
