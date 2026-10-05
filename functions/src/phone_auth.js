function hasVerifiedPhoneAuth(auth) {
  const uid = typeof auth?.uid === "string" ? auth.uid.trim() : "";
  const phoneNumber = typeof auth?.token?.phone_number === "string" ?
    auth.token.phone_number.trim() : "";
  return uid.length > 0 && phoneNumber.length > 0 &&
    auth?.token?.firebase?.sign_in_provider === "phone";
}

async function hasCanonicalPhoneProfile(db, auth) {
  if (!hasVerifiedPhoneAuth(auth)) return false;
  const collections = ["admins", "users", "securityStaff"];
  const snapshots = await Promise.all(collections.map((collection) =>
    db.collection(collection).doc(auth.uid).get(),
  ));
  const profiles = snapshots.flatMap((snapshot, index) => {
    if (!snapshot.exists) return [];
    return [{collection: collections[index], profile: snapshot.data()}];
  });
  if (profiles.length === 0) return false;

  return profiles.every(({collection, profile}) => {
    const expectedRole = {
      admins: new Set(["admin", "superAdmin"]),
      users: new Set(["resident"]),
      securityStaff: new Set(["security"]),
    }[collection];
    return profile?.uid === auth.uid &&
      typeof profile.phoneNumber === "string" &&
      profile.phoneNumber === auth.token.phone_number &&
      expectedRole.has(profile.role);
  });
}

module.exports = {hasVerifiedPhoneAuth, hasCanonicalPhoneProfile};
