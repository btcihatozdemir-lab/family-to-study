import 'package:flutter/material.dart';
import '../theme/kids_theme.dart';

class ConvexBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const ConvexBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    const double barHeight = 66.0;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      color: Colors.transparent,
      height: barHeight + bottomPadding + 26.0,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // 1. Kavisli Convex Bar Arka Planı (fixedCircle stili)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: barHeight + bottomPadding,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width, barHeight + bottomPadding),
              painter: _ConvexBarPainter(
                backgroundColor: KidsTheme.surfaceElevated,
                borderColor: Colors.white.withOpacity(0.12),
              ),
            ),
          ),

          // 2. Navigasyon İkonları (Solda 2, Sağda 2)
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPadding,
            height: barHeight,
            child: Row(
              children: [
                // Tab 0: Görevler
                Expanded(
                  child: _buildSideItem(
                    index: 0,
                    icon: Icons.rocket_launch_rounded,
                    label: 'Görevler',
                  ),
                ),
                // Tab 1: Çanta & Ders
                Expanded(
                  child: _buildSideItem(
                    index: 1,
                    icon: Icons.backpack_rounded,
                    label: 'Çanta',
                  ),
                ),
                // Ortadaki Çıkıntılı Buton İçin Boşluk
                const SizedBox(width: 72),
                // Tab 3: Kasa & Çark
                Expanded(
                  child: _buildSideItem(
                    index: 3,
                    icon: Icons.savings_rounded,
                    label: 'Kasa',
                  ),
                ),
                // Tab 4: Profil
                Expanded(
                  child: _buildSideItem(
                    index: 4,
                    icon: Icons.person_rounded,
                    label: 'Profil',
                  ),
                ),
              ],
            ),
          ),

          // 3. ORTADAKİ ÇIKINTILI SABİT DAİRE BUTON (fixedCircle: 📻 TELSİZ)
          Positioned(
            bottom: bottomPadding + 22.0,
            child: GestureDetector(
              onTap: () => onTabSelected(2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selectedIndex == 2
                      ? const LinearGradient(
                          colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  border: Border.all(
                    color: selectedIndex == 2 ? Colors.tealAccent : Colors.teal.withOpacity(0.5),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: selectedIndex == 2
                          ? Colors.tealAccent.withOpacity(0.45)
                          : Colors.black.withOpacity(0.5),
                      blurRadius: selectedIndex == 2 ? 16 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '📻',
                        style: TextStyle(
                          fontSize: selectedIndex == 2 ? 24 : 20,
                        ),
                      ),
                      Text(
                        'Telsiz',
                        style: TextStyle(
                          color: selectedIndex == 2 ? Colors.white : Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool isSelected = selectedIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTabSelected(index),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? KidsTheme.primary.withOpacity(0.2) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? KidsTheme.goldLight : Colors.white54,
                size: isSelected ? 24 : 21,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                color: isSelected ? Colors.white : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConvexBarPainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;

  _ConvexBarPainter({required this.backgroundColor, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    final w = size.width;
    final h = size.height;
    final centerX = w / 2;

    // fixedCircle kavis geometrisi
    const double curveWidth = 46.0;
    const double hillHeight = 24.0;

    path.moveTo(0, 0);
    path.lineTo(centerX - curveWidth - 10, 0);

    // Tepeye doğru pürüzsüz kavis
    path.cubicTo(
      centerX - curveWidth, 0,
      centerX - 30, -hillHeight,
      centerX, -hillHeight,
    );

    // Tepeden aşağıya doğru pürüzsüz kavis
    path.cubicTo(
      centerX + 30, -hillHeight,
      centerX + curveWidth, 0,
      centerX + curveWidth + 10, 0,
    );

    path.lineTo(w, 0);
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    // Gölgelendirme
    canvas.drawShadow(path, Colors.black.withOpacity(0.4), 10.0, true);

    // Arka plan dolgusu
    canvas.drawPath(path, paint);

    // Üst kenar çizgisi (Border outline)
    final borderPath = Path()
      ..moveTo(0, 0)
      ..lineTo(centerX - curveWidth - 10, 0)
      ..cubicTo(
        centerX - curveWidth, 0,
        centerX - 30, -hillHeight,
        centerX, -hillHeight,
      )
      ..cubicTo(
        centerX + 30, -hillHeight,
        centerX + curveWidth, 0,
        centerX + curveWidth + 10, 0,
      )
      ..lineTo(w, 0);

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
