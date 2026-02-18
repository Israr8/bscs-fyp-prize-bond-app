import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/utils/constants.dart';
import 'package:app/models/market_item.dart'; // ✅ Import model

class PostItemSheet extends StatefulWidget {
  final Function(String, String, double, String, String) onPost;
  final MarketItem? item;
  final bool isEdit;

  const PostItemSheet({
    Key? key,
    required this.onPost,
    this.item,
    this.isEdit = false,
  }) : super(key: key);

  @override
  State<PostItemSheet> createState() => _PostItemSheetState();
}

class _PostItemSheetState extends State<PostItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _bondNumberController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  String? _selectedDenomination;
  final List<String> _denominations = [
    'Rs. 100',
    'Rs. 200',
    'Rs. 750',
    'Rs. 1500',
    'Rs. 7500',
    'Rs. 15,000',
    'Rs. 25,000',
    'Rs. 40,000',
  ];

  @override
  void initState() {
    super.initState();

    if (widget.isEdit && widget.item != null) {
      _bondNumberController.text = widget.item!.bondNumber;
      _selectedDenomination = widget.item!.denomination;
      _priceController.text = widget.item!.askingPrice.toString();
      _descriptionController.text = widget.item!.description;
      _locationController.text = widget.item!.location;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.isEdit ? 'Edit Bond' : 'Post Bond for Sale',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 20),

            TextFormField(
              controller: _bondNumberController,
              decoration: InputDecoration(
                labelText: 'Bond Number*',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.confirmation_number_outlined),
                hintText: 'Enter 10-digit bond number',
              ),
              enabled: !widget.isEdit,
              maxLength: 10,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter bond number';
                }
                if (value.length < 10) {
                  return 'Bond number must be 10 digits';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedDenomination,
              decoration: InputDecoration(
                labelText: 'Denomination*',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.money_outlined),
              ),
              items: _denominations
                  .map((denom) => DropdownMenuItem(
                value: denom,
                child: Text(denom),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDenomination = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select denomination';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: 'Asking Price*',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.attach_money_outlined),
                prefixText: 'Rs. ',
                hintText: 'e.g., 210',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter price';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter valid price';
                }
                if (double.parse(value) <= 0) {
                  return 'Price must be greater than 0';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Location*',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.location_on_outlined),
                hintText: 'e.g., Karachi, Lahore',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter location';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.description_outlined),
                hintText: 'Describe condition, history, or special notes...',
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  widget.isEdit ? 'Update Bond' : 'Post for Sale',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      widget.onPost(
        _bondNumberController.text.trim(),
        _selectedDenomination!,
        double.parse(_priceController.text),
        _descriptionController.text.trim(),
        _locationController.text.trim(),
      );
    }
  }

  @override
  void dispose() {
    _bondNumberController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}