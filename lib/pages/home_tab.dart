import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_textfield.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../providers/subscription_provider.dart';
import '../models/subscription_model.dart';
import '../services/routing_service.dart';
import 'map_page.dart';
import 'subscription_page.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final RoutingService _routingService = RoutingService();

  /// Mengecek apakah user masih memiliki kuota grup sebelum membuat / bergabung grup.
  /// Jika batas grup sudah tercapai, tampilkan bottom sheet prompt Upgrade ke Premium.
  Future<bool> _checkGroupLimitOrShowPrompt(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final subProvider = context.read<SubscriptionProvider>();
    final uid = authProvider.user?.uid;

    if (uid != null && !subProvider.isInitialized) {
      await subProvider.initializeForUser(uid);
    }

    if (!context.mounted) return false;

    if (subProvider.canCreateOrJoinGroup) {
      return true;
    }

    _showGroupLimitReachedSheet(context, subProvider);
    return false;
  }

  void _showGroupLimitReachedSheet(
    BuildContext context,
    SubscriptionProvider subProvider,
  ) {
    final isPremiumActive = subProvider.isPremium;
    final isExpired = subProvider.isPremiumExpired;

    final String titleText = isPremiumActive
        ? 'Kamu sudah mencapai batas grup paket Premium'
        : 'Kamu sudah mencapai batas grup untuk paket Free';

    final String subtitleText = isExpired
        ? 'Masa aktif paket Premium kamu sudah berakhir (${subProvider.usedGroupsCount}/${subProvider.maxGroups} grup terpakai). Grup lama tetap aman dan bisa dilihat, namun kamu perlu memperbarui langganan Premium untuk menambah grup baru.'
        : (isPremiumActive
            ? 'Kamu telah menggunakan maksimal ${PlanLimits.premiumMaxGroups} grup pada paket Premium.'
            : 'Paket Free dibatasi maksimal ${PlanLimits.freeMaxGroups} grup (${subProvider.usedGroupsCount}/${PlanLimits.freeMaxGroups} grup terpakai). Upgrade ke Trackie Premium untuk membuat atau bergabung hingga ${PlanLimits.premiumMaxGroups} grup perjalanan!');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, Color(0xFF4A0FBF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                titleText,
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitleText,
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(
                  fontSize: 14.5,
                  color: const Color(0xFF6B6F9A),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionPage(
                        isFirstTimeFlow: false,
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                label: Text(
                  'Upgrade ke Premium',
                  style: GoogleFonts.urbanist(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(sheetCtx),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Nanti saja',
                  style: GoogleFonts.urbanist(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B6F9A),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCreateGroupModal(BuildContext context) async {
    final canProceed = await _checkGroupLimitOrShowPrompt(context);
    if (!canProceed || !context.mounted) return;

    final groupNameController = TextEditingController();
    final destinationController = TextEditingController();
    String? selectedVehicleType;
    PlaceSuggestion? selectedPlace;
    List<PlaceSuggestion> suggestions = [];
    bool isSearchingPlace = false;
    bool isCreating = false;
    Timer? debounceTimer;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            void onDestinationChanged(String value) {
              selectedPlace = null;
              debounceTimer?.cancel();
              if (value.trim().length < 3) {
                setModalState(() {
                  suggestions = [];
                  isSearchingPlace = false;
                });
                return;
              }
              setModalState(() => isSearchingPlace = true);
              debounceTimer = Timer(const Duration(milliseconds: 450), () async {
                final res = await _routingService.searchPlaces(value);
                if (context.mounted) {
                  setModalState(() {
                    suggestions = res;
                    isSearchingPlace = false;
                  });
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.homeCreateTripTitle,
                      style: GoogleFonts.urbanist(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 24),
                    CustomTextField(
                      label: 'Nama Grup',
                      hint: 'contoh: Touring Lembang',
                      controller: groupNameController,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'TUJUAN PERGI (CARI LOKASI RUTE)',
                      style: GoogleFonts.urbanist(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6B6F9A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: destinationController,
                      onChanged: onDestinationChanged,
                      style: GoogleFonts.urbanist(
                        color: const Color(0xFF1A1A2E),
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ketik tujuan (contoh: Kawah Putih, Ciwidey)',
                        hintStyle: GoogleFonts.urbanist(
                          color: const Color(0xFF6B6F9A),
                        ),
                        prefixIcon: const Icon(
                          Icons.location_searching_rounded,
                          color: AppTheme.primary,
                        ),
                        suffixIcon: isSearchingPlace
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              )
                            : (selectedPlace != null
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.green,
                                  )
                                : null),
                        filled: true,
                        fillColor: const Color(0xFFF7F7FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEDEDF2)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: suggestions.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: Color(0xFFEDEDF2)),
                          itemBuilder: (ctx, i) {
                            final item = suggestions[i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.place_rounded,
                                color: AppTheme.primary,
                                size: 20,
                              ),
                              title: Text(
                                item.title,
                                style: GoogleFonts.urbanist(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: const Color(0xFF1A1A2E),
                                ),
                              ),
                              subtitle: Text(
                                item.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.urbanist(
                                  fontSize: 12,
                                  color: const Color(0xFF6B6F9A),
                                ),
                              ),
                              onTap: () {
                                debounceTimer?.cancel();
                                destinationController.text = item.title;
                                setModalState(() {
                                  selectedPlace = item;
                                  suggestions = [];
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'TIPE KENDARAAN',
                      style: GoogleFonts.urbanist(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6B6F9A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      dropdownColor: Colors.white,
                      style: GoogleFonts.urbanist(
                        color: const Color(0xFF1A1A2E),
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF7F7FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      items: ['Motor', 'Mobil', 'Sepeda'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setModalState(() => selectedVehicleType = val),
                      hint: Text(
                        'Pilih Tipe Kendaraan',
                        style: GoogleFonts.urbanist(
                          color: const Color(0xFF6B6F9A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: isCreating
                          ? null
                          : () async {
                              if (groupNameController.text.trim().isEmpty ||
                                  destinationController.text.trim().isEmpty ||
                                  selectedVehicleType == null) {
                                return;
                              }
                              final authProvider = context.read<AuthProvider>();
                              final subProvider =
                                  context.read<SubscriptionProvider>();
                              final currentUid = authProvider.user?.uid;
                              if (currentUid == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Sesi login tidak valid. Silakan login kembali.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              if (!subProvider.canCreateOrJoinGroup) {
                                Navigator.pop(context);
                                _showGroupLimitReachedSheet(
                                  this.context,
                                  subProvider,
                                );
                                return;
                              }

                              setModalState(() => isCreating = true);
                              final groupProvider =
                                  context.read<GroupProvider>();

                              final encodedDestination =
                                  RoutingService.encodeDestination(
                                destinationController.text.trim(),
                                selectedPlace?.point,
                              );

                              final success = await groupProvider.createGroup(
                                name: groupNameController.text.trim(),
                                type: selectedVehicleType!,
                                destination: encodedDestination,
                                hostUid: currentUid,
                              );

                              if (!context.mounted) return;

                              if (success) {
                                subProvider.onGroupCreatedOrJoined(currentUid);
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MapPage(isHost: true),
                                  ),
                                );
                              } else {
                                setModalState(() => isCreating = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      groupProvider.error ??
                                          'Gagal membuat grup',
                                    ),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: isCreating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'MULAI PERJALANAN',
                              style: GoogleFonts.urbanist(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      debounceTimer?.cancel();
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        groupNameController.dispose();
        destinationController.dispose();
      });
    });
  }

  Future<void> _showJoinGroupModal(BuildContext context) async {
    final canProceed = await _checkGroupLimitOrShowPrompt(context);
    if (!canProceed || !context.mounted) return;

    final inviteCodeController = TextEditingController();
    bool isJoining = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppLocalizations.of(context)!.homeJoinTripTitle,
                    style: GoogleFonts.urbanist(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomTextField(
                    label: 'Kode Undangan',
                    hint: 'contoh: TRG-42A9B1',
                    controller: inviteCodeController,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: isJoining
                        ? null
                        : () async {
                            if (inviteCodeController.text.trim().isEmpty) return;
                            final authProvider = context.read<AuthProvider>();
                            final subProvider =
                                context.read<SubscriptionProvider>();
                            final currentUid = authProvider.user?.uid;
                            if (currentUid == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Sesi login tidak valid. Silakan login kembali.',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (!subProvider.canCreateOrJoinGroup) {
                              Navigator.pop(context);
                              _showGroupLimitReachedSheet(
                                this.context,
                                subProvider,
                              );
                              return;
                            }

                            setModalState(() => isJoining = true);
                            final groupProvider = context.read<GroupProvider>();

                            final success = await groupProvider.joinGroup(
                              inviteCode: inviteCodeController.text.trim(),
                              uid: currentUid,
                            );

                            if (!context.mounted) return;

                            if (success) {
                              subProvider.onGroupCreatedOrJoined(currentUid);
                              final isHost = groupProvider.activeGroup
                                      ?.isHost(currentUid) ??
                                  false;
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MapPage(isHost: isHost),
                                ),
                              );
                            } else {
                              setModalState(() => isJoining = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    groupProvider.error ??
                                        'Gagal bergabung grup',
                                  ),
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A0FBF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isJoining
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'GABUNG',
                            style: GoogleFonts.urbanist(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        inviteCodeController.dispose();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final groupProvider = context.watch<GroupProvider>();
    final subProvider = context.watch<SubscriptionProvider>();
    final userProfile = authProvider.userProfile;

    final bool hasActiveTrip = groupProvider.hasActiveGroup;
    final String activeTripName =
        groupProvider.activeGroup?.name ?? 'Perjalanan';
    final String userName = userProfile?.name ?? 'Rider';
    final String firstName = userName.split(' ')[0];

    final List<Map<String, dynamic>> upcomingTrips = [
      {
        'title': 'Sunmori Puncak Pas',
        'date': '12',
        'month': 'OKT',
        'time': '06:00',
        'relativeTime': '8 hari lagi',
        'meetingPoint': 'SPBU X',
        'members': 8,
        'role': 'Member',
      },
      {
        'title': 'Touring Lintas Provinsi',
        'date': '20',
        'month': 'OKT',
        'time': '05:30',
        'relativeTime': '2 minggu lagi',
        'meetingPoint': 'Rest Area KM 57',
        'members': 14,
        'role': 'Host',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                AppLocalizations.of(context)!
                                    .homeGreeting(firstName),
                                style: GoogleFonts.urbanist(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A1A2E),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
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
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: subProvider.isPremium
                                      ? const LinearGradient(
                                          colors: [
                                            AppTheme.primary,
                                            Color(0xFF4A0FBF),
                                          ],
                                        )
                                      : null,
                                  color: subProvider.isPremium
                                      ? null
                                      : const Color(0xFFEDEDF2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.workspace_premium_rounded,
                                      size: 13,
                                      color: subProvider.isPremium
                                          ? Colors.white
                                          : const Color(0xFF4A0FBF),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      subProvider.isPremium ? 'PRO' : 'FREE',
                                      style: GoogleFonts.urbanist(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: subProvider.isPremium
                                            ? Colors.white
                                            : const Color(0xFF4A0FBF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${AppLocalizations.of(context)!.homeSubtitle} • ${subProvider.groupUsageText}',
                          style: GoogleFonts.urbanist(
                            fontSize: 14,
                            color: const Color(0xFF6B6F9A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Stack(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          image: userProfile?.photoUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(userProfile!.photoUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: userProfile?.photoUrl == null
                            ? Text(
                                firstName.isNotEmpty
                                    ? firstName[0].toUpperCase()
                                    : 'U',
                                style: GoogleFonts.urbanist(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFF7F7FA),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Active Trip Banner
              if (hasActiveTrip) ...[
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        final isHost = groupProvider.activeGroup
                                ?.isHost(authProvider.user?.uid ?? '') ??
                            false;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MapPage(isHost: isHost),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.navigation_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.of(context)!.homeActiveTrip,
                                    style: GoogleFonts.urbanist(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    activeTripName,
                                    style: GoogleFonts.urbanist(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // Primary Actions
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      context: context,
                      title: 'Create Trip',
                      icon: Icons.add_road_rounded,
                      color: AppTheme.primary,
                      onTap: () => _showCreateGroupModal(context),
                      isPrimary: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                      context: context,
                      title: 'Join Trip',
                      icon: Icons.tag_rounded,
                      color: const Color(0xFF4A0FBF),
                      onTap: () => _showJoinGroupModal(context),
                      isPrimary: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Upcoming Trips Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rencana Perjalanan',
                    style: GoogleFonts.urbanist(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Lihat Semua',
                      style: GoogleFonts.urbanist(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Upcoming Trips List
              ...upcomingTrips.map((trip) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: const Color(0xFFEDEDF2), width: 1),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {},
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date Block
                            Container(
                              width: 56,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F1F5),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    trip['date'],
                                    style: GoogleFonts.urbanist(
                                      color: const Color(0xFF1A1A2E),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      height: 1.1,
                                    ),
                                  ),
                                  Text(
                                    trip['month'],
                                    style: GoogleFonts.urbanist(
                                      color: const Color(0xFF6B6F9A),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Trip Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          trip['title'],
                                          style: GoogleFonts.urbanist(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1A1A2E),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        trip['time'],
                                        style: GoogleFonts.urbanist(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1A1A2E),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 14,
                                        color: Color(0xFF6B6F9A),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          trip['meetingPoint'],
                                          style: GoogleFonts.urbanist(
                                            fontSize: 13,
                                            color: const Color(0xFF6B6F9A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      // Role Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: trip['role'] == 'Host'
                                              ? AppTheme.primary
                                                  .withValues(alpha: 0.15)
                                              : const Color(0xFFF1F1F5),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          trip['role'],
                                          style: GoogleFonts.urbanist(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: trip['role'] == 'Host'
                                                ? AppTheme.primary
                                                : const Color(0xFF6B6F9A),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Member Count
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F1F5),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.group_outlined,
                                              size: 12,
                                              color: Color(0xFF6B6F9A),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${trip['members']} pax',
                                              style: GoogleFonts.urbanist(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF6B6F9A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isPrimary ? color : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPrimary ? color : const Color(0xFFEDEDF2),
          width: 1,
        ),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                )
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? Colors.white.withValues(alpha: 0.2)
                        : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: isPrimary ? Colors.white : color,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: GoogleFonts.urbanist(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isPrimary ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
