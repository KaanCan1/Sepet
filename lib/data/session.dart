import 'package:flutter/foundation.dart';

/// Oturum. Şimdilik bellekte; Aşama 7'de Node/Postgres backend'indeki
/// `/auth` uçlarına bağlanacak (JWT + refresh, fişler kullanıcıya bağlı).
class Session {
  const Session({
    required this.email,
    required this.since,
    required this.receipts,
    required this.observations,
    this.consentAggregate = false,
    this.consentMarketing = false,
  });

  final String email;
  final DateTime since;
  final int receipts;
  final int observations;

  /// KVKK açık rızası — ikisi de isteğe bağlı, varsayılan kapalı.
  /// Hesabın kendisi sözleşmenin ifasına (m. 5/2-c) dayanıyor, rızaya değil;
  /// bu yüzden bunlar kapalıyken de uygulama tam çalışır.
  final bool consentAggregate;
  final bool consentMarketing;

  Session copyWith({bool? consentAggregate, bool? consentMarketing}) => Session(
    email: email,
    since: since,
    receipts: receipts,
    observations: observations,
    consentAggregate: consentAggregate ?? this.consentAggregate,
    consentMarketing: consentMarketing ?? this.consentMarketing,
  );

  /// "kaan" -> "Kaan"
  String get displayName {
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
