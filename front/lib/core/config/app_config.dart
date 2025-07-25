class AppConfig {
  // App Information
  static const String appName = 'Doctors App';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Application de prise de rendez-vous médical - Sénégal';
  
  // API Configuration
  static const String baseUrl = 'http://10.0.2.2:5000/api'; // Spécial IP pour accéder à localhost depuis l'émulateur Android
  static const String apiVersion = 'v1';
  
  // Endpoints
  static const String authEndpoint = '/auth';
  static const String usersEndpoint = '/users';
  static const String doctorsEndpoint = '/doctors';
  static const String appointmentsEndpoint = '/appointments';
  static const String adminEndpoint = '/admin';
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String languageKey = 'app_language';
  static const String themeKey = 'app_theme';
  static const String locationKey = 'user_location';
  
  // Default Values
  static const String defaultLanguage = 'fr';
  static const String defaultCountryCode = '+221';
  static const String defaultCurrency = 'XOF';
  static const String defaultCountry = 'Sénégal';
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;
  
  // Timeouts
  static const int connectionTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds
  
  // SMS & Phone
  static const int otpLength = 6;
  static const int otpExpiryMinutes = 10;
  static const String phoneRegex = r'^[0-9]{8,9}$'; // Accept phone without +221 prefix
  
  // Maps & Location
  static const double defaultLatitude = 14.6937; // Dakar
  static const double defaultLongitude = -17.4441; // Dakar
  static const double defaultZoom = 12.0;
  static const double searchRadius = 10.0; // km
  
  // Appointment
  static const int appointmentDuration = 30; // minutes
  static const int cancellationHours = 2; // hours before appointment
  static const int reminderHours = 24; // hours before appointment
  
  // File Upload
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png'];
  static const List<String> allowedDocTypes = ['pdf', 'doc', 'docx'];
  
  // UI Constants
  static const double borderRadius = 12.0;
  static const double cardElevation = 2.0;
  static const double buttonHeight = 48.0;
  static const double inputHeight = 56.0;
  
  // Colors (Hex values)
  static const String primaryColor = '#2E7D32'; // Green medical
  static const String secondaryColor = '#FFC107'; // Amber
  static const String errorColor = '#D32F2F'; // Red
  static const String successColor = '#388E3C'; // Green
  static const String warningColor = '#F57C00'; // Orange
  
  // Senegal Specific
  static const List<String> supportedLanguages = ['fr', 'wo', 'ar'];
  static const List<String> senegalRegions = [
    'Dakar',
    'Thiès',
    'Saint-Louis',
    'Diourbel',
    'Louga',
    'Fatick',
    'Kaolack',
    'Kolda',
    'Ziguinchor',
    'Tambacounda',
    'Kaffrine',
    'Kédougou',
    'Matam',
    'Sédhiou'
  ];
  
  // Medical Specialties
  static const List<String> medicalSpecialties = [
    'Médecine générale',
    'Cardiologie',
    'Pédiatrie',
    'Gynécologie',
    'Dermatologie',
    'Ophtalmologie',
    'ORL',
    'Orthopédie',
    'Neurologie',
    'Psychiatrie',
    'Radiologie',
    'Anesthésie',
    'Chirurgie générale',
    'Urologie',
    'Pneumologie',
    'Gastro-entérologie',
    'Endocrinologie',
    'Rhumatologie',
    'Néphrologie',
    'Oncologie'
  ];
  
  // Working Hours
  static const List<String> workingHours = [
    '08:00', '08:30', '09:00', '09:30', '10:00', '10:30',
    '11:00', '11:30', '12:00', '12:30', '13:00', '13:30',
    '14:00', '14:30', '15:00', '15:30', '16:00', '16:30',
    '17:00', '17:30', '18:00', '18:30', '19:00', '19:30'
  ];
  
  // Environment Check
  static bool get isDebug {
    bool inDebugMode = false;
    assert(inDebugMode = true);
    return inDebugMode;
  }
  
  static bool get isProduction => !isDebug;
  
  // Get full API URL
  static String getApiUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }
  
  // Validate Senegal phone number
  static bool isValidSenegalPhone(String phone) {
    return RegExp(phoneRegex).hasMatch(phone);
  }
  
  // Format phone number for Senegal
  static String formatSenegalPhone(String phone) {
    // Remove all non-digits
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    
    // If starts with 221, add +
    if (cleaned.startsWith('221')) {
      return '+$cleaned';
    }
    
    // If starts with 7 or 3 (Senegal mobile), add +221
    if (cleaned.startsWith('7') || cleaned.startsWith('3')) {
      return '+221$cleaned';
    }
    
    return phone; // Return as is if format not recognized
  }
}
