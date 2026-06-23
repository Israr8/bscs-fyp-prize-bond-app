// lib/widgets/bond_result_card.dart
import 'package:flutter/material.dart';
import 'package:app/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class BondResultCard extends StatelessWidget {
  final String bondNumber;
  final String denomination;
  final DateTime? drawDate;
  final String? drawNumber;
  final bool isWinner;
  final int? prizeAmount;
  final String? prizeType;
  final bool showActions;
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final VoidCallback? onCheckAgain;
  final String? city;

  const BondResultCard({
    super.key,
    required this.bondNumber,
    required this.denomination,
    this.drawDate,
    this.drawNumber,
    this.isWinner = false,
    this.prizeAmount,
    this.prizeType,
    this.showActions = true,
    this.onSave,
    this.onShare,
    this.onCheckAgain,
    this.city,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isWinner ? Colors.green.withValues(alpha:0.3) : Colors.grey.withValues(alpha:0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status — left block must shrink so denomination never overflows.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isWinner ? Colors.green.withValues(alpha:0.1) : Colors.blue.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isWinner ? Colors.green : Colors.blue,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isWinner ? Icons.emoji_events : Icons.confirmation_number,
                              size: 16,
                              color: isWinner ? Colors.green : Colors.blue,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isWinner ? 'WINNER' : 'CHECKED',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isWinner ? Colors.green : Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          denomination,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  bondNumber.length >= 3
                      ? '#${bondNumber.substring(0, 3)}***'
                      : '#$bondNumber',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Bond Number
            Center(
              child: Text(
                bondNumber,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: AppColors.primaryColor,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Results Details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  if (isWinner && prizeAmount != null) ...[
                    _buildDetailRow('Prize Amount', 'Rs. ${NumberFormat('#,##0').format(prizeAmount)}'),
                    _buildDetailRow('Prize Type', prizeType?.toUpperCase() ?? ''),
                    if (drawNumber != null)
                      _buildDetailRow('Draw Number', drawNumber!),
                    if (drawDate != null)
                      _buildDetailRow('Draw Date', DateFormat('dd MMM yyyy').format(drawDate!)),
                  ] else ...[
                    _buildDetailRow('Status', 'Not a winning bond'),
                    _buildDetailRow('Message', 'Better luck next time!'),
                  ],
                ],
              ),
            ),

            // Actions (if enabled)
            if (showActions) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSave,
                      icon: const Icon(Icons.bookmark_border),
                      label: const Text('Save'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onShare,
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (onCheckAgain != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onCheckAgain,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Check Again'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ],

            // Timestamp
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Checked: ${DateFormat('hh:mm a').format(DateTime.now())}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}