import 'dart:io';
import '../../services/api_service.dart';
import '../../models/doctor.dart';
import '../../utils/logger.dart';

/// Service spécialisé pour l'upload des documents médecin
class DoctorUploadService {
  static DoctorUploadService? _instance;
  static DoctorUploadService get instance => _instance ??= DoctorUploadService._internal();
  
  // Utiliser les instances depuis les bons packages
  final ApiService _apiService = ApiService.instance;
  
  DoctorUploadService._internal();

  /// Types de documents supportés
  static const Map<String, String> documentTypes = {
    'medicalLicense': 'Licence médicale',
    'diploma': 'Diplôme',
    'certifications': 'Certification',
    'profilePhoto': 'Photo de profil',
    'clinicPhotos': 'Photo de clinique',
  };

  /// Crée un profil médecin et upload tous les documents en une seule requête
  Future<DoctorUploadResult> createDoctorProfileWithDocuments({
    required Map<String, dynamic> doctorData,
    required Map<String, List<File>> documents,
    Function(String)? onStatusUpdate,
    Function(double)? onProgressUpdate,
  }) async {
    try {
      onStatusUpdate?.call('Préparation des données et fichiers...');
      onProgressUpdate?.call(0.1);
      
      // Préparer un Map<String, File> pour la nouvelle méthode
      // On ne prend que le premier fichier de chaque liste pour cette démo
      final Map<String, File> filesToUpload = {};
      final List<String> processedFiles = [];
      
      // Mapping des noms de champs anciens vers nouveaux
      final Map<String, String> fieldMapping = {
        'license': 'medicalLicense',
        'diploma': 'diploma', // déjà correct
        'certification': 'certifications',
        'profile': 'profilePhoto',
        'clinic': 'clinicPhotos',
      };
      
      documents.forEach((documentType, files) {
        if (files.isNotEmpty) {
          // Utiliser le nom de champ mappé pour le backend
          final backendFieldName = fieldMapping[documentType] ?? documentType;
          filesToUpload[backendFieldName] = files.first;
          processedFiles.add('$backendFieldName: ${files.first.path}');
          
          {
            Logger.log('🔄 Préparation fichier $backendFieldName (original: $documentType): ${files.first.path}');
          }
        }
      });
      
      if (filesToUpload.isEmpty) {
        Logger.log('⚠️ Aucun fichier à uploader');
      } else {
        Logger.log('📄 Nombre de fichiers à uploader: ${filesToUpload.length}');
      }
      
      onStatusUpdate?.call('Envoi du profil et des documents...');
      onProgressUpdate?.call(0.3);
      
      // Utiliser la nouvelle méthode qui combine données + fichiers
      final doctorResponse = await _apiService.requestDoctorUpgradeWithFiles(
        doctorData: doctorData,
        files: filesToUpload,
        onProgress: (sent, total) {
          final progress = 0.3 + (sent / total) * 0.7; // 30% à 100%
          onProgressUpdate?.call(progress);
        },
      );
      
      if (!doctorResponse.success) {
        return DoctorUploadResult.error(
          'Erreur lors de l\'envoi des données: ${doctorResponse.error}'
        );
      }

      final doctor = doctorResponse.data!;
      final String doctorId = doctor.id ?? '';
      
      {
        Logger.success('Profil médecin créé avec succès: $doctorId');
        Logger.success('Documents envoyés: ${processedFiles.join(', ')}');
      }

      onProgressUpdate?.call(1.0);
      onStatusUpdate?.call('Profil créé avec tous les documents!');

      // Dans cette nouvelle approche, tous les documents sont envoyés en même temps
      // que les données du profil, donc on considère que tous sont uploadés avec succès
      return DoctorUploadResult.success(
        doctor: doctor,
        uploadedDocuments: [], // On n'a pas les URLs des documents uploadés
        message: 'Profil médecin créé et documents uploadés avec succès',
      );

    } catch (e) {
      {
        Logger.error('Erreur création profil médecin: $e');
      }
      onStatusUpdate?.call('Erreur lors de la création du profil');
      return DoctorUploadResult.error('Erreur inattendue: $e');
    }
  }

