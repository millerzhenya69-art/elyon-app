/// Subscription tiers matching the roadmap
enum SubscriptionTier {
  core,       // Free — 15 msg/day
  nova,       // 91₽/mo — 25 msg/day
  pro,        // 182₽/mo — 30 msg/day
  absolution, // 265₽/mo — 30 msg/day
}

extension SubscriptionTierX on SubscriptionTier {
  String get displayName {
    switch (this) {
      case SubscriptionTier.core:       return 'Core';
      case SubscriptionTier.nova:       return 'Nova';
      case SubscriptionTier.pro:        return 'PRO';
      case SubscriptionTier.absolution: return 'Absolution';
    }
  }

  String get modelId {
    switch (this) {
      case SubscriptionTier.core:       return 'gpt';
      case SubscriptionTier.nova:       return 'nova';
      case SubscriptionTier.pro:        return 'pro';
      case SubscriptionTier.absolution: return 'absolution';
    }
  }

  /// Human-readable model label shown in UI — no third-party branding
  String get modelLabel {
    switch (this) {
      case SubscriptionTier.core:       return 'Elyon Core';
      case SubscriptionTier.nova:       return 'Elyon Nova';
      case SubscriptionTier.pro:        return 'Elyon PRO';
      case SubscriptionTier.absolution: return 'Elyon Absolution';
    }
  }

  int get dailyLimit {
    switch (this) {
      case SubscriptionTier.core:       return 15;
      case SubscriptionTier.nova:       return 25;
      case SubscriptionTier.pro:        return 30;
      case SubscriptionTier.absolution: return 30;
    }
  }

  /// Monthly price in RUB. 0 = free.
  int get priceRub {
    switch (this) {
      case SubscriptionTier.core:       return 0;
      case SubscriptionTier.nova:       return 91;
      case SubscriptionTier.pro:        return 182;
      case SubscriptionTier.absolution: return 265;
    }
  }

  String get priceLabel =>
      priceRub == 0 ? 'Free' : '$priceRub ₽ / mo';

  String get description {
    switch (this) {
      case SubscriptionTier.core:
        return 'Fast and always free. Perfect for everyday questions and quick tasks.';
      case SubscriptionTier.nova:
        return 'Smarter and faster. Built for work that demands real quality.';
      case SubscriptionTier.pro:
        return 'Deep reasoning and nuanced analysis for complex challenges.';
      case SubscriptionTier.absolution:
        return 'Maximum capability. The most powerful intelligence Elyon offers.';
    }
  }

  bool get isFree     => priceRub == 0;
  bool get isFeatured => this == SubscriptionTier.pro;
}

/// App user
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.avatarUrl,
    required this.tier,
    required this.messagesUsedToday,
    required this.isOwner,
    required this.authProvider,
    required this.joinedAt,
    this.subscriptionExpiresAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final SubscriptionTier tier;
  final int messagesUsedToday;
  final bool isOwner;
  final String authProvider; // 'google' | 'telegram' | 'email'
  final DateTime joinedAt;
  final DateTime? subscriptionExpiresAt;

  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  }

  int get remainingMessages =>
      (tier.dailyLimit - messagesUsedToday).clamp(0, tier.dailyLimit);

  bool get canSendMessage => remainingMessages > 0;

  AppUser copyWith({
    String? displayName,
    SubscriptionTier? tier,
    int? messagesUsedToday,
    DateTime? subscriptionExpiresAt,
  }) =>
      AppUser(
        id:                      id,
        email:                   email,
        displayName:             displayName             ?? this.displayName,
        avatarUrl:               avatarUrl,
        tier:                    tier                    ?? this.tier,
        messagesUsedToday:       messagesUsedToday       ?? this.messagesUsedToday,
        isOwner:                 isOwner,
        authProvider:            authProvider,
        joinedAt:                joinedAt,
        subscriptionExpiresAt:   subscriptionExpiresAt   ?? this.subscriptionExpiresAt,
      );

  Map<String, dynamic> toJson() => {
        'id':                    id,
        'email':                 email,
        'displayName':           displayName,
        'avatarUrl':             avatarUrl,
        'tier':                  tier.name,
        'messagesUsedToday':     messagesUsedToday,
        'isOwner':               isOwner,
        'authProvider':          authProvider,
        'joinedAt':              joinedAt.toIso8601String(),
        'subscriptionExpiresAt': subscriptionExpiresAt?.toIso8601String(),
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id:            json['id'] as String,
        email:         json['email'] as String,
        displayName:   json['displayName'] as String,
        avatarUrl:     json['avatarUrl'] as String?,
        tier:          SubscriptionTier.values
            .firstWhere((t) => t.name == (json['tier'] as String? ?? 'core'),
                orElse: () => SubscriptionTier.core),
        messagesUsedToday:     json['messagesUsedToday'] as int? ?? 0,
        isOwner:               json['isOwner'] as bool? ?? false,
        authProvider:          json['authProvider'] as String? ?? 'email',
        joinedAt:              DateTime.parse(json['joinedAt'] as String),
        subscriptionExpiresAt: json['subscriptionExpiresAt'] != null
            ? DateTime.parse(json['subscriptionExpiresAt'] as String)
            : null,
      );
}
