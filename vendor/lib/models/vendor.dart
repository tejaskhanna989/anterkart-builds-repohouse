class Vendor {
  final int id;
  final int tenantId;
  final String tenantName;
  final String name;
  final String email;
  final String phone;
  final String status;

  Vendor({
    required this.id,
    required this.tenantId,
    this.tenantName = '',
    required this.name,
    this.email = '',
    this.phone = '',
    this.status = 'active',
  });

  factory Vendor.fromJson(Map<String, dynamic> j, [Map<String, dynamic>? tenant]) => Vendor(
    id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
    tenantId: j['tenant_id'] is int ? j['tenant_id'] : int.tryParse('${j['tenant_id']}') ?? 0,
    tenantName: tenant?['name'] ?? j['tenant_name'] ?? '',
    name: j['name'] ?? '',
    email: j['email'] ?? '',
    phone: j['phone'] ?? '',
    status: j['status'] ?? 'active',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'tenant_name': tenantName,
    'name': name,
    'email': email,
    'phone': phone,
    'status': status,
  };
}
