const LoginAttempt = require("../models/LoginAttempt");

const createLoginAttemptRepository = ({ model = LoginAttempt } = {}) => ({
  async create(payload) {
    return model.create(payload);
  },
});

module.exports = {
  createLoginAttemptRepository,
  loginAttemptRepository: createLoginAttemptRepository(),
};
