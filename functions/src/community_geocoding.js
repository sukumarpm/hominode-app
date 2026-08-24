const {RegistrationError} = require("./register_resident");
const {requireLocationSearchAdmin} = require("./community_location_management");

async function communityLocationSearchCore({db, auth, data, apiKey, fetchImpl = fetch}) {
  await requireLocationSearchAdmin(db, auth);
  const query = String(data?.query ?? "").trim();
  if (query.length < 3 || query.length > 250) {
    throw new RegistrationError("invalid-argument", "Enter at least 3 characters to search.");
  }
  const sessionToken = validateSessionToken(data?.sessionToken);
  const countryCode = validateCountryCode(data?.countryCode);
  if (!apiKey) throw new Error("GOOGLE_GEOCODING_API_KEY is not configured");
  const body = {input: query, sessionToken};
  if (countryCode) body.includedRegionCodes = [countryCode.toLowerCase()];
  const response = await fetchImpl(
    "https://places.googleapis.com/v1/places:autocomplete",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": apiKey,
      },
      body: JSON.stringify(body),
    },
  );
  if (!response.ok) throw new Error(`Places autocomplete failed: ${response.status}`);
  const payload = await response.json();
  if (payload.status === "ZERO_RESULTS") return {suggestions: []};
  return {
    suggestions: (payload.suggestions || [])
      .map((suggestion) => suggestion?.placePrediction)
      .filter((prediction) =>
        typeof prediction?.placeId === "string" &&
        typeof prediction?.text?.text === "string"
      )
      .slice(0, 5)
      .map((prediction) => ({
        placeId: prediction.placeId,
        primaryText: prediction.structuredFormat?.mainText?.text || prediction.text.text,
        secondaryText: prediction.structuredFormat?.secondaryText?.text || "",
        displayText: prediction.text.text,
      })),
  };
}

function validateSessionToken(value) {
  const token = typeof value === "string" ? value.trim() : "";
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(token)) {
    throw new RegistrationError("invalid-argument", "A valid autocomplete session token is required.");
  }
  return token;
}

function validateCountryCode(value) {
  if (value == null || value === "") return null;
  const code = typeof value === "string" ? value.trim().toUpperCase() : "";
  if (!/^[A-Z]{2}$/.test(code)) {
    throw new RegistrationError("invalid-argument", "countryCode must be a two-letter code.");
  }
  return code;
}

function validatePlaceId(value) {
  const placeId = typeof value === "string" ? value.trim() : "";
  if (!/^[A-Za-z0-9._:-]{3,500}$/.test(placeId)) {
    throw new RegistrationError("invalid-argument", "A valid placeId is required.");
  }
  return placeId;
}

async function resolveCommunityLocationPlaceCore({db, auth, data, apiKey, fetchImpl = fetch}) {
  await requireLocationSearchAdmin(db, auth);
  const placeId = validatePlaceId(data?.placeId);
  const sessionToken = validateSessionToken(data?.sessionToken);
  if (!apiKey) throw new Error("GOOGLE_GEOCODING_API_KEY is not configured");
  const url = new URL(`https://places.googleapis.com/v1/places/${encodeURIComponent(placeId)}`);
  url.searchParams.set("sessionToken", sessionToken);
  const response = await fetchImpl(url, {
    headers: {
      "X-Goog-Api-Key": apiKey,
      "X-Goog-FieldMask": "id,displayName,formattedAddress,location",
    },
  });
  if (!response.ok) throw new Error(`Place Details failed: ${response.status}`);
  const place = await response.json();
  const latitude = place?.location?.latitude;
  const longitude = place?.location?.longitude;
  const formattedAddress = typeof place?.formattedAddress === "string" ? place.formattedAddress.trim() : "";
  if (typeof latitude !== "number" || !Number.isFinite(latitude) || latitude < -90 || latitude > 90 ||
      typeof longitude !== "number" || !Number.isFinite(longitude) || longitude < -180 || longitude > 180 ||
      !formattedAddress) {
    throw new Error("Place Details returned an invalid location");
  }
  return {result: {
    placeId: typeof place.id === "string" && place.id ? place.id : placeId,
    formattedAddress,
    latitude,
    longitude,
    displayName: typeof place?.displayName?.text === "string" ? place.displayName.text : null,
  }};
}

function validateReverseGeocodeInput(data) {
  const allowedKeys = new Set(["latitude", "longitude"]);
  if (!data || typeof data !== "object" || Array.isArray(data) ||
      Object.keys(data).some((key) => !allowedKeys.has(key))) {
    throw new RegistrationError("invalid-argument", "Only latitude and longitude are accepted.");
  }
  const {latitude, longitude} = data;
  if (typeof latitude !== "number" || !Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
    throw new RegistrationError("invalid-argument", "Enter a valid latitude.");
  }
  if (typeof longitude !== "number" || !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw new RegistrationError("invalid-argument", "Enter a valid longitude.");
  }
  return {latitude, longitude};
}

async function reverseGeocodeCommunityLocationCore({db, auth, data, apiKey, fetchImpl = fetch}) {
  await requireLocationSearchAdmin(db, auth);
  const {latitude, longitude} = validateReverseGeocodeInput(data);
  if (!apiKey) throw new Error("GOOGLE_GEOCODING_API_KEY is not configured");
  const url = new URL("https://maps.googleapis.com/maps/api/geocode/json");
  url.searchParams.set("latlng", `${latitude},${longitude}`);
  url.searchParams.set("key", apiKey);
  const response = await fetchImpl(url);
  if (!response.ok) throw new Error(`Reverse geocoding request failed: ${response.status}`);
  const payload = await response.json();
  if (payload.status === "ZERO_RESULTS") return {result: null};
  if (payload.status !== "OK") throw new Error(`Geocoding provider returned ${payload.status}`);
  const result = payload.results?.find((candidate) =>
    typeof candidate?.formatted_address === "string" &&
    candidate.formatted_address.trim().length > 0
  );
  if (!result) throw new Error("Geocoding provider returned an invalid result");
  return {result: {
    latitude,
    longitude,
    formattedAddress: result.formatted_address.trim(),
    placeId: typeof result.place_id === "string" ? result.place_id : null,
  }};
}

module.exports = {
  communityLocationSearchCore,
  validateSessionToken,
  validateCountryCode,
  validatePlaceId,
  resolveCommunityLocationPlaceCore,
  validateReverseGeocodeInput,
  reverseGeocodeCommunityLocationCore,
};
