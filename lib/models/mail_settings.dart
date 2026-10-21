class MailSettings {
  final String userId;
  final String mode; // 'selected' | 'all'
  final bool syncEnabled;
  final String? gmailHistoryId;
  final DateTime? lastSyncedAt;
  final String? quietStart;
  final String? quietEnd;
  final bool dailyDigest;

  const MailSettings({
    required this.userId,
    this.mode = 'selected',
    this.syncEnabled = true,
    this.gmailHistoryId,
    this.lastSyncedAt,
    this.quietStart,
    this.quietEnd,
    this.dailyDigest = false,
  });

  factory MailSettings.fromMap(Map<String, dynamic> m) {
    return MailSettings(
      userId: m['user_id'] as String? ?? '',
      mode: m['mode'] as String? ?? 'selected',
      syncEnabled: m['sync_enabled'] as bool? ?? true,
      gmailHistoryId: m['gmail_history_id'] as String?,
      lastSyncedAt: m['last_synced_at'] != null ? DateTime.tryParse(m['last_synced_at'])?.toLocal() : null,
      quietStart: m['quiet_start'] as String?,
      quietEnd: m['quiet_end'] as String?,
      dailyDigest: m['daily_digest'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'mode': mode,
      'sync_enabled': syncEnabled,
      if (gmailHistoryId != null) 'gmail_history_id': gmailHistoryId,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt?.toIso8601String(),
      if (quietStart != null) 'quiet_start': quietStart,
      if (quietEnd != null) 'quiet_end': quietEnd,
      'daily_digest': dailyDigest,
    };
  }

  MailSettings copyWith({
    String? userId,
    String? mode,
    bool? syncEnabled,
    String? gmailHistoryId,
    DateTime? lastSyncedAt,
    String? quietStart,
    String? quietEnd,
    bool? dailyDigest,
  }) {
    return MailSettings(
      userId: userId ?? this.userId,
      mode: mode ?? this.mode,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      gmailHistoryId: gmailHistoryId ?? this.gmailHistoryId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      quietStart: quietStart ?? this.quietStart,
      quietEnd: quietEnd ?? this.quietEnd,
      dailyDigest: dailyDigest ?? this.dailyDigest,
    );
  }
}

