import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Report reason options
class ReportReason {
  final String id;
  final String label;
  final IconData icon;

  const ReportReason({required this.id, required this.label, required this.icon});

  static const List<ReportReason> reasons = [
    ReportReason(id: 'toxic', label: 'Toxic / Kasar', icon: Icons.sentiment_very_dissatisfied),
    ReportReason(id: 'cheating', label: 'Curang', icon: Icons.warning_amber),
    ReportReason(id: 'afk', label: 'AFK / Tidak Aktif', icon: Icons.timer_off),
    ReportReason(id: 'inappropriate_name', label: 'Nama Tidak Pantas', icon: Icons.badge),
    ReportReason(id: 'spam', label: 'Spam', icon: Icons.message),
    ReportReason(id: 'other', label: 'Lainnya', icon: Icons.more_horiz),
  ];
}

/// Result returned from report dialog
class ReportResult {
  final String reason;
  final String? details;
  final bool alsoBlock;

  const ReportResult({required this.reason, this.details, this.alsoBlock = false});
}

/// Shows a report player dialog
/// Returns [ReportResult] if user confirms, null if cancelled
Future<ReportResult?> showReportDialog({
  required BuildContext context,
  required String playerName,
  bool showBlockOption = true,
}) async {
  return showDialog<ReportResult>(
    context: context,
    builder: (ctx) => _ReportDialog(playerName: playerName, showBlockOption: showBlockOption),
  );
}

class _ReportDialog extends StatefulWidget {
  final String playerName;
  final bool showBlockOption;

  const _ReportDialog({required this.playerName, this.showBlockOption = true});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _selectedReason;
  final _detailsController = TextEditingController();
  bool _alsoBlock = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.flag, color: Colors.red, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Laporkan ${widget.playerName}',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih alasan:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            // Reason selection
            ...ReportReason.reasons.map((reason) => _ReasonTile(
              reason: reason,
              isSelected: _selectedReason == reason.id,
              onTap: () => setState(() => _selectedReason = reason.id),
            )),
            const SizedBox(height: 16),
            // Details text field
            TextField(
              controller: _detailsController,
              maxLength: 200,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Detail tambahan (opsional)',
                hintStyle: TextStyle(color: AppColors.textMuted.withOpacity( 0.5)),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterStyle: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            // Block option
            if (widget.showBlockOption) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _alsoBlock,
                onChanged: (v) => setState(() => _alsoBlock = v ?? false),
                title: const Text(
                  'Blokir pemain ini juga',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                subtitle: const Text(
                  'Anda tidak akan dipasangkan dengan pemain ini',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
                checkColor: Colors.black,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: _selectedReason != null
              ? () => Navigator.of(context).pop(ReportResult(
                  reason: _selectedReason!,
                  details: _detailsController.text.trim().isNotEmpty ? _detailsController.text.trim() : null,
                  alsoBlock: _alsoBlock,
                ))
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade700,
          ),
          child: const Text('Laporkan'),
        ),
      ],
    );
  }
}

class _ReasonTile extends StatelessWidget {
  final ReportReason reason;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReasonTile({required this.reason, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? AppColors.primary.withOpacity( 0.2) : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  reason.icon,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  reason.label,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
