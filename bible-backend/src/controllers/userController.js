const asyncHandler = require("../utils/asyncHandler");
const multer = require("multer");
const { authService } = require("../services/authService");
const { userRepository } = require("../repositories/userRepository");
const AppError = require("../utils/AppError");

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 2 * 1024 * 1024 }, // 2MB
  fileFilter: (req, file, cb) => {
    if (!file.mimetype.startsWith("image/")) {
      return cb(new AppError(400, "Only image files allowed"));
    }
    cb(null, true);
  },
});

const getCurrentUser = asyncHandler(async (req, res) => {
  const user = await authService.getCurrentUser(req.user.id || req.user._id);

  res.status(200).json({
    success: true,
    data: user,
  });
});

const updateUser = asyncHandler(async (req, res) => {
  const { name, preferences } = req.body;
  const updated = await userRepository.updateProfile(req.user.id || req.user._id, { name, preferences });

  res.status(200).json({
    success: true,
    data: updated,
  });
});

const uploadPhoto = [
  upload.single("photo"),
  asyncHandler(async (req, res) => {
    if (!req.file) throw new AppError(400, "No image file provided");
    const dataUrl = `data:${req.file.mimetype};base64,${req.file.buffer.toString("base64")}`;
    const updated = await userRepository.updatePhoto(req.user.id || req.user._id, dataUrl);
    res.status(200).json({ success: true, data: updated });
  }),
];

module.exports = {
  getCurrentUser,
  updateUser,
  uploadPhoto,
};
