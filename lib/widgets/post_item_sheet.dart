import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/utils/constants.dart';
import 'package:app/models/market_item.dart';

typedef PostMarketplaceCallback = void Function(
  String bondNumber,
  String denomination,
  double askingPrice,
  String description,
  String location,
  String sellerPhone,
);

class PostItemSheet extends StatefulWidget {
  final PostMarketplaceCallback onPost;
  final MarketItem? item;
  final bool isEdit;

  const PostItemSheet({
    super.key,
    required this.onPost,
    this.item,
    this.isEdit = false,
  });

  @override
  State<PostItemSheet> createState() => _PostItemSheetState();
}

class _PostItemSheetState extends State<PostItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _bondNumberController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();

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
      _phoneController.text = widget.item!.sellerPhone;
    }
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please add your contact number';
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      return 'Enter at least 10 digits';
    }
    if (digits.length > 15) {
      return 'Number is too long';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final h = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: (h * 0.9).clamp(400.0, h * 0.95),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isEdit ? 'Edit listing' : 'Sell your bond',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.isEdit
                              ? 'Update your listing details'
                              : 'Your number is shown to the buyer only after they confirm purchase',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey[600],
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _bondNumberController,
                        decoration: InputDecoration(
                          labelText: 'Bond number *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          prefixIcon: const Icon(Icons.confirmation_number_outlined),
                          hintText: '10-digit bond number',
                        ),
                        enabled: !widget.isEdit,
                        maxLength: 10,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter bond number';
                          }
                          if (value.length < 10) {
                            return 'Must be 10 digits';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        value: _selectedDenomination,
                        decoration: InputDecoration(
                          labelText: 'Denomination *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          prefixIcon: const Icon(Icons.currency_exchange_outlined),
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
                            return 'Select denomination';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _priceController,
                        decoration: InputDecoration(
                          labelText: 'Asking price (Rs.) *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          prefixIcon: const Icon(Icons.sell_outlined),
                          prefixText: 'Rs. ',
                          hintText: 'e.g. 210',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter price';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Enter a valid number';
                          }
                          if (double.parse(value) <= 0) {
                            return 'Must be greater than zero';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: 'Contact / WhatsApp number *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          prefixIcon: const Icon(Icons.phone_android_outlined),
                          hintText: '03XX XXXXXXX',
                          helperText:
                              'Shown only to the buyer after purchase; hidden on the listing',
                          helperMaxLines: 2,
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d+\s\-]')),
                        ],
                        validator: _validatePhone,
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: 'City / area *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          prefixIcon: const Icon(Icons.place_outlined),
                          hintText: 'e.g. Karachi, Gulberg Lahore',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter city or area';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description (optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          prefixIcon: const Icon(Icons.notes_outlined),
                          hintText: 'Condition, series, notes…',
                        ),
                        maxLines: 3,
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            widget.isEdit ? 'Save changes' : 'Post listing',
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
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final rawPhone = _phoneController.text.trim();
      final digitsOnly = rawPhone.replaceAll(RegExp(r'\D'), '');
      widget.onPost(
        _bondNumberController.text.trim(),
        _selectedDenomination!,
        double.parse(_priceController.text.trim()),
        _descriptionController.text.trim(),
        _locationController.text.trim(),
        digitsOnly.isNotEmpty ? digitsOnly : rawPhone,
      );
    }
  }

  @override
  void dispose() {
    _bondNumberController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
