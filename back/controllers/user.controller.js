const User = require('../models/User');
const bcrypt = require('bcryptjs');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const asyncHandler = require('../middleware/asyncHandler');

// @desc    Update FCM token
// @route   PUT /api/users/fcm-token
// @access  Private
exports.updateFcmToken = asyncHandler(async (req, res, next) => {
  const { fcmToken } = req.body;

  if (!fcmToken) {
    return res.status(400).json({ success: false, message: 'FCM token is required' });
  }

  const user = await User.findById(req.user.id);

  if (!user) {
    return res.status(404).json({ success: false, message: 'User not found' });
  }

  // Add the new token if it doesn't already exist
  if (!user.fcmTokens.includes(fcmToken)) {
    user.fcmTokens.push(fcmToken);
    await user.save();
  }

  res.status(200).json({ success: true, data: user.fcmTokens });
});

// @desc    Update user profile
// @route   PUT /api/users/profile
// @access  Private
exports.updateProfile = asyncHandler(async (req, res, next) => {
  console.log('🔍 UPDATE PROFILE - Données reçues:', JSON.stringify(req.body, null, 2));
  
  const { firstName, lastName, email, phone, dateOfBirth, gender, address, city } = req.body;
  
  console.log('🔍 UPDATE PROFILE - Champs extraits:', {
    firstName, lastName, email, phone, dateOfBirth, gender, address, city
  });

  const user = await User.findById(req.user.id);
  console.log('🔍 UPDATE PROFILE - Utilisateur trouvé:', user ? 'Oui' : 'Non');

  if (!user) {
    return res.status(404).json({ success: false, message: 'User not found' });
  }

  // Update fields if provided
  if (firstName !== undefined) user.firstName = firstName;
  if (lastName !== undefined) user.lastName = lastName;
  if (email !== undefined) user.email = email;
  if (phone !== undefined) user.phone = phone;
  if (dateOfBirth !== undefined) user.dateOfBirth = dateOfBirth;
  if (gender !== undefined) user.gender = gender;
  
  // Handle address object structure
  if (address !== undefined) {
    console.log('🔍 UPDATE PROFILE - Mise à jour de l\'adresse:', address);
    if (typeof address === 'object' && address !== null) {
      // If address is an object with street and city
      if (!user.address) user.address = {};
      if (address.street !== undefined) user.address.street = address.street;
      if (address.city !== undefined) user.address.city = address.city;
      // Also update the city field for backward compatibility
      if (address.city !== undefined) user.city = address.city;
    } else {
      // If address is a string (backward compatibility)
      user.address = address;
    }
  }
  if (city !== undefined) {
    user.city = city;
    // Also update address.city if address object exists
    if (!user.address) user.address = {};
    user.address.city = city;
  }
  
  console.log('🔍 UPDATE PROFILE - Utilisateur avant sauvegarde:', {
    firstName: user.firstName,
    lastName: user.lastName,
    email: user.email,
    phone: user.phone,
    dateOfBirth: user.dateOfBirth,
    gender: user.gender,
    address: user.address,
    city: user.city
  });

  const updatedUser = await user.save();

  res.status(200).json({
    success: true,
    data: {
      id: updatedUser._id,
      firstName: updatedUser.firstName,
      lastName: updatedUser.lastName,
      email: updatedUser.email,
      phone: updatedUser.phone,
      role: updatedUser.role,
      dateOfBirth: updatedUser.dateOfBirth,
      gender: updatedUser.gender,
      address: updatedUser.address,
      city: updatedUser.city,
      profilePicture: updatedUser.profilePicture
    }
  });
});

// @desc    Change user password
// @route   PUT /api/users/change-password
// @access  Private
exports.changePassword = asyncHandler(async (req, res, next) => {
  const { currentPassword, newPassword } = req.body;

  if (!currentPassword || !newPassword) {
    return res.status(400).json({ 
      success: false, 
      message: 'Current password and new password are required' 
    });
  }

  const user = await User.findById(req.user.id).select('+password');

  if (!user) {
    return res.status(404).json({ success: false, message: 'User not found' });
  }

  // Check current password
  const isCurrentPasswordCorrect = await bcrypt.compare(currentPassword, user.password);
  if (!isCurrentPasswordCorrect) {
    return res.status(400).json({ 
      success: false, 
      message: 'Current password is incorrect' 
    });
  }

  // Hash new password
  const salt = await bcrypt.genSalt(10);
  user.password = await bcrypt.hash(newPassword, salt);

  await user.save();

  res.status(200).json({
    success: true,
    message: 'Password updated successfully'
  });
});

// @desc    Get user appointments
// @route   GET /api/users/appointments
// @access  Private
exports.getUserAppointments = asyncHandler(async (req, res, next) => {
  const Appointment = require('../models/Appointment');
  
  const appointments = await Appointment.find({ patient: req.user.id })
    .populate('doctor', 'firstName lastName specialization')
    .sort({ appointmentDate: -1 });

  res.status(200).json({
    success: true,
    data: appointments
  });
});

// @desc    Delete user account
// @route   DELETE /api/users/account
// @access  Private
exports.deleteAccount = asyncHandler(async (req, res, next) => {
  const user = await User.findById(req.user.id);

  if (!user) {
    return res.status(404).json({ success: false, message: 'User not found' });
  }

  // Delete user's profile picture if it exists
  if (user.profilePicture) {
    const imagePath = path.join(__dirname, '..', 'uploads', 'avatars', user.profilePicture);
    if (fs.existsSync(imagePath)) {
      fs.unlinkSync(imagePath);
    }
  }

  await User.findByIdAndDelete(req.user.id);

  res.status(200).json({
    success: true,
    message: 'Account deleted successfully'
  });
});

// Configuration multer pour l'upload d'avatar
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadPath = path.join(__dirname, '..', 'uploads', 'avatars');
    if (!fs.existsSync(uploadPath)) {
      fs.mkdirSync(uploadPath, { recursive: true });
    }
    cb(null, uploadPath);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'avatar-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB limit
  },
  fileFilter: function (req, file, cb) {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'), false);
    }
  }
});

// @desc    Upload user avatar
// @route   POST /api/users/upload-avatar
// @access  Private
exports.uploadAvatar = [upload.single('avatar'), asyncHandler(async (req, res, next) => {
  console.log('🖼️ UPLOAD AVATAR - Début de l\'upload');
  console.log('🖼️ UPLOAD AVATAR - Fichier reçu:', req.file ? 'Oui' : 'Non');
  if (req.file) {
    console.log('🖼️ UPLOAD AVATAR - Détails du fichier:', {
      filename: req.file.filename,
      originalname: req.file.originalname,
      mimetype: req.file.mimetype,
      size: req.file.size
    });
  }
  
  if (!req.file) {
    return res.status(400).json({ success: false, message: 'No file uploaded' });
  }

  const user = await User.findById(req.user.id);
  console.log('🖼️ UPLOAD AVATAR - Utilisateur trouvé:', user ? 'Oui' : 'Non');

  if (!user) {
    return res.status(404).json({ success: false, message: 'User not found' });
  }

  // Delete old avatar if it exists
  if (user.profilePicture) {
    const oldImagePath = path.join(__dirname, '..', 'uploads', 'avatars', user.profilePicture);
    if (fs.existsSync(oldImagePath)) {
      fs.unlinkSync(oldImagePath);
    }
  }

  // Update user with new avatar filename
  user.profilePicture = req.file.filename;
  await user.save();

  res.status(200).json({
    success: true,
    data: {
      profilePicture: user.profilePicture,
      url: `/uploads/avatars/${user.profilePicture}`
    }
  });
})];
