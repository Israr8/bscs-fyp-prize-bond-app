// lib/widgets/bond_item.dart - UPDATE IF EXISTS
import 'package:flutter/material.dart';
import 'package:app/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class BondItem extends StatelessWidget {
  final String bondNumber;
  final String denomination;
  final DateTime savedDate;
  final bool isWinner;
  final int? prizeAmount;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const BondItem({
    super.key,
    required this.bondNumber,
    required this.denomination,
    required this.savedDate,
    this.isWinner = false,
    this.prizeAmount,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isWinner ? Colors.green.withValues(alpha:0.1) : AppColors.primaryColor.withValues(alpha:0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isWinner ? Icons.emoji_events : Icons.wallet_outlined,
            color: isWinner ? Colors.green : AppColors.primaryColor,
          ),
        ),
        title: Text(
          bondNumber,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              denomination,
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              'Saved: ${DateFormat('dd MMM yyyy').format(savedDate)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isWinner && prizeAmount != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: Text(
                  'Rs. ${NumberFormat('#,##0').format(prizeAmount)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (onDelete != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
                tooltip: 'Delete bond',
              ),
            ],
          ],
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}