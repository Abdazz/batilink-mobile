import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/document.dart';
import '../../services/document_service.dart';

class DocumentsScreen extends StatefulWidget {
  final List<Document> initialDocuments;
  final Function(List<Document>) onDocumentsUpdated;
  final String token;

  const DocumentsScreen({
    Key? key,
    required this.initialDocuments,
    required this.onDocumentsUpdated,
    required this.token,
  }) : super(key: key);

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late List<Document> _documents;
  final Map<String, PlatformFile> _selectedDocuments = {};
  bool _isLoading = false;
  late DocumentService _documentService;

  @override
  void initState() {
    super.initState();
    _documentService = DocumentService(widget.token);
    _initializeDocuments();
  }

  void _initializeDocuments() {
    _documents = List<Document>.from(widget.initialDocuments);
  }

  Future<void> _saveDocuments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final List<Document> updatedDocuments = [];
      final List<Document> deletedDocuments = [];

      for (var doc in _documents) {
        if (_selectedDocuments.containsKey(doc.type)) {
          try {
            final file = _selectedDocuments[doc.type]!;
            final uploadedDoc = await _documentService.uploadDocument(
              File(file.path!),
              doc.type,
              documentId: doc.id,
            );
            updatedDocuments.add(uploadedDoc);

            if (doc.filePath.isNotEmpty) {
              deletedDocuments.add(doc);
            }
          } catch (e) {
            _showError('Erreur lors du téléversement de ${doc.name}: $e');
          }
        } else if (doc.filePath.isNotEmpty) {
          updatedDocuments.add(doc);
        }
      }

      await _documentService.updateProfileDocuments(updatedDocuments, deletedDocuments);
      widget.onDocumentsUpdated(updatedDocuments);
      _showSuccess('Documents sauvegardés avec succès');
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError('Erreur lors de la sauvegarde: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDocument(String documentType) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedDocuments[documentType] = result.files.first;
        });
        await _uploadDocument(documentType);
      }
    } catch (e) {
      _showError('Erreur lors de la sélection du fichier: $e');
    }
  }

  Future<void> _uploadDocument(String documentType) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final file = _selectedDocuments[documentType]!;
      final filePath = file.path!;
      final fileSize = await File(filePath).length();
      const maxSize = 10 * 1024 * 1024; // 10MB

      if (fileSize > maxSize) {
        throw Exception('Le fichier est trop volumineux (max 10 Mo)');
      }

      final uploadedDoc = await _documentService.uploadDocument(
        File(filePath),
        documentType,
      );

      setState(() {
        _documents.removeWhere((doc) => doc.type == documentType);
        _documents.add(uploadedDoc);
        _selectedDocuments.remove(documentType);
      });

      widget.onDocumentsUpdated(_documents);
      _showSuccess('Document ajouté avec succès');

    } catch (e) {
      // Log and show a detailed error dialog so user can copy the server response
      debugPrint('Upload error: $e');
  final message = e.toString();
      // Show a short snack
      _showError('Erreur lors de l\'ajout du document: ${message.split('\n').first}');
      // And a dialog with the full message for debugging/copy
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Erreur lors du téléversement'),
            content: SingleChildScrollView(
              child: Text(message),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteDocument(String documentId) async {
    final docToDelete = _documents.firstWhere(
      (doc) => doc.id == documentId,
      orElse: () => Document(
        id: '',
        name: '',
        url: '',
        type: '',
        uploadedAt: DateTime.now(),
        filePath: '',
      ),
    );

    if (docToDelete.id.isEmpty) {
      _showError('Document non trouvé');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer ce document ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (docToDelete.filePath.isNotEmpty) {
          await _documentService.deleteDocument(docToDelete.filePath);
        }

        setState(() {
          _documents.removeWhere((doc) => doc.id == documentId);
        });

        widget.onDocumentsUpdated(_documents);
        _showSuccess('Document supprimé avec succès');
      } catch (e) {
        _showError('Erreur lors de la suppression: $e');
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          if (_selectedDocuments.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveDocuments,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _documents.length,
              itemBuilder: (context, index) {
                final doc = _documents[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Type: ${doc.type}'),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _pickDocument(doc.type),
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Mettre à jour'),
                            ),
                            if (doc.filePath.isNotEmpty)
                              TextButton.icon(
                                onPressed: () => _deleteDocument(doc.id),
                                icon: const Icon(Icons.delete),
                                label: const Text('Supprimer'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}