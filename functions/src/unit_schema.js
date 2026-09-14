// Canonical identity is flats/{documentId}. All label fields are display references.
const {RegistrationError} = require('./register_resident');
const STRUCTURE_TYPES = ['apartment_building', 'villa_cluster', 'row_house_cluster', 'townhouse_cluster', 'mixed', 'other'];
const UNIT_TYPES = ['apartment', 'villa', 'row_house', 'duplex', 'townhouse', 'other'];
const clean = (value) => typeof value === 'string' ? value.trim() : '';
const normalizeLabel = (value) => clean(value).normalize('NFKC').toLocaleLowerCase('en').replace(/\s+/g, ' ');
const structureType = (data) => data?.structureType == null ? 'apartment_building' : data.structureType;
const unitType = (data) => data?.unitType == null ? 'apartment' : data.unitType;
const defaultUnitType = (type) => ({apartment_building: 'apartment', villa_cluster: 'villa', row_house_cluster: 'row_house', townhouse_cluster: 'townhouse'}[type] || 'other');
const unitLabel = (data) => clean(data?.flatLabel) || clean(data?.flatId) || clean(data?.unitId);
// Fallback aliases are used only when the preferred visible label is absent.
const unitMatchesLabel = (data, value) => normalizeLabel(unitLabel(data)) === normalizeLabel(value);
const hasValue = (value) => value != null && (typeof value !== 'string' || value.trim() !== '');
const hasResidentLink = (data) => ['residentUserId', 'residentId', 'residentUid'].some((field) => hasValue(data[field])) ||
  (data.residentIds != null && (!Array.isArray(data.residentIds) || data.residentIds.length > 0));
function assertSafelyVacant(data) {
  if (data?.status !== 'vacant' || hasResidentLink(data) || hasValue(data.reservedOnboardingId) || data.isActive === false) {
    throw new RegistrationError('failed-precondition', `Unit ${unitLabel(data)} is ${data?.status === 'reserved' ? 'reserved' : data?.status === 'occupied' ? 'already occupied' : 'not safely vacant'}.`);
  }
}
function occupancyStats(documents, overrides = new Map()) {
  const stats = {totalFlats: documents.length, occupied: 0, reserved: 0, vacant: 0, maintenance: 0};
  for (const doc of documents) {
    const status = overrides.get(doc.id) || doc.data().status;
    stats[['occupied', 'reserved', 'vacant', 'maintenance'].includes(status) ? status : 'maintenance']++;
  }
  stats.occupancyRate = stats.totalFlats ? Math.round(stats.occupied / stats.totalFlats * 100) : 0;
  return stats;
}
module.exports = {STRUCTURE_TYPES, UNIT_TYPES, structureType, unitType, defaultUnitType, normalizeLabel,
  unitLabel, unitMatchesLabel, hasResidentLink, hasValue, assertSafelyVacant, occupancyStats};
