import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_wrapper.dart';

/// Sentry splash screen.
///
/// Usage (e.g. in main.dart):
///
///   MaterialApp(
///     home: SplashScreen(nextScreen: const HomeScreen()),
///   );
///
/// Uses the icon PNG from Assets/images/Sentry.png.
///
/// Animation sequence (total ~2.2s):
/// 1. Icon scales up (80% -> 100%) while fading in (~0.2s–0.9s).
/// 2. Brief pause (~0.9s–1.3s).
/// 3. Icon pulses once (100% -> 112% -> 100%), like a single heartbeat (~1.3s–1.7s).
/// 4. The "sentry" wordmark fades in and slides up slightly (~1.6s–2.2s).
/// 5. Brief hold (~0.3s), then fades into [nextScreen].
class SplashScreen extends StatefulWidget {
  final Widget? nextScreen;
  final VoidCallback? onAnimationComplete;
  final bool autoNavigate;

  const SplashScreen({
    super.key,
    this.nextScreen,
    this.onAnimationComplete,
    this.autoNavigate = true,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _iconAssetPath = 'Assets/images/Sentry.png';
  static const _green = Color(0xFF1F9D55);

  late final AnimationController _controller;

  late final Animation<double> _entranceScale;
  late final Animation<double> _pulseScale;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<Offset> _wordmarkOffset;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Phase 1 (~0.2s-0.9s): icon scales + fades in.
    _entranceScale = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.09, 0.41, curve: Curves.easeOut),
      ),
    );
    _iconOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.09, 0.41, curve: Curves.easeOut),
      ),
    );

    // Phase 2 (~1.3s-1.7s): icon pulses once.
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.59, 0.77, curve: Curves.linear),
      ),
    );

    // Phase 3 (~1.6s-2.2s): wordmark fades in and slides up.
    _wordmarkOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.73, 1.0, curve: Curves.easeOut),
      ),
    );
    _wordmarkOffset = Tween(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.73, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          if (widget.onAnimationComplete != null) {
            widget.onAnimationComplete!();
          } else if (widget.autoNavigate) {
            final targetScreen = widget.nextScreen ?? const AuthWrapper();
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 400),
                pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
                  opacity: animation,
                  child: targetScreen,
                ),
              ),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final scale = _entranceScale.value * _pulseScale.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: _iconOpacity.value,
                    child: Transform.scale(
                      scale: scale,
                      child: Image.asset(
                        _iconAssetPath,
                        width: 120,
                        height: 120,
                        semanticLabel: 'Academic Assistant App Logo',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SlideTransition(
                    position: _wordmarkOffset,
                    child: Opacity(
                      opacity: _wordmarkOpacity.value,
                      child: Text(
                        'sentry',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 32,
                          fontWeight: FontWeight.w500,
                          color: _green,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
