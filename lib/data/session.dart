import 'package:flutter/foundation.dart';

/// Oturumun nasıl açıldığı. Apple ve Google ad döndürebiliyor, e-posta akışı
/// döndürmüyor — `displayName` bu yüzden ada öncelik verip e-postaya düşüyor.
enum AuthProvider {
  apple('Apple'),
  google('Google'),
  email('E-posta');

  const AuthProvider(this.label);
  final String label;
}

/// Oturum. Şimdilik bellekte; backend gelince `/auth` uçlarına bağlanacak
/// (JWT + refresh, fişler kullanıcıya bağlı).
class Session {
  const Session({
    required this.email,
    required this.provider,
    required this.since,
    required this.receipts,
    required this.observations,
    this.name,
    this.consentAggregate = false,
    this.consentMarketing = false,
  });

  final String email;
  final AuthProvider provider;
  final DateTime since;
  final int receipts;
  final int observations;

  /// Sağlayıcıdan geldiyse gerçek ad. Apple "adımı gizle" derse boş kalır.
  final String? name;

  /// KVKK açık rızası — ikisi de isteğe bağlı, varsayılan kapalı.
  /// Hesabın kendisi sözleşmenin ifasına (m. 5/2-c) dayanıyor, rızaya değil;
  /// bu yüzden bunlar kapalıyken de uygulama tam çalışır.
  final bool consentAggregate;
  final bool consentMarketing;

  Session copyWith({bool? consentAggregate, bool? consentMarketing}) => Session(
    email: email,
    provider: provider,
    since: since,
    receipts: receipts,
    observations: observations,
    name: name,
    consentAggregate: consentAggregate ?? this.consentAggregate,
    consentMarketing: consentMarketing ?? this.consentMarketing,
  );

  /// Sağlayıcı ad verdiyse onu, vermediyse e-postanın yerel kısmını kullan:
  /// "kaan.kurt@..." -> "Kaan"
  String get displayName {
    final given = name?.trim();
    if (given != null && given.isNotEmpty) return given;
    final local = email.split('@').first.split(RegExp(r'[._-]')).first;
    if (local.isEmpty) return email;
    return local[0].toUpperCase() + local.substring(1);
  }

  String get initials =>
      displayName.isEmpty ? '?' : displayName[0].toUpperCase();
}

/// Uygulama genelinde tek oturum kaynağı.
final session = ValueNotifier<Session?>(null);

bool isValidEmail(String v) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(v.trim());
