/* RYDO PASSENGER LIVE
Driver tracking + active ride updates
*/

let driverMarker = null;
let driverChannel = null;
let rideChannel = null;
let trackingRideId = null;

/* ---------- START TRACKING ---------- */

async function startRydoLiveTracking(rideId) {
if (!rideId) return;

trackingRideId = rideId;

await loadRide(rideId);
subscribeToRide(rideId);
}

/* ---------- LOAD RIDE ---------- */

async function loadRide(rideId) {
const { data, error } = await supabaseClient
.from("rides")
.select("*")
.eq("id", rideId)
.single();

if (error) {
console.error("Ride:", error);
return;
}

window.currentRide = data;

updateRideStatus(data);

if (data.driver_id) {
await loadDriver(data.driver_id);
}
}

/* ---------- RIDE REALTIME ---------- */

function subscribeToRide(rideId) {
if (rideChannel) {
supabaseClient.removeChannel(rideChannel);
}

rideChannel = supabaseClient
.channel("rydo-ride-" + rideId)
.on(
"postgres_changes",
{
event: "UPDATE",
schema: "public",
table: "rides",
filter: "id=eq." + rideId
},
payload => {
window.currentRide = payload.new;

    updateRideStatus(payload.new);

    if (payload.new.driver_id) {
      loadDriver(payload.new.driver_id);
    }
  }
)
.subscribe();

}

/* ---------- RIDE STATUS ---------- */

function updateRideStatus(ride) {
const status = ride.status;

const statusText = document.getElementById("activeStatus");

if (statusText) {
if (status === "requested") {
statusText.textContent = "Finding a driver...";
} else if (status === "accepted") {
statusText.textContent = "Driver accepted your ride";
} else if (status === "arriving") {
statusText.textContent = "Driver is arriving";
} else if (status === "started") {
statusText.textContent = "Ride in progress";
} else if (status === "completed") {
statusText.textContent = "Ride completed";
showCompletedRide(ride);
} else if (status === "cancelled") {
statusText.textContent = "Ride cancelled";
}
}

const fare = document.getElementById("activeFare");

if (fare && ride.fare != null) {
fare.textContent = "NPR " + Math.round(Number(ride.fare));
}
}

/* ---------- DRIVER ---------- */

async function loadDriver(driverId) {
const { data, error } = await supabaseClient
.from("profiles")
.select("id, full_name, phone")
.eq("id", driverId)
.single();

if (error) {
console.error("Driver:", error);
return;
}

window.currentDriver = data;

const name = document.getElementById("driverName");
const phone = document.getElementById("driverPhone");

if (name) {
name.textContent = data.full_name || "Rydo Driver";
}

if (phone) {
phone.textContent = data.phone || "";
}

subscribeToDriverLocation(driverId);
}

/* ---------- DRIVER LOCATION ---------- */

function subscribeToDriverLocation(driverId) {

if (driverChannel) {
supabaseClient.removeChannel(driverChannel);
}

/*
Driver location should eventually come from:

driver_locations
----------------
driver_id
ride_id
latitude
longitude
updated_at

We intentionally do not read fake coordinates.

*/

driverChannel = supabaseClient
.channel("rydo-driver-" + driverId)
.on(
"broadcast",
{ event: "driver_location" },
payload => {
const location = payload.payload;

    if (!location) return;
    if (location.driver_id !== driverId) return;

    updateDriverMarker(
      Number(location.latitude),
      Number(location.longitude)
    );
  }
)
.subscribe();

}

/* ---------- DRIVER MARKER ---------- */

function updateDriverMarker(lat, lng) {
if (!window.google || !window.google.maps) return;

const position = { lat, lng };

if (!activeMap) {
createActiveMap(position);
}

if (driverMarker) {
driverMarker.setPosition(position);
} else {
driverMarker = new google.maps.Marker({
position,
map: activeMap,
title: "Rydo Driver"
});
}

if (activeMap) {
activeMap.panTo(position);
}

updateDriverETA(position);
}

/* ---------- ACTIVE MAP ---------- */

function createActiveMap(position) {
const mapElement = document.getElementById("activeMap");

if (!mapElement) return;

activeMap = new google.maps.Map(mapElement, {
center: position,
zoom: 16,
mapTypeControl: false,
streetViewControl: false,
fullscreenControl: true
});

driverMarker = new google.maps.Marker({
position,
map: activeMap,
title: "Rydo Driver"
});
}

/* ---------- DRIVER ETA ---------- */

function updateDriverETA(driverPosition) {
if (!window.google || !window.google.maps) return;

const ride = window.currentRide;

if (!ride) return;

if (
!ride.pickup_lat ||
!ride.pickup_lon
) {
return;
}

const service = new google.maps.DistanceMatrixService();

service.getDistanceMatrix(
{
origins: [driverPosition],
destinations: [
{
lat: Number(ride.pickup_lat),
lng: Number(ride.pickup_lon)
}
],
travelMode: google.maps.TravelMode.DRIVING
},
(result, status) => {

  if (status !== "OK") return;

  const element = result.rows?.[0]?.elements?.[0];

  if (!element || element.status !== "OK") return;

  const eta = document.getElementById("driverEta");

  if (eta) {
    eta.textContent = element.duration.text;
  }
}

);
}

/* ---------- COMPLETED RIDE ---------- */

function showCompletedRide(ride) {
const finalFare = document.getElementById("finalFare");
const finalDistance = document.getElementById("finalDistance");

if (finalFare) {
finalFare.textContent =
"NPR " + Math.round(Number(ride.fare || 0));
}

if (finalDistance) {
finalDistance.textContent =
Number(ride.distance_km || 0).toFixed(2) + " km";
}

setTimeout(() => {
const screen = document.getElementById("completedScreen");

if (screen) {
  document.querySelectorAll(".screen").forEach(s => {
    s.classList.remove("active");
  });

  screen.classList.add("active");
}

}, 700);
}

/* ---------- CLEANUP ---------- */

function stopRydoLiveTracking() {

if (driverChannel) {
supabaseClient.removeChannel(driverChannel);
driverChannel = null;
}

if (rideChannel) {
supabaseClient.removeChannel(rideChannel);
rideChannel = null;
}

trackingRideId = null;

if (driverMarker) {
driverMarker.setMap(null);
driverMarker = null;
}
}

/* ---------- PUBLIC ---------- */

window.startRydoLiveTracking = startRydoLiveTracking;
window.stopRydoLiveTracking = stopRydoLiveTracking;
window.updateDriverMarker = updateDriverMarker;


### One important thing

This file is the **passenger-side tracker**. It does **not** create fake driver coordinates.

Our next job is to connect the **driver app → Supabase → passenger app**, so the driver's real GPS position moves on the passenger's Google Map.

After saving `passenger-live.js`, tell me **Done**. Then we'll connect the three passenger JS files to `passenger.html` before touching the driver tracking system.
