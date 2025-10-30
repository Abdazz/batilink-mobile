import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/pro_client_service.dart';

class ProClientQuotationsScreen extends StatefulWidget {
  final String? token;
  final Map<String, dynamic>? userData;
  final Map<String, dynamic>? filters;

  const ProClientQuotationsScreen({
    Key? key,
    this.token,
    this.userData,
    this.filters,
  }) : super(key: key);

  @override
  State<ProClientQuotationsScreen> createState() => _ProClientQuotationsScreenState();
}

class _ProClientQuotationsScreenState extends State<ProClientQuotationsScreen> {
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
      // Récupérer les filtres passés en paramètres ou utiliser des valeurs par défaut
      final statusFilter = widget.filters?['status']?.toString() ?? 'pending,quoted,accepted';
      final userId = widget.filters?['user_id']?.toString();
      
      final response = await _proClientService.getQuotations(
        accessToken: _finalToken,
        context: 'client', // Mode client
        status: statusFilter,
        userId: userId,
      );

      if (response.statusCode == 200) {
        final data = await _proClientService.parseProClientProfileResponse(response);
        if (data != null && data['quotations'] != null) {
          setState(() {
            _quotations = data['quotations'] as List<dynamic>;
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
    // Déterminer le titre en fonction des filtres
    final bool isMyQuotations = widget.filters?['user_id'] != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                isMyQuotations ? 'Mes demandes' : 'Devis reçus',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            if (_isProClient) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 1),
                ),
                constraints: const BoxConstraints(maxWidth: 100),
                child: Text(
                  'PRO-CLIENT',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
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
                          Icon(Icons.inbox, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Aucun devis reçu',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  quotation['title'] ?? 'Sans titre',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(quotation['status']),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    quotation['status'] ?? 'En attente',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              quotation['description'] ?? 'Aucune description',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.euro, size: 16, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  '${quotation['amount'] ?? '0'} €',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const Spacer(),
                Text(
                  'Par: ${quotation['professional_name'] ?? 'Professionnel'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptQuotation(quotation['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Accepter'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectQuotation(quotation['id']),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Refuser'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _acceptQuotation(String quotationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token d\'accès non trouvé')),
        );
        return;
      }

      final response = await _proClientService.acceptQuotation(
        accessToken: token,
        quotationId: quotationId,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devis accepté avec succès !')),
        );
        _loadQuotations(); // Recharger la liste
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'acceptation du devis')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  Future<void> _rejectQuotation(String quotationId) async {
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
          const SnackBar(content: Text('Devis refusé avec succès !')),
        );
        _loadQuotations(); // Recharger la liste
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du refus du devis')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }
}
