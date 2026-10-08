/* RYDO PASSENGER RIDE
Google Maps + GPS + Places + Route + Fare + Ride Request
*/

let rydoMap;
let activeMap;
let pickupMarker;
let destinationMarker; 
let routeRenderer;
let directionsService;

let pickupLocation = null;
let destinationLocation = null;
let routeDistanceKm = 0;
let routeDurationMin = 0;
let selectedVehicle = "bike";
let selectedPayment = "cash";
let currentFare = 0;
let fareRules = {};

/* ---------- SCREEN ---------- */

function showScreen(id) {
document.querySelectorAll(".screen").forEach(s => {
s.classList.remove("active");
});

const el = document.getElementById(id);
if (el) el.classList.add("active");
}

/* ---------- GOOGLE MAPS ---------- */

window.initRydoMap = function () {
if (typeof google === "undefined") return;

rydoMap = new google.maps.Map(document.getElementById("map"), {
center: { lat: 27.7172, lng: 85.3240 },
zoom: 13,
mapTypeControl: false,
streetViewControl: false,
fullscreenControl: true
});

directionsService = new google.maps.DirectionsService();
routeRenderer = new google.maps.DirectionsRenderer({
map: rydoMap,
suppressMarkers: true
});

window.initializeRydoGoogleMap = window.initRydoMap;

setupDestinationSearch();
getCurrentLocation();
};

function setupDestinationSearch() {
const input = document.getElementById("destination");

if (!input || !google.maps.places) return;

const autocomplete = new google.maps.places.Autocomplete(input, {
componentRestrictions: { country: "np" },
fields: ["geometry", "formatted_address", "name"]
});

autocomplete.addListener("place_changed", () => {
const place = autocomplete.getPlace();

if (!place.geometry || !place.geometry.location) {
  return;
}

destinationLocation = {
  lat: place.geometry.location.lat(),
  lng: place.geometry.location.lng()
};

input.value = place.formatted_address || place.name || "";

if (pickupLocation) {
  calculateRoute();
}

});
}

/* ---------- GPS ---------- */

function getCurrentLocation() {
if (!navigator.geolocation) return;

navigator.geolocation.getCurrentPosition(
position => {
pickupLocation = {
lat: position.coords.latitude,
lng: position.coords.longitude
};

  setPickupMarker();
  if (rydoMap) {
    rydoMap.setCenter(pickupLocation);
    rydoMap.setZoom(16);
  }

  const pickup = document.getElementById("pickup");
  if (pickup) pickup.value = "My current location";
},
() => {
  const pickup = document.getElementById("pickup");
  if (pickup) pickup.placeholder = "Enter pickup location";
},
{
  enableHighAccuracy: true,
  timeout: 10000,
  maximumAge: 5000
}

);
}

function setPickupMarker() {
if (!rydoMap || !pickupLocation) return;

if (pickupMarker) pickupMarker.setMap(null);

pickupMarker = new google.maps.Marker({
position: pickupLocation,
map: rydoMap,
title: "Pickup"
});
}

/* ---------- MANUAL PICKUP ---------- */

async function searchPickup() {
const input = document.getElementById("pickup");
if (!input || !input.value.trim()) return;

if (!google.maps.places) return;

const service = new google.maps.places.AutocompleteService();

service.getPlacePredictions(
{
input: input.value,
componentRestrictions: { country: "np" }
},
async predictions => {
if (!predictions || !predictions.length) return;

  const places = new google.maps.places.PlacesService(rydoMap);

  places.getDetails(
    {
      placeId: predictions[0].place_id,
      fields: ["geometry", "formatted_address", "name"]
    },
    place => {
      if (!place || !place.geometry) return;

      pickupLocation = {
        lat: place.geometry.location.lat(),
        lng: place.geometry.location.lng()
      };

      input.value = place.formatted_address || place.name || "";
      setPickupMarker();

      if (rydoMap) {
        rydoMap.setCenter(pickupLocation);
        rydoMap.setZoom(16);
      }

      if (destinationLocation) calculateRoute();
    }
  );
}

);
}

/* ---------- ROUTE ---------- */

function calculateRoute() {
if (!pickupLocation || !destinationLocation || !directionsService) {
return;
}

directionsService.route(
{
origin: pickupLocation,
destination: destinationLocation,
travelMode: google.maps.TravelMode.DRIVING
},
(result, status) => {
if (status !== "OK") {
console.error("Route error:", status);
return;
}

  routeRenderer.setDirections(result);

  const leg = result.routes[0].legs[0];

  routeDistanceKm = leg.distance.value / 1000;
  routeDurationMin = Math.ceil(leg.duration.value / 60);

  if (destinationMarker) destinationMarker.setMap(null);

  destinationMarker = new google.maps.Marker({
    position: destinationLocation,
    map: rydoMap,
    title: "Destination"
  });

  updateRouteInfo();
  calculateFare();
}

);
}

