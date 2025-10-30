import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class Document {
  final String id;
  final String name;
  final String url;
  final String type;
  final DateTime uploadedAt;

  Document({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    required this.uploadedAt,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'],
      name: json['name'],
      url: json['url'],
      type: json['type'],
      uploadedAt: DateTime.parse(json['uploaded_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'type': type,
      'uploaded_at': uploadedAt.toIso8601String(),
    };
  }
}

class DocumentsScreen extends StatefulWidget {
  final List<Document> initialDocuments;
  final Function(List<Document>) onSave;

  const DocumentsScreen({
    Key? key,
    required this.initialDocuments,
    required this.onSave,
  }) : super(key: key);

  @override
  _DocumentsScreenState createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late List<Document> _documents;
  final List<PlatformFile> _selectedDocuments = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _documents = List.from(widget.initialDocuments);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents professionnels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              widget.onSave(_documents);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: _isUploading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickDocuments,
        child: const Icon(Icons.upload_file),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Documents sélectionnés
          if (_selectedDocuments.isNotEmpty) ...[
            const Text(
              'Nouveaux documents à téléverser:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ..._selectedDocuments.asMap().entries.map((entry) {
              final index = entry.key;
              final doc = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(doc.name),
                  subtitle: Text('${(doc.size / 1024).toStringAsFixed(2)} KB'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeDocument(index),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _uploadDocuments,
              child: const Text('Téléverser les documents'),
            ),
            const Divider(height: 40),
          ],

          // Documents existants
          if (_documents.isNotEmpty) ...[
            const Text(
              'Documents existants:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ..._documents.map((doc) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: _getDocumentIcon(doc.type),
                title: Text(doc.name),
                subtitle: Text('Ajouté le ${_formatDate(doc.uploadedAt)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteDocument(doc.id),
                ),
                onTap: () {
                  // TODO: Afficher le document
                },
              ),
            )).toList(),
          ] else ...[
            const Center(
              child: Text('Aucun document pour le moment'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _getDocumentIcon(String type) {
    if (type.contains('pdf')) {
      return const Icon(Icons.picture_as_pdf, color: Colors.red);
    } else if (type.contains('image')) {
      return const Icon(Icons.image, color: Colors.blue);
    } else if (type.contains('word') || type.contains('document')) {
      return const Icon(Icons.description, color: Colors.blue);
    }
    return const Icon(Icons.insert_drive_file);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _pickDocuments() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          _selectedDocuments.addAll(result.files);
        });
      }
    } catch (e) {
      _showError('Erreur lors de la sélection des documents: $e');
    }
  }

  void _removeDocument(int index) {
    setState(() {
      _selectedDocuments.removeAt(index);
    });
  }

  Future<void> _uploadDocuments() async {
    if (_selectedDocuments.isEmpty) return;

    setState(() {
      _isUploading = true;
    });

    try {
      // TODO: Implémenter l'upload des documents vers le serveur
      // Pour chaque document dans _selectedDocuments, envoyer au serveur
      // et ajouter le résultat à _documents
      
      // Simulation d'upload réussi
      await Future.delayed(const Duration(seconds: 2));
      
      final newDocuments = _selectedDocuments.map((file) => Document(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: file.name,
        url: 'https://example.com/documents/${file.name}',
        type: file.extension ?? 'application/octet-stream',
        uploadedAt: DateTime.now(),
      )).toList();

      setState(() {
        _documents.addAll(newDocuments);
        _selectedDocuments.clear();
      });

      _showSuccess('Documents téléchargés avec succès');
    } catch (e) {
      _showError('Erreur lors du téléchargement des documents: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _deleteDocument(String documentId) async {
    try {
      // TODO: Implémenter la suppression côté serveur
      setState(() {
        _documents.removeWhere((doc) => doc.id == documentId);
      });
      _showSuccess('Document supprimé avec succès');
    } catch (e) {
      _showError('Erreur lors de la suppression du document: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}
