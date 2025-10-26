import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/pro_client_service.dart';

class ProClientRespondQuotationsScreen extends StatefulWidget {
  final String? token;
  final Map<String, dynamic>? userData;
  final String? filterMode; // 'pending' (devis à répondre) ou 'active' (jobs pro)

  const ProClientRespondQuotationsScreen({
    Key? key,
    this.token,
    this.userData,
    this.filterMode,
  }) : super(key: key);

  @override
  State<ProClientRespondQuotationsScreen> createState() => _ProClientRespondQuotationsScreenState();
}

class _ProClientRespondQuotationsScreenState extends State<ProClientRespondQuotationsScreen> {
  final ProClientService _proClientService = ProClientService(
    baseUrl: 'http://10.0.2.2:8000',
    authService: AuthService(baseUrl: 'http://10.0.2.2:8000'),
  );

  List<dynamic> _quotations = [];
  bool _isLoading = true;
  String? _error;
  bool _isProClient = false;
  String _finalToken = '';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Détecter si l'utilisateur est un pro_client
    _isProClient = _detectProClientRole();

    // Récupérer le token depuis SharedPreferences comme secours
    final prefs = await SharedPreferences.getInstance();
    final tokenFromPrefs = prefs.getString('token') ?? '';

    // Utiliser le token passé en argument, ou celui de SharedPreferences comme secours
    _finalToken = widget.token?.isNotEmpty == true ? widget.token! : tokenFromPrefs;

    if (_finalToken.isEmpty) {
      setState(() {
        _error = 'Token d\'accès non trouvé';
        _isLoading = false;
      });
      return;
    }

    _loadQuotations();
  }

  bool _detectProClientRole() {
    // Vérifier les données utilisateur passées en argument
    final userData = widget.userData;
    if (userData != null) {
      // Vérifier si le rôle est directement dans userData
      if (userData.containsKey('role') && userData['role'] == 'pro_client') {
        return true;
      }
      // Vérifier la structure imbriquée data.user.role
      if (userData.containsKey('data') &&
          userData['data'] is Map &&
          userData['data']['user'] is Map &&
          userData['data']['user']['role'] == 'pro_client') {
        return true;
      }
      // Vérifier la structure imbriquée user.role
      if (userData.containsKey('user') &&
          userData['user'] is Map &&
          userData['user']['role'] == 'pro_client') {
        return true;
      }
    }

    return false;
  }

  Future<void> _loadQuotations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _proClientService.getQuotations(
        accessToken: _finalToken,
        context: 'professional', // Mode professionnel
      );

      if (response.statusCode == 200) {
        final data = await _proClientService.parseProClientProfileResponse(response);
        if (data != null && data['quotations'] != null) {
          var list = List<dynamic>.from(data['quotations'] as List<dynamic>);
          // Appliquer filtre selon filterMode
          final mode = widget.filterMode ?? 'pending';
          if (mode == 'pending') {
            list = list.where((q) => (q['status']?.toString().toLowerCase() ?? '') == 'pending').toList();
          } else if (mode == 'active') {
            const activeStatuses = {'accepted', 'in_progress', 'completed', 'cancelled'};
            list = list.where((q) => activeStatuses.contains((q['status']?.toString().toLowerCase() ?? ''))).toList();
          }
          setState(() {
            _quotations = list;
          });
        } else {
          setState(() {
            _quotations = [];
          });
        }
      } else {
        setState(() => _error = 'Erreur lors du chargement des devis');
      }
    } catch (e) {
      setState(() => _error = 'Erreur: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.filterMode ?? 'pending';
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(mode == 'active' ? 'Mes jobs (pro)' : 'Répondre aux devis'),
            const SizedBox(width: 8),
            if (_isProClient)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 1),
                ),
                child: Text(
                  'MODE PRO-CLIENT',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: const Color(0xFFFFCC00),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadQuotations,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _quotations.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.question_answer, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Aucun devis à traiter',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _quotations.length,
                      itemBuilder: (context, index) {
                        final quotation = _quotations[index];
                        return _buildQuotationCard(quotation);
                      },
                    ),
    );
  }

  Widget _buildQuotationCard(dynamic quotation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quotation['title'] ?? 'Sans titre',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1976D2),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              quotation['description'] ?? 'Aucune description',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.euro, size: 16, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  'Budget client: ${quotation['budget'] ?? 'Non spécifié'} €',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Spacer(),
                Text(
                  'Client: ${quotation['client_name'] ?? 'Client anonyme'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showResponseDialog(quotation['id'], quotation['title']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFCC00),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Répondre'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _declineQuotation(quotation['id']),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Décliner'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showResponseDialog(String quotationId, String? title) async {
    final TextEditingController _amountController = TextEditingController();
    final TextEditingController _notesController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Répondre à "$title"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Montant proposé (€)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes et détails',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => _submitResponse(quotationId, _amountController.text, _notesController.text),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitResponse(String quotationId, String amount, String notes) async {
    if (amount.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le montant est requis')),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token d\'accès non trouvé')),
        );
        return;
      }

      final responseData = {
        'amount': double.tryParse(amount) ?? 0,
        'notes': notes,
        'status': 'quoted',
      };

      final response = await _proClientService.updateQuotation(
        accessToken: token,
        quotationId: quotationId,
        quotationData: responseData,
      );

      if (response.statusCode == 200) {
        Navigator.pop(context); // Fermer le dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réponse envoyée avec succès !')),
        );
        _loadQuotations(); // Recharger la liste
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'envoi de la réponse')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  Future<void> _declineQuotation(String quotationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token d\'accès non trouvé')),
        );
        return;
      }

      final response = await _proClientService.cancelQuotation(
        accessToken: token,
        quotationId: quotationId,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devis décliné avec succès !')),
        );
        _loadQuotations(); // Recharger la liste
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du déclinaison du devis')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }
}