function updateRouteInfo() {
const distance = document.getElementById("distance");
const eta = document.getElementById("eta");

if (distance) {
distance.textContent = routeDistanceKm.toFixed(1) + " km";
}

if (eta) {
eta.textContent = routeDurationMin + " min";
}
}

/* ---------- FARE ---------- */

async function loadFareRules() {
const { data, error } = await supabaseClient
.from("fare_rules")
.select("*")
.eq("is_active", true);

if (error) {
console.error("Fare rules:", error);
return;
}

fareRules = {};

(data || []).forEach(rule => {
fareRules[rule.vehicle_type] = rule;
});

calculateFare();
}

function calculateFare() {
if (!routeDistanceKm) return;

const rule = fareRules[selectedVehicle];

if (!rule) return;

const base = Number(rule.base_fare) || 0;
const perKm = Number(rule.per_km_fare) || 0;

currentFare = Math.round(base + routeDistanceKm * perKm);

const fare = document.getElementById("fare");
if (fare) {
fare.textContent = "NPR " + currentFare;
}
}

/* ---------- VEHICLE ---------- */

function selectVehicle(vehicle) {
selectedVehicle = vehicle;

document.querySelectorAll("[data-vehicle]").forEach(btn => {
btn.classList.remove("selected");
});

const selected = document.querySelector(
"[data-vehicle="${vehicle}"]"
);

if (selected) selected.classList.add("selected");

calculateFare();
}

/* ---------- PAYMENT ---------- */

function selectPayment(payment) {
selectedPayment = payment;

document.querySelectorAll("[data-payment]").forEach(btn => {
btn.classList.remove("selected");
});

const selected = document.querySelector(
"[data-payment="${payment}"]"
);

if (selected) selected.classList.add("selected");
}

/* ---------- RIDE REQUEST ---------- */

async function requestRydo() {
const {
data: { user }
} = await supabaseClient.auth.getUser();

if (!user) {
alert("Please login first.");
showScreen("authScreen");
return;
}

if (!pickupLocation || !destinationLocation) {
alert("Please select pickup and destination.");
return;
}

if (!routeDistanceKm || !currentFare) {
alert("Please wait for the route and fare.");
return;
}

const button = document.getElementById("requestRide");
if (button) button.disabled = true;

const ride = {
passenger_id: user.id,
pickup: document.getElementById("pickup")?.value || "Pickup",
destination: document.getElementById("destination")?.value || "Destination",
pickup_lat: pickupLocation.lat,
pickup_lon: pickupLocation.lng,
destination_lat: destinationLocation.lat,
destination_lon: destinationLocation.lng,
vehicle_type: selectedVehicle,
distance_km: Number(routeDistanceKm.toFixed(2)),
fare: currentFare,
payment_method: selectedPayment,
payment_status: "pending",
status: "requested"
};

const { data, error } = await supabaseClient
.from("rides")
.insert(ride)
.select()
.single();

if (button) button.disabled = false;

if (error) {
console.error(error);
alert("Ride request failed: " + error.message);
return;
}

window.currentRide = data;

showScreen("searchingScreen");

setTimeout(() => {
showScreen("activeScreen");
}, 1200);

if (window.startRydoLiveTracking) {
window.startRydoLiveTracking(data.id);
}
}

/* ---------- CANCEL ---------- */

async function cancelRide() {
const ride = window.currentRide;

if (!ride) return;

const { error } = await supabaseClient
.from("rides")
.update({ status: "cancelled" })
.eq("id", ride.id);

if (error) {
alert("Unable to cancel ride.");
return;
}

window.currentRide = null;
showScreen("rideScreen");
}

/* ---------- BUTTONS ---------- */

document.addEventListener("DOMContentLoaded", () => {
loadFareRules();

const request = document.getElementById("requestRide");
if (request) request.addEventListener("click", requestRydo);

const cancel = document.getElementById("cancelRide");
if (cancel) cancel.addEventListener("click", cancelRide);

document.querySelectorAll("[data-vehicle]").forEach(btn => {
btn.addEventListener("click", () => {
selectVehicle(btn.dataset.vehicle);
});
});

document.querySelectorAll("[data-payment]").forEach(btn => {
btn.addEventListener("click", () => {
selectPayment(btn.dataset.payment);
});
});

const pickup = document.getElementById("pickup");

if (pickup) {
pickup.addEventListener("change", searchPickup);
}
});

/* ---------- PUBLIC FUNCTIONS ---------- */

window.selectVehicle = selectVehicle;
window.selectPayment = selectPayment;
window.calculateRoute = calculateRoute;
window.getCurrentLocation = getCurrentLocation;
window.requestRydo = requestRydo;
window.cancelRide = cancelRide;
window.searchPickup = searchPickup;


**Important:** this file does **not** contain driver tracking yet. We are deliberately separating that part so GitHub doesn't cut the code again.

After you save this file, **don't change anything else yet**. Tell me **“Done”**, and we'll create the next smaller file: **`passenger-auth.js`**.
