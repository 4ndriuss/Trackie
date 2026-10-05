import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import '../providers/locale_provider.dart';
import '../l10n/app_localizations.dart';

/// [PreferencesPage] menampilkan pengaturan preferensi pengguna,
/// termasuk pemilihan bahasa dan mode tampilan (Light/Dark).
class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  // Daftar bahasa yang tersedia
  static const List<_LanguageOption> _languages = [
    _LanguageOption(code: 'id', name: 'Bahasa Indonesia', flag: '🇮🇩'),
    _LanguageOption(code: 'en', name: 'English', flag: '🇺🇸'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.preferencesTitle),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === BAHASA ===
            _buildSectionTitle(theme, AppLocalizations.of(context)!.languageSection),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.2), // ignore: deprecated_member_use
                ),
              ),
              child: Column(
                children: _languages.map((lang) {
                  final isSelected = localeProvider.locale.languageCode == lang.code;
                  return RadioListTile<String>(
                    value: lang.code,
                    groupValue: localeProvider.locale.languageCode,
                    onChanged: (value) {
                      if (value != null) {
                        localeProvider.setLocale(Locale(value));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppLocalizations.of(context)!.languageChanged(lang.name)),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    title: Text(
                      '${lang.flag}  ${lang.name}',
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    activeColor: theme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // === TAMPILAN ===
            _buildSectionTitle(theme, AppLocalizations.of(context)!.appearanceSection),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.2), // ignore: deprecated_member_use
                ),
              ),
              child: ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, currentMode, child) {
                  return Column(
                    children: [
                      // Light Mode
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.light,
                        groupValue: currentMode,
                        onChanged: (value) {
                          themeNotifier.value = value!;
                        },
                        title: Row(
                          children: [
                            const Icon(Icons.light_mode, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Text(AppLocalizations.of(context)!.lightMode),
                          ],
                        ),
                        subtitle: Text(AppLocalizations.of(context)!.lightModeDesc),
                        activeColor: theme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: AppSpacing.md,
                        endIndent: AppSpacing.md,
                        color: theme.colorScheme.secondary.withValues(alpha: 0.15), // ignore: deprecated_member_use
                      ),
                      // Dark Mode
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.dark,
                        groupValue: currentMode,
                        onChanged: (value) {
                          themeNotifier.value = value!;
                        },
                        title: Row(
                          children: [
                            const Icon(Icons.dark_mode, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Text(AppLocalizations.of(context)!.darkMode),
                          ],
                        ),
                        subtitle: Text(AppLocalizations.of(context)!.darkModeDesc),
                        activeColor: theme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: AppSpacing.md,
                        endIndent: AppSpacing.md,
                        color: theme.colorScheme.secondary.withValues(alpha: 0.15), // ignore: deprecated_member_use
                      ),
                      // System Default
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.system,
                        groupValue: currentMode,
                        onChanged: (value) {
                          themeNotifier.value = value!;
                        },
                        title: Row(
                          children: [
                            const Icon(Icons.settings_brightness, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Text(AppLocalizations.of(context)!.systemMode),
                          ],
                        ),
                        subtitle: Text(AppLocalizations.of(context)!.systemModeDesc),
                        activeColor: theme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.secondary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

/// Model data untuk opsi bahasa.
class _LanguageOption {
  final String code;
  final String name;
  final String flag;

  const _LanguageOption({
    required this.code,
    required this.name,
    required this.flag,
  });
}
