import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_design/transit_design.dart';

import '../providers/agency_provider.dart';

/// Profile and Getting Around screen matching Transit iOS Dec 2025 screen 4.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _emoji = '👩‍🏫';
  String _nickname = 'KNOWLEDGE AKIMBO';

  void _editAvatar() async {
    final emojis = ['👩‍🏫', '🦊', '🚀', '⚡️', '🌟', '🎧', '🥑', '🏆', '🎯', '🐱'];
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose your avatar'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: emojis.map((e) {
            return InkWell(
              onTap: () => Navigator.pop(context, e),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _emoji == e ? TransitColors.brandGreenLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _emoji == e ? TransitColors.brandGreen : Colors.grey.shade300,
                  ),
                ),
                child: Text(e, style: const TextStyle(fontSize: 28)),
              ),
            );
          }).toList(),
        ),
      ),
    );

    if (selected != null) {
      setState(() => _emoji = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agency = ref.watch(agencyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF27AE60), // Vibrant Transit Green
      body: SafeArea(
        child: Stack(
          children: [
            // Top Right Close Button
            Positioned(
              top: 12,
              right: 16,
              child: InkWell(
                onTap: () => context.pop(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),

            ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                const SizedBox(height: 12),

                // Avatar with Blackboard/Framed backdrop
                Center(
                  child: InkWell(
                    onTap: _editAvatar,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A6B53), // Slate chalkboard green
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFC49A45), width: 3), // Wooden frame
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(_emoji, style: const TextStyle(fontSize: 44)),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Italic Bold All-Caps Name
                Text(
                  _nickname,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 8),

                // Score / Karma Pill
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('😊', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 6),
                        Text(
                          '0',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'SINCE 4 NOV 2025',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 20),

                // Transit Royale Upgrade Pill Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E824C).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Text('👑', style: TextStyle(fontSize: 22)),
                          SizedBox(width: 10),
                          Text(
                            'royale',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF196F3D),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Upgrade',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Section Title
                const Text(
                  'Getting around',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 14),

                // 2x2 Grid of Getting Around Cards
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.05,
                  children: [
                    _gettingAroundCard(
                      title: 'Public\ntransit',
                      icons: [
                        _miniBadge(Icons.directions_bus_rounded, Colors.grey.shade800),
                        _miniBadge(Icons.subway_rounded, const Color(0xFF2980B9)),
                      ],
                      onTap: () => context.pop(),
                    ),
                    _gettingAroundCard(
                      title: 'On the\nsidewalk',
                      icons: [
                        _miniBadge(Icons.accessible_rounded, const Color(0xFF3498DB)),
                        _miniBadge(Icons.directions_walk_rounded, const Color(0xFF27AE60)),
                      ],
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sidewalk & accessibility mode active')),
                        );
                      },
                    ),
                    _gettingAroundCard(
                      title: 'Two\nwheels',
                      icons: [
                        _miniBadge(Icons.pedal_bike_rounded, const Color(0xFF2ECC71)),
                        _miniBadge(Icons.electric_scooter_rounded, const Color(0xFF3498DB)),
                        _miniBadge(Icons.moped_rounded, Colors.grey.shade900),
                      ],
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bikes and scooters filtered')),
                        );
                      },
                    ),
                    _gettingAroundCard(
                      title: 'Four\nwheels',
                      icons: [
                        _miniBadge(Icons.directions_car_rounded, Colors.grey.shade800),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Uber',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Rideshare mode connected')),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Digital Pass Link
                TransitActionCard(
                  title: 'Digital Transit Pass',
                  subtitle: 'View active ticket & QR code',
                  icon: const Icon(Icons.qr_code_rounded, color: TransitColors.metroBlue),
                  margin: EdgeInsets.zero,
                  onTap: () => context.push('/ticket'),
                ),

                const SizedBox(height: 12),

                // Change Agency Link
                TransitActionCard(
                  title: 'Change Agency',
                  subtitle: 'Current: ${agency.agencySlug ?? 'demo-metro'}',
                  icon: const Icon(Icons.swap_horiz_rounded, color: TransitColors.brandGreen),
                  margin: EdgeInsets.zero,
                  onTap: () => context.go('/'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _gettingAroundCard({
    required String title,
    required List<Widget> icons,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(spacing: 6, runSpacing: 6, children: icons),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniBadge(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}
