import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/pro_client_portfolio.dart';
import '../../services/pro_client_portfolio_service.dart';
import '../../widgets/dialogs/pro_client_portfolio_dialog.dart';
import '../../core/app_config.dart';

class PortfolioManagementScreen extends StatefulWidget {
  final String token;
  final Function(List<ProClientPortfolio>)? onUpdate;

  const PortfolioManagementScreen({
    Key? key,
    required this.token,
    this.onUpdate,
  }) : super(key: key);

  @override
  _PortfolioManagementScreenState createState() => _PortfolioManagementScreenState();
}

class _PortfolioManagementScreenState extends State<PortfolioManagementScreen> {
  late List<ProClientPortfolio> _portfolios;
  late final ProClientPortfolioService _portfolioService;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _portfolios = [];
    _portfolioService = ProClientPortfolioService();
    _fetchPortfolios();
  }

  Future<void> _fetchPortfolios() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      final portfolios = await _portfolioService.getPortfolios(token: widget.token);
      if (mounted) {
        setState(() {
          _portfolios = portfolios;
          _isLoading = false;
        });
        widget.onUpdate?.call(_portfolios);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur lors du chargement du portfolio : ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddPortfolioDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ProClientPortfolioDialog(token: widget.token),
    );

    if (result == true) {
      _fetchPortfolios();
    }
  }

  void _editPortfolio(ProClientPortfolio portfolio) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ProClientPortfolioDialog(
        portfolio: portfolio,
        token: widget.token,
      ),
    );

    if (result == true) {
      _fetchPortfolios();
    }
  }

  Future<void> _deletePortfolio(String portfolioId) async {
    try {
      await _portfolioService.deletePortfolio(
        token: widget.token,
        portfolioId: portfolioId,
      );
      _fetchPortfolios();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Portfolio supprimé avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression : ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFCC00),
        elevation: 0,
        title: Text(
          'Gestion du Portfolio',
          style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black87),
            onPressed: _showAddPortfolioDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPortfolios,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: GoogleFonts.poppins(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchPortfolios,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFCC00)),
                        child: Text('Réessayer', style: GoogleFonts.poppins()),
                      ),
                    ],
                  )
                : _portfolios.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('Aucun portfolio créé', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text('Commencez par ajouter vos réalisations', style: GoogleFonts.poppins(fontSize: 14)),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _showAddPortfolioDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Créer votre premier portfolio'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFCC00)),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _portfolios.length,
                        itemBuilder: (context, index) {
                          final p = _portfolios[index];
                          return _buildPortfolioCard(p);
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPortfolioDialog,
        backgroundColor: const Color(0xFFFFCC00),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPortfolioCard(ProClientPortfolio portfolio) {
    final String? imageUrl = (portfolio.imagePath != null && portfolio.imagePath!.isNotEmpty)
        ? (portfolio.imagePath!.startsWith('http') ? portfolio.imagePath : '${AppConfig.baseUrl}/storage/${portfolio.imagePath}')
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Container(
            height: 180,
            width: double.infinity,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              color: Colors.grey,
            ),
            child: imageUrl != null
                ? ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (context, error, st) {
                        debugPrint('Portfolio card image error: $error');
                        debugPrint('Tried URL: $imageUrl');
                        return const Icon(Icons.broken_image, size: 64, color: Colors.white);
                      },
                    ),
                  )
                : const Center(child: Icon(Icons.image, size: 64, color: Colors.white)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(portfolio.title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(portfolio.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 14)),
                const SizedBox(height: 12),
                Row(children: [
                  if (portfolio.projectDate != null) Text(_formatDate(portfolio.projectDate), style: GoogleFonts.poppins(fontSize: 12)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.edit), onPressed: () => _editPortfolio(portfolio)),
                  IconButton(icon: const Icon(Icons.delete), onPressed: () => _deletePortfolio(portfolio.id)),
                ])
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Date inconnue';
    return '${d.day}/${d.month}/${d.year}';
  }
}