class OutletModel {
  final String id;
  final String name;
  final String address;
  final bool active;
  final String? tenantId;

  const OutletModel({
    required this.id,
    required this.name,
    required this.address,
    required this.active,
    this.tenantId,
  });

  OutletModel copyWith({
    String? name,
    String? address,
    bool? active,
    String? tenantId,
  }) =>
      OutletModel(
        id: id,
        name: name ?? this.name,
        address: address ?? this.address,
        active: active ?? this.active,
        tenantId: tenantId ?? this.tenantId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'active': active,
        'tenantId': tenantId,
      };

  factory OutletModel.fromJson(Map<String, dynamic> json) => OutletModel(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String? ?? '',
        active: json['active'] as bool? ?? true,
        tenantId: json['tenantId'] as String?,
      );
}
