import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:water_drop_nav_bar/water_drop_nav_bar.dart';

import '../config/theme.dart';
import 'home/home_screen.dart';
import 'chat/chat_screen.dart';
import 'voice/voice_chat_screen.dart';
import 'journal/journal_list_screen.dart';
import 'settings/settings_screen.dart';

class MainShell extends StatefulWidget {
  static final globalKey = GlobalKey<MainShellState>();

  const MainShell({super.key});

  @override
  MainShellState createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  late PageController _pageController;

  static MainShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainShellState>() ??
      MainShell.globalKey.currentState;

  void switchTab(int screenIndex) {
    if (screenIndex < 0 || screenIndex > 4) return;
    setState(() => _currentIndex = screenIndex);
    _pageController.jumpToPage(screenIndex);
  }

  int get _navBarIndex {
    if (_currentIndex <= 1) return _currentIndex;
    if (_currentIndex == 2) return -1; // voice - not in nav bar
    return _currentIndex - 1; // 3→2, 4→3
  }

  void _onNavBarTap(int navIndex) {
    // navIndex: 0=Home, 1=Chat, 2=Journal, 3=Settings → screen: 0, 1, 3, 4
    final screenMap = [0, 1, 3, 4];
    final screenIndex = screenMap[navIndex];
    setState(() => _currentIndex = screenIndex);
    _pageController.jumpToPage(screenIndex);
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    ChatScreen(),
    VoiceChatScreen(),
    JournalListScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isVoiceScreen = _currentIndex == 2;
    final hideNavBar = isVoiceScreen;
    final hideVoiceFab = _currentIndex == 1 || isVoiceScreen;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: hideNavBar ? AppColors.background : AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: _screens,
        ),
        bottomNavigationBar: hideNavBar
            ? null
            : DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: WaterDropNavBar(
                  backgroundColor: AppColors.surface,
                  waterDropColor: AppColors.primary,
                  inactiveIconColor: AppColors.textTertiary,
                  iconSize: 26,
                  onItemSelected: _onNavBarTap,
                  selectedIndex: _navBarIndex.clamp(0, 3),
                  barItems: [
                    BarItem(
                      filledIcon: Icons.home_rounded,
                      outlinedIcon: Icons.home_outlined,
                    ),
                    BarItem(
                      filledIcon: Icons.chat_bubble_rounded,
                      outlinedIcon: Icons.chat_bubble_outline_rounded,
                    ),
                    BarItem(
                      filledIcon: Icons.edit_note_rounded,
                      outlinedIcon: Icons.edit_note_outlined,
                    ),
                    BarItem(
                      filledIcon: Icons.settings_rounded,
                      outlinedIcon: Icons.settings_outlined,
                    ),
                  ],
                ),
              ),
        floatingActionButton: hideVoiceFab ? null : _buildVoiceFab(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  Widget _buildVoiceFab() {
    final isActive = _currentIndex == 2;
    return GestureDetector(
      onTap: () => switchTab(2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isActive
                ? [AppColors.secondary, AppColors.secondaryDark]
                : [AppColors.primary, AppColors.primaryDark],
          ),
          boxShadow: [
            BoxShadow(
              color: (isActive ? AppColors.secondary : AppColors.primary)
                  .withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          isActive ? Icons.mic : Icons.mic_none_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
