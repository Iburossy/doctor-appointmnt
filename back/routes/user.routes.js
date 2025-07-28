const express = require('express');
const { updateFcmToken } = require('../controllers/user.controller');
const { authenticate, authorize } = require('../middleware/auth');

const router = express.Router();

// This route is protected, only authenticated users can access it.
router.put('/fcm-token', authenticate, updateFcmToken);

module.exports = router;
