import 'dart:io';

/// Modèle représentant un document à uploader vers Cloudinary
class Document {
  final String id;
  final String type;
  final String name;
  final String? description;
  final File file;
  final DateTime createdAt;
  final bool isRequired;
  final String? cloudinaryId;
  final String? url;
  final int? size;
  final String? mimeType;

  Document({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    required this.file,
    required this.createdAt,
    this.isRequired = false,
    this.cloudinaryId,
    this.url,
    this.size,
    this.mimeType,
  });

  /// Crée un document à partir d'un fichier local
  factory Document.fromFile({
    required File file,
    required String type,
    required String name,
    String? description,
    bool isRequired = false,
  }) {
    return Document(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      name: name,
      description: description,
      file: file,
      createdAt: DateTime.now(),
      isRequired: isRequired,
    );
  }

  /// Crée un document à partir d'une réponse Cloudinary
  factory Document.fromCloudinaryResponse(Map<String, dynamic> response, String type, bool isRequired) {
    return Document(
      id: response['cloudinaryId'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      name: response['originalName'] ?? 'Document',
      file: File(response['path'] ?? ''),
      createdAt: response['uploadedAt'] != null 
          ? DateTime.parse(response['uploadedAt']) 
          : DateTime.now(),
      cloudinaryId: response['cloudinaryId'],
      url: response['url'],
      size: response['size'],
      mimeType: response['mimetype'],
      isRequired: isRequired,
    );
  }

  /// Convertit le document en Map pour l'API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'isRequired': isRequired,
      'cloudinaryId': cloudinaryId,
      'url': url,
      'size': size,
      'mimeType': mimeType,
    };
  }

  /// Vérifie si le document a été uploadé avec succès
  bool get isUploaded => cloudinaryId != null && url != null;

  /// Obtient l'extension du fichier
  String get extension => file.path.split('.').last.toLowerCase();

  /// Obtient le nom du fichier sans le chemin
  String get fileName => file.path.split('/').last;

  /// Obtient la taille du fichier en format lisible
  String get readableSize {
    if (size == null) return 'Inconnu';
    
    final kb = size! / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    } else {
      final mb = kb / 1024;
      return '${mb.toStringAsFixed(1)} MB';
    }
  }
}

/// Gestionnaire de collection de documents
class DocumentCollection {
  final Map<String, List<Document>> _documents = {};

  /// Ajoute un document à la collection
  void addDocument(Document document) {
    if (!_documents.containsKey(document.type)) {
      _documents[document.type] = [];
    }
    _documents[document.type]!.add(document);
  }

  /// Supprime un document de la collection
  void removeDocument(String id) {
    _documents.forEach((type, docs) {
      _documents[type] = docs.where((doc) => doc.id != id).toList();
    });
  }

  /// Obtient tous les documents d'un type spécifique
  List<Document> getDocumentsByType(String type) {
    return _documents[type] ?? [];
  }

  /// Obtient tous les documents
  List<Document> getAllDocuments() {
    final allDocs = <Document>[];
    _documents.forEach((_, docs) => allDocs.addAll(docs));
    return allDocs;
  }

  /// Obtient tous les documents requis
  List<Document> getRequiredDocuments() {
    return getAllDocuments().where((doc) => doc.isRequired).toList();
  }

  /// Vérifie si tous les documents requis sont présents
  bool get hasAllRequiredDocuments {
    final requiredTypes = ['license', 'diploma'];
    for (final type in requiredTypes) {
      final docs = getDocumentsByType(type);
      if (docs.isEmpty) return false;
    }
    return true;
  }

  /// Convertit la collection en Map pour l'API
  Map<String, List<File>> toFileMap() {
    final result = <String, List<File>>{};
    _documents.forEach((type, docs) {
      result[type] = docs.map((doc) => doc.file).toList();
    });
    return result;
  }

  /// Obtient le nombre total de documents
  int get count => getAllDocuments().length;

  /// Obtient la taille totale des documents
  int get totalSize => getAllDocuments()
      .map((doc) => doc.size ?? 0)
      .fold(0, (prev, size) => prev + size);

  /// Vérifie si la collection contient un document
  bool containsDocument(String id) {
    return getAllDocuments().any((doc) => doc.id == id);
  }

  /// Vérifie si la collection est vide
  bool get isEmpty => getAllDocuments().isEmpty;

  /// Vérifie si la collection n'est pas vide
  bool get isNotEmpty => !isEmpty;

  /// Efface tous les documents
  void clear() {
    _documents.clear();
  }
}
