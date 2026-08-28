import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_design/transit_design.dart';

/// "GO" active transit companion mode matching Transit iOS Dec 2025 screen 38.
class GoNavigationScreen extends ConsumerStatefulWidget {
  const GoNavigationScreen({
    super.key,
    required this.routeId,
    required this.destination,
    this.routeColor = const Color(0xFFF58220),
    this.initialStep = 0,
  });

  final String routeId;
  final String destination;
  final Color routeColor;
  final int initialStep;

  @override
  ConsumerState<GoNavigationScreen> createState() => _GoNavigationScreenState();
}

class _GoNavigationScreenState extends ConsumerState<GoNavigationScreen> {
  int _currentStep = 0;
  CrowdingLevel? _reportedCrowding;
  bool _tripCompleted = false;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _tripCompleted ? _buildCelebrationView() : _buildGoActiveView(),
    );
  }

  Widget _buildGoActiveView() {
    return Stack(
      children: [
        // Simulated Interactive Map Canvas with Route Paths
        Positioned.fill(
          child: Container(
            color: const Color(0xFFF5F2E9), // Light map land background
            child: CustomPaint(
              painter: _MapRoutePainter(routeColor: widget.routeColor),
            ),
          ),
        ),

        // Top Navigation Header (Close & Recenter buttons)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.near_me_rounded, color: TransitColors.brandGreen, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'To ${widget.destination}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8),
                          ],
                        ),
                        child: const Icon(Icons.navigation_rounded, color: Colors.black87, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => context.pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8),
                          ],
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.red, size: 22),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Bottom GO Panel (Transit iOS Screen 38)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Walking Step Tag
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF0D5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5C88F)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_walk_rounded, size: 16, color: Color(0xFF855D18)),
                    SizedBox(width: 6),
                    Text(
                      '4 minutes to stop',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF855D18),
                      ),
                    ),
                  ],
                ),
              ),

              // Main Trip Overview Card with GO Badge
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Leave at 5:15 PM',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1E293B),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Arrive at 5:51 PM',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.only(right: 60),
                                child: Text(
                                  '36 min',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Transit Multi-Segment Progress Line
                          Row(
                            children: [
                              _dot(Colors.grey.shade400),
                              const SizedBox(width: 4),
                              _dot(Colors.grey.shade400),
                              const SizedBox(width: 4),
                              _dot(Colors.grey.shade400),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF58220), // Yellow/Orange bus leg
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 3,
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE20613), // Red Line train leg
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _dot(Colors.grey.shade400),
                              const SizedBox(width: 4),
                              _dot(Colors.grey.shade400),
                              const SizedBox(width: 4),
                              _dot(Colors.grey.shade400),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Golden Yellow GO Floating Emblem
                    Positioned(
                      top: -12,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFCC00),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFCC00).withValues(alpha: 0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Text(
                          'GO',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Departure Options Carousel
              SizedBox(
                height: 115,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _liveDepartureCard('29', isLive: true, color: const Color(0xFF855D18)),
                    const SizedBox(width: 10),
                    _liveDepartureCard('32', isLive: true, color: const Color(0xFF855D18)),
                    const SizedBox(width: 10),
                    _liveDepartureCard('52', isLive: false, color: const Color(0xFF855D18)),
                  ],
                ),
              ),

              // Advance Button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.routeColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        setState(() => _tripCompleted = true);
                      },
                      child: const Text(
                        'Arrived at Destination',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _liveDepartureCard(String minutes, {required bool isLive, required Color color}) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                minutes,
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1.0,
                ),
              ),
              if (isLive) ...[
                const SizedBox(width: 2),
                Icon(Icons.wifi_tethering_rounded, color: color, size: 14),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'minutes',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCelebrationView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F8EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: TransitColors.brandGreen,
                size: 52,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Great Success!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You arrived at ${widget.destination}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8EE),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: TransitColors.brandGreen.withValues(alpha: 0.3)),
              ),
              child: const Column(
                children: [
                  Text(
                    '🎉 You helped 325 riders!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: TransitColors.brandGreenDark,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'By broadcasting with GO, other passengers saw accurate real-time arrivals.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: TransitColors.brandGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => context.pop(),
                child: const Text('Awesome', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapRoutePainter extends CustomPainter {
  _MapRoutePainter({required this.routeColor});
  final Color routeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.3);
    path.cubicTo(
      size.width * 0.4,
      size.height * 0.2,
      size.width * 0.6,
      size.height * 0.4,
      size.width * 0.8,
      size.height * 0.35,
    );

    final paint = Paint()
      ..color = const Color(0xFFF58220)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);

    final subwayPath = Path();
    subwayPath.moveTo(size.width * 0.8, size.height * 0.35);
    subwayPath.lineTo(size.width * 0.75, size.height * 0.6);

    final subwayPaint = Paint()
      ..color = const Color(0xFFE20613)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(subwayPath, subwayPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
