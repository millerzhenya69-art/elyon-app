import '../theme/app_theme.dart';

enum AppLanguage { english, russian }

enum FontSizeOption { small, medium, large }

extension FontSizeOptionX on FontSizeOption {
  String get label {
    switch (this) {
      case FontSizeOption.small:  return 'Small';
      case FontSizeOption.medium: return 'Medium';
      case FontSizeOption.large:  return 'Large';
    }
  }

  double get scale {
    switch (this) {
      case FontSizeOption.small:  return 0.88;
      case FontSizeOption.medium: return 1.0;
      case FontSizeOption.large:  return 1.14;
    }
  }
}

extension AppLanguageX on AppLanguage {
  String get label {
    switch (this) {
      case AppLanguage.english: return 'English';
      case AppLanguage.russian: return 'Русский';
    }
  }

  String get code {
    switch (this) {
      case AppLanguage.english: return 'en';
      case AppLanguage.russian: return 'ru';
    }
  }
}

class AppSettings {
  const AppSettings({
    this.themeMode     = AppThemeMode.dark,
    this.language      = AppLanguage.english,
    this.fontSize      = FontSizeOption.medium,
    this.streamingEnabled = true,
    this.soundEnabled  = false,
  });

  final AppThemeMode   themeMode;
  final AppLanguage    language;
  final FontSizeOption fontSize;
  final bool streamingEnabled;
  final bool soundEnabled;

  AppSettings copyWith({
    AppThemeMode?   themeMode,
    AppLanguage?    language,
    FontSizeOption? fontSize,
    bool?           streamingEnabled,
    bool?           soundEnabled,
  }) =>
      AppSettings(
        themeMode:        themeMode        ?? this.themeMode,
        language:         language         ?? this.language,
        fontSize:         fontSize         ?? this.fontSize,
        streamingEnabled: streamingEnabled ?? this.streamingEnabled,
        soundEnabled:     soundEnabled     ?? this.soundEnabled,
      );

  Map<String, dynamic> toJson() => {
        'themeMode':        themeMode.name,
        'language':         language.name,
        'fontSize':         fontSize.name,
        'streamingEnabled': streamingEnabled,
        'soundEnabled':     soundEnabled,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        themeMode: AppThemeMode.values.firstWhere(
          (v) => v.name == json['themeMode'],
          orElse: () => AppThemeMode.dark,
        ),
        language: AppLanguage.values.firstWhere(
          (v) => v.name == json['language'],
          orElse: () => AppLanguage.english,
        ),
        fontSize: FontSizeOption.values.firstWhere(
          (v) => v.name == json['fontSize'],
          orElse: () => FontSizeOption.medium,
        ),
        streamingEnabled: json['streamingEnabled'] as bool? ?? true,
        soundEnabled:     json['soundEnabled']     as bool? ?? false,
      );
}