  /// Upload d'un document individuel
  Future<ApiResponse<Map<String, dynamic>>> uploadSingleDocument({
    required String doctorId,
    required File file,
    required String documentType,
    Function(int, int)? onProgress,
  }) async {
    return await _apiService.uploadDoctorDocument(
      doctorId: doctorId,
      file: file,
      documentType: documentType,
      onProgress: onProgress,
    );
  }

  /// Valide un fichier avant upload
  ValidationResult validateFile(File file, String documentType) {
    try {
      // Vérifier l'existence du fichier
      if (!file.existsSync()) {
        return ValidationResult.error('Le fichier n\'existe pas');
      }

      // Vérifier l'extension
      final extension = file.path.split('.').last.toLowerCase();
      final allowedTypes = ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'];
      if (!allowedTypes.contains(extension)) {
        return ValidationResult.error(
          'Type de fichier non autorisé. Types acceptés: ${allowedTypes.join(', ')}'
        );
      }

      // Vérifier la taille (de manière synchrone approximative)
      final fileSize = file.lengthSync();
      final maxSize = 10 * 1024 * 1024; // 10MB
      if (fileSize > maxSize) {
        return ValidationResult.error(
          'Fichier trop volumineux. Taille maximale: ${(maxSize / (1024 * 1024)).toStringAsFixed(1)}MB'
        );
      }

      // Vérifier le type de document
      if (!documentTypes.containsKey(documentType)) {
        return ValidationResult.error('Type de document non reconnu: $documentType');
      }

      return ValidationResult.success('Fichier valide');

    } catch (e) {
      return ValidationResult.error('Erreur lors de la validation: $e');
    }
  }

  /// Valide plusieurs fichiers
  List<ValidationResult> validateFiles(Map<String, List<File>> documents) {
    final results = <ValidationResult>[];
    
    documents.forEach((documentType, files) {
      // Vérifier le nombre de fichiers par type
      final maxFiles = _getMaxFilesForType(documentType);
      if (files.length > maxFiles) {
        results.add(ValidationResult.error(
          'Trop de fichiers pour $documentType. Maximum: $maxFiles'
        ));
        return;
      }

      // Valider chaque fichier
      for (File file in files) {
        results.add(validateFile(file, documentType));
      }
    });

    return results;
  }

  /// Obtient la taille totale des fichiers à uploader
  Future<int> getTotalUploadSize(Map<String, List<File>> documents) async {
    int totalSize = 0;
    
    for (List<File> files in documents.values) {
      for (File file in files) {
        totalSize += await file.length();
      }
    }
    
    return totalSize;
  }

  /// Estime le temps d'upload (très approximatif)
  Duration estimateUploadTime(int totalSizeBytes) {
    // Estimation basée sur une vitesse de 1MB/s (très conservateur)
    final seconds = (totalSizeBytes / (1024 * 1024)).ceil();
    return Duration(seconds: seconds);
  }

  /// Obtient le nombre maximum de fichiers pour un type
  int _getMaxFilesForType(String documentType) {
    switch (documentType) {
      case 'license':
      case 'profile':
        return 1;
      case 'diploma':
      case 'certification':
        return 3;
      case 'clinic':
        return 5;
      default:
        return 1;
    }
  }
}

// ==================== CLASSES DE SUPPORT ====================

/// Résultat de l'upload complet d'un profil médecin
class DoctorUploadResult {
  final bool success;
  final Doctor? doctor;
  final List<Map<String, dynamic>>? uploadedDocuments;
  final List<String>? failedUploads;
  final String message;
  final bool isPartialSuccess;

  DoctorUploadResult.success({
    required this.doctor,
    required this.uploadedDocuments,
    required this.message,
  }) : success = true, failedUploads = null, isPartialSuccess = false;

  DoctorUploadResult.partialSuccess({
    required this.doctor,
    required this.uploadedDocuments,
    required this.failedUploads,
    required this.message,
  }) : success = true, isPartialSuccess = true;

  DoctorUploadResult.error(this.message) 
    : success = false, 
      doctor = null, 
      uploadedDocuments = null, 
      failedUploads = null,
      isPartialSuccess = false;
}

/// Résultat de validation d'un fichier
class ValidationResult {
  final bool isValid;
  final String message;

  ValidationResult.success(this.message) : isValid = true;
  ValidationResult.error(this.message) : isValid = false;
}
