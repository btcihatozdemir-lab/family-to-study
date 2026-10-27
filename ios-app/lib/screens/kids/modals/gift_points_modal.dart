import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/kids_theme.dart';

class GiftPointsModal extends StatefulWidget {
  final UserModel student;
  final VoidCallback? onSuccess;

  const GiftPointsModal({super.key, required this.student, this.onSuccess});

  static Future<void> show(BuildContext context, UserModel student, {VoidCallback? onSuccess}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GiftPointsModal(student: student, onSuccess: onSuccess),
    );
  }

  @override
  State<GiftPointsModal> createState() => _GiftPointsModalState();
}

class _GiftPointsModalState extends State<GiftPointsModal> {
  List<UserModel> _siblings = [];
  UserModel? _selectedSibling;
  bool _isLoading = true;
  bool _isSending = false;
  int _transferAmount = 15;
  final TextEditingController _msgCtrl = TextEditingController(text: 'Sana benden destek puanı! 💛');

  @override
  void initState() {
    super.initState();
    _loadSiblings();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSiblings() async {
    final list = await SupabaseService.fetchSiblings(widget.student.familyId, widget.student.id);
    if (mounted) {
      setState(() {
        _siblings = list;
        if (list.isNotEmpty) _selectedSibling = list.first;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSendPoints() async {
    if (_selectedSibling == null) return;
    if (widget.student.pointsBalance < _transferAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yeterli puanın bulunmuyor!'),
          backgroundColor: KidsTheme.rose,
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    final ok = await SupabaseService.transferPointsToSibling(
      familyId: widget.student.familyId,
      senderId: widget.student.id,
      receiverId: _selectedSibling!.id,
      amount: _transferAmount,
      message: _msgCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (ok) {
      Navigator.pop(context);
      widget.onSuccess?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Text('💛 ', style: TextStyle(fontSize: 20)),
              Expanded(
                child: Text(
                  'Tebrikler Altın Kalp! ${_selectedSibling!.name} kardeşine $_transferAmount puan hediye ettin!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: KidsTheme.emerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Puan transferi sırasında bir hata oluştu.'),
          backgroundColor: KidsTheme.rose,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxAllowed = widget.student.pointsBalance;

    return Container(
      decoration: const BoxDecoration(
        color: KidsTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.amber, Colors.pinkAccent]),
                  shape: BoxShape.circle,
                ),
                child: const Text('💛', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Altın Kalp: Kardeşime Puan Gönder',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Kardeşler arası dayanışma ve sevgi puanı transferi',
                      style: TextStyle(color: KidsTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: KidsTheme.primary)))
          else if (_siblings.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: KidsTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Ailende kayıtlı başka bir kardeş profili bulunamadı.',
                style: TextStyle(color: KidsTheme.textMuted, fontSize: 13),
              ),
            )
          else ...[
            const Text(
              'Kardeşini Seç:',
              style: TextStyle(color: KidsTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Row(
              children: _siblings.map((sib) {
                final isSelected = _selectedSibling?.id == sib.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedSibling = sib),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? KidsTheme.primary : KidsTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? KidsTheme.primaryLight : Colors.white12,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(sib.avatarEmoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          sib.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Hediye Edilecek Puan:',
                  style: TextStyle(color: KidsTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: KidsTheme.gold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: KidsTheme.goldLight),
                  ),
                  child: Text(
                    '$_transferAmount Puan 🪙',
                    style: const TextStyle(color: KidsTheme.goldLight, fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ),
              ],
            ),
            Slider(
              value: _transferAmount.toDouble().clamp(5, (maxAllowed > 5 ? maxAllowed : 5).toDouble()),
              min: 5,
              max: (maxAllowed > 5 ? maxAllowed : 5).toDouble(),
              divisions: maxAllowed > 5 ? (maxAllowed ~/ 5).clamp(1, 20) : 1,
              activeColor: Colors.pinkAccent,
              inactiveColor: Colors.white12,
              onChanged: maxAllowed >= 5 ? (val) => setState(() => _transferAmount = val.round()) : null,
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _msgCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Kardeşine Not / Sevgi Mesajı',
                labelStyle: const TextStyle(color: KidsTheme.textSecondary),
                filled: true,
                fillColor: KidsTheme.surfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 18),

            ElevatedButton(
              onPressed: (_isSending || maxAllowed < 5) ? null : _handleSendPoints,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSending
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Altın Kalp Hediyesini Gönder 💛',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
