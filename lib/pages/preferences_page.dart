import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import '../providers/locale_provider.dart';
import '../providers/subscription_provider.dart';
import '../l10n/app_localizations.dart';
import 'subscription_page.dart';

/// [PreferencesPage] menampilkan pengaturan preferensi pengguna,
/// termasuk menu Subscription, pemilihan bahasa, dan mode tampilan (Light/Dark).
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
    final subProvider = context.watch<SubscriptionProvider>();

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
            // === SUBSCRIPTION ===
            _buildSectionTitle(theme, 'SUBSCRIPTION'),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                ),
                title: Row(
                  children: [
                    const Text(
                      'Subscription',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: subProvider.isPremium
                            ? AppTheme.primary.withValues(alpha: 0.16)
                            : theme.colorScheme.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        subProvider.isPremium ? 'PREMIUM' : 'FREE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: subProvider.isPremium
                              ? AppTheme.primary
                              : theme.colorScheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  'Paket ${subProvider.subscription.planDisplayName} • ${subProvider.groupUsageText}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionPage(
                        isFirstTimeFlow: false,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // === BAHASA ===
            _buildSectionTitle(theme, AppLocalizations.of(context)!.languageSection),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                ),
              ),
              child: RadioGroup<String>(
                groupValue: localeProvider.locale.languageCode,
                onChanged: (value) {
                  if (value != null) {
                    final selectedLang = _languages.firstWhere(
                      (l) => l.code == value,
                      orElse: () => _languages.first,
                    );
                    localeProvider.setLocale(Locale(value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)!.languageChanged(selectedLang.name)),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: Column(
                  children: _languages.map((lang) {
                    final isSelected = localeProvider.locale.languageCode == lang.code;
                    return RadioListTile<String>(
                      value: lang.code,
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
                  color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                ),
              ),
              child: ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, currentMode, child) {
                  return RadioGroup<ThemeMode>(
                    groupValue: currentMode,
                    onChanged: (value) {
                      if (value != null) {
                        themeNotifier.value = value;
                      }
                    },
                    child: Column(
                      children: [
                        // Light Mode
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.light,
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
                          color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                        ),
                        // Dark Mode
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.dark,
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
                          color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                        ),
                        // System Default
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.system,
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
                    ),
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
