class AddressModel {
  final int id;
  final String label;
  final String address;
  final double lat;
  final double lng;
  final bool isDefault;

  AddressModel({required this.id, this.label = 'Home', required this.address, this.lat = 0, this.lng = 0, this.isDefault = false});

  factory AddressModel.fromJson(Map<String, dynamic> j) => AddressModel(
    id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
    label: j['label'] ?? 'Home',
    address: j['address'] ?? '',
    lat: double.tryParse('${j['lat']}') ?? 0,
    lng: double.tryParse('${j['lng']}') ?? 0,
    isDefault: j['is_default'] == 1 || j['is_default'] == true,
  );
}
