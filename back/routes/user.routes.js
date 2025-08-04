const express = require('express');
const { 
  updateFcmToken, 
  updateProfile, 
  changePassword, 
  getUserAppointments, 
  deleteAccount, 
  uploadAvatar 
} = require('../controllers/user.controller');
const { authenticate, authorize } = require('../middleware/auth');

const router = express.Router();

// All routes are protected, only authenticated users can access them
router.put('/fcm-token', authenticate, updateFcmToken);
router.put('/profile', authenticate, updateProfile);
router.put('/change-password', authenticate, changePassword);
router.get('/appointments', authenticate, getUserAppointments);
router.delete('/account', authenticate, deleteAccount);
router.post('/upload-avatar', authenticate, uploadAvatar);

module.exports = router;
