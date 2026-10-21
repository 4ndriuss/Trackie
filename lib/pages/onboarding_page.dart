import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../models/onboarding_item.dart';
import 'login_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  static const int _cacheWidth = 800;

  static const List<OnboardingItem> items = [
    OnboardingItem(
      title: "Your Adventure Starts Here",
      description:
          "Discover new places, plan exciting journeys, and capture unforgettable memories as you explore the world around you.",
      imagePath: "assets/images/dino-reichmuth-A5rCN8626Ck-unsplash.jpg",
    ),
    OnboardingItem(
      title: "Track Your Daily Trips",
      description:
          "Effortlessly record your routes, analyze your travel patterns, and keep a detailed history of all your daily commutes.",
      imagePath: "assets/images/paul-green-gOHfFgwyDNM-unsplash.jpg",
    ),
    OnboardingItem(
      title: "Stay Connected With Friends",
      description:
          "Share your adventures, find travel buddies, and stay updated with your friends' latest journeys in real-time.",
      imagePath: "assets/images/toomas-tartes-Yizrl9N_eDA-unsplash.jpg",
    ),
  ];

  /// Mengembalikan [ImageProvider] dengan kunci yang konsisten antara
  /// `precacheImage` dan widget [Image] agar tidak terjadi cache miss.
  static ImageProvider<Object> imageProvider(String imagePath) =>
      ResizeImage.resizeIfNeeded(_cacheWidth, null, AssetImage(imagePath));

  /// Preload semua gambar onboarding ke memori.
  static Future<void> precacheAll(BuildContext context) async {
    await Future.wait(
      items.map((item) => precacheImage(imageProvider(item.imagePath), context)),
    );
  }

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isNavigating = false;

  List<OnboardingItem> get _items => OnboardingPage.items;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload images into memory with matching ResizeImage key so they appear instantly
    OnboardingPage.precacheAll(context);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (_isNavigating) return;
    _isNavigating = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final imageHeight = size.height * 0.5;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          NotificationListener<ScrollUpdateNotification>(
            onNotification: (notification) {
              // Detect swiping further on the last page
              if (_currentIndex == _items.length - 1 &&
                  notification.metrics.pixels >
                      notification.metrics.maxScrollExtent + 40) {
                _completeOnboarding();
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: _items.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return _buildPageContent(_items[index], imageHeight);
              },
            ),
          ),

          // Skip Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 24,
            child: GestureDetector(
              onTap: _completeOnboarding,
              child: Container(
                width: 64,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.skipButtonBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Skip",
                  style: GoogleFonts.urbanist(
                    color: AppColors.skipButtonText,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),

          // Page Indicator
          Positioned(
            bottom: size.height * 0.15,
            left: 0,
            right: 0,
            child: _buildPageIndicator(),
          ),

          // 'Get Started' Button on last page
          if (_currentIndex == _items.length - 1)
            Positioned(
              bottom: size.height * 0.05,
              left: 24,
              right: 24,
              child: ElevatedButton(
                onPressed: _completeOnboarding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  "Get Started",
                  style: GoogleFonts.urbanist(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPageContent(OnboardingItem item, double imageHeight) {
    return Column(
      children: [
        ClipPath(
          clipper: CurvedClipper(),
          child: ColoredBox(
            color: AppColors.imagePlaceholder,
            child: SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: Image(
                image: OnboardingPage.imageProvider(item.imagePath),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: child,
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            item.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: GoogleFonts.urbanist(
              color: AppColors.textTitle,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            item.description,
            textAlign: TextAlign.center,
            maxLines: 4,
            style: GoogleFonts.urbanist(
              color: AppColors.textDescription,
              fontSize: 18,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _items.length,
        (index) {
          final isActive = _currentIndex == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 8,
            width: isActive ? 32 : 8,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary
                  : AppColors.indicatorInactive,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        },
      ),
    );
  }
}

/// A custom clipper that creates a wide elliptical arc at the bottom.
class CurvedClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 60);
    // Control point determines the curvature of the arc
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 30, // Pushing the curve downwards
      size.width,
      size.height - 60,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
