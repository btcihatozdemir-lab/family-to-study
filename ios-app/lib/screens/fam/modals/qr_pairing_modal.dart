import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../theme/fam_theme.dart';
import '../../../services/supabase_service.dart';

class QrPairingModal extends StatelessWidget {
  final String familyId;
  final String familyCode;

  const QrPairingModal({
    super.key,
    required this.familyId,
    required this.familyCode,
  });

  static void show(BuildContext context, String familyId, String familyCode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QrPairingModal(familyId: familyId, familyCode: familyCode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrData = 'familytostudy://pair?familyId=$familyId&code=$familyCode';

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: FamTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('📷', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sihirli Bağlantı (Kamera ile QR)',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Kod yazmadan çocuğun iPad veya PC kamerasından okutun!',
                        style: TextStyle(color: FamTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: FamTheme.primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200.0,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: FamTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Aile Kodu: ', style: TextStyle(color: FamTheme.textMuted, fontSize: 12)),
                        Text(familyCode, style: const TextStyle(color: FamTheme.primaryLight, fontWeight: FontWeight.w900, fontSize: 16)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Çocuğunuzun Windows bilgisayarındaki veya tabletindeki "Kamera ile Eşleş" butonuna tıklayıp bu QR kodu ekrana tutmanız yeterlidir. 1 saniyede otomatik eşleşir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: FamTheme.textMuted, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
