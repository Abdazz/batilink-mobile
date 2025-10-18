import 'package:flutter/material.dart';
import '../unified_quotation_detail_screen.dart';

class QuotationDetailScreen extends StatelessWidget {
  final String quotationId;
  final Map<String, dynamic> quotation;
  final String token;

  const QuotationDetailScreen({
    Key? key,
    required this.quotationId,
    required this.quotation,
    required this.token,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return UnifiedQuotationDetailScreen(
      quotationId: quotationId,
      quotation: quotation,
      token: token,
      context: QuotationContext.professional,
    );
  }
}
