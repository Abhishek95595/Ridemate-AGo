import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../home/home_screen.dart';
import '../../core/widgets/app_avatar.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int currentPage = 0;

  final List<Map<String, dynamic>> pages = [
    {
      "avatarIndex": 0,
      "title": "Find Your Perfect Ride",
      "subtitle":
          "Travel with verified drivers and passengers using AGo without paying any platform fee.",
      "color": const Color(0xFF14B8A6),
    },
    {
      "avatarIndex": 5,
      "title": "Share Your Journey",
      "subtitle":
          "Offer rides on AGo to people travelling on the same route and save fuel & money.",
      "color": const Color(0xFF0D9488),
    },
    {
      "avatarIndex": 10,
      "title": "Safe & Trusted",
      "subtitle":
          "Verified AGo users, live tracking and secure experience for every journey.",
      "color": const Color(0xFF08234C),
    },
  ];

  void goToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: goToHome, child: const Text("Skip")),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (index) {
                  setState(() {
                    currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final page = pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: (page["color"] as Color).withValues(
                              alpha: 0.1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: AppAvatar(
                              avatarIndex: page["avatarIndex"],
                              size: 160,
                              borderWidth: 0,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 50),
                        Text(
                          page["title"],
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF08234C),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          page["subtitle"],
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  height: 10,
                  width: currentPage == index ? 30 : 10,
                  decoration: BoxDecoration(
                    color: currentPage == index
                        ? const Color(0xFF14B8A6)
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () {
                    if (currentPage == pages.length - 1) {
                      goToHome();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: Text(
                    currentPage == pages.length - 1 ? "Get Started" : "Next",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
