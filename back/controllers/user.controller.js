const User = require('../models/User');
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
