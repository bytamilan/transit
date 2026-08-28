import 'package:flutter/material.dart';
import 'package:transit_design/transit_design.dart';

/// Digital transit ticket and QR validation screen.
class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key});

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transit Pass'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ticket Card
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 380),
                decoration: BoxDecoration(
                  color: isDark ? TransitColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: isDark ? TransitColors.darkBorder : TransitColors.lightBorder,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Moving animated security banner
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return Container(
                          height: 12,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: const [
                                TransitColors.brandGreen,
                                TransitColors.metroCyan,
                                TransitColors.metroYellow,
                                TransitColors.metroRed,
                                TransitColors.brandGreen,
                              ],
                              stops: [
                                0.0,
                                (_animController.value * 0.5).clamp(0.0, 1.0),
                                (_animController.value).clamp(0.0, 1.0),
                                (_animController.value * 0.8 + 0.2).clamp(0.0, 1.0),
                                1.0,
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'STANDARD FARE',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                      color: isDark ? Colors.white54 : TransitColors.lightSubtext,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '1-Ride + Transfer',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: TransitColors.statusOnTime.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: TransitColors.statusOnTime),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: TransitColors.statusOnTime,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // QR Code Container
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade300, width: 2),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 180,
                                  color: Colors.grey.shade900,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'TRN-8492-9104-LA',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Expiration Timer
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? TransitColors.darkBackground : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.timer_outlined, size: 18, color: TransitColors.metroOrange),
                                const SizedBox(width: 8),
                                Text(
                                  'Expires in 1 hr 45 min',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Hold QR code against the optical validator when boarding.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : TransitColors.lightSubtext,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
