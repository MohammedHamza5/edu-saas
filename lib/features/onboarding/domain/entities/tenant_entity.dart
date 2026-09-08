import 'package:equatable/equatable.dart';

class TenantEntity extends Equatable {
  final String id;
  final String name;
  final String? logoUrl;
  final String? email;
  final String? phone;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TenantEntity({
    required this.id,
    required this.name,
    this.logoUrl,
    this.email,
    this.phone,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == 'active';
  bool get isSuspended => status == 'suspended';

  @override
  List<Object?> get props => [
        id,
        name,
        logoUrl,
        email,
        phone,
        status,
        createdAt,
        updatedAt,
      ];
}
