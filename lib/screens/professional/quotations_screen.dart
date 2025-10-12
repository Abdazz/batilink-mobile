import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class QuotationsScreen extends StatefulWidget {
  final String token;
  
  const QuotationsScreen({Key? key, required this.token}) : super(key: key);

  @override
  _QuotationsScreenState createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends State<QuotationsScreen> {
  List<dynamic> _quotations = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchQuotations();
  }

  Future<void> _fetchQuotations() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? widget.token;

      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/quotations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _quotations = data['data'] ?? [];
        });
      } else {
        setState(() {
          _error = 'Erreur lors du chargement des devis';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur de connexion: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Devis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchQuotations,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchQuotations,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_quotations.isEmpty) {
      return const Center(
        child: Text('Aucun devis trouvé'),
      );
    }

    return ListView.builder(
      itemCount: _quotations.length,
      itemBuilder: (context, index) {
        final quotation = _quotations[index];
        return _buildQuotationCard(quotation);
      },
    );
  }

  Widget _buildQuotationCard(Map<String, dynamic> quotation) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          'Devis #${quotation['id']?.substring(0, 8) ?? 'N/A'}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Description: ${quotation['description'] ?? 'Non spécifiée'}'),
            Text('Statut: ${_getStatusText(quotation['status'])}'),
            if (quotation['amount'] != null)
              Text('Montant: ${quotation['amount']} FCFA'),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: Naviguer vers les détails du devis
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(
          //     builder: (context) => QuotationDetailScreen(
          //       quotationId: quotation['id'],
          //       token: widget.token,
          //     ),
          //   ),
          // );
        },
      ),
    );
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'accepted':
        return 'Accepté';
      case 'rejected':
        return 'Refusé';
      case 'expired':
        return 'Expiré';
      default:
        return status ?? 'Inconnu';
    }
  }
}
