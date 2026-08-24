const {createHash} = require("node:crypto");

const sha256 = (value) => createHash("sha256").update(String(value)).digest("hex");

const residentOnboardingId = (communityId, phoneNumber) =>
  sha256(`${communityId}\n${phoneNumber}`);

const importRowId = (importJobId, rowNumber) =>
  `${importJobId}_${sha256(String(rowNumber)).slice(0, 40)}`;

module.exports = {sha256, residentOnboardingId, importRowId};
