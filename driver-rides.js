/* RYDO DRIVER RIDES */

const onlineStatus = document.getElementById("onlineStatus");
const onlineBtn = document.getElementById("onlineBtn");
const logoutBtn = document.getElementById("logoutBtn");
const refreshBtn = document.getElementById("refreshBtn");
const requests = document.getElementById("requests");
const currentRideCard = document.getElementById("currentRideCard");
const currentRide = document.getElementById("currentRide");
const startRideBtn = document.getElementById("startRideBtn");
const completeRideBtn = document.getElementById("completeRideBtn");
const gpsStatus = document.getElementById("gpsStatus");

let rideId = null;
let gpsWatch = null;


/* START DRIVER APP */

window.startDriverApp = async function () {

  document.getElementById("driverName").textContent =
    window.currentDriver.full_name || "Driver";

  document.getElementById("verificationStatus").textContent =
    "✓ Verified Driver";

  setOnlineUI(window.currentDriver.is_online);

  if (window.currentDriver.is_online) {
    startGPS();
    loadRequests();
  } else {
    showNoRequests();
  }

  loadCurrentRide();
};


/* ONLINE / OFFLINE */

onlineBtn.onclick = async function () {

  const online = !window.currentDriver.is_online;

  const { error } = await db
    .from("profiles")
    .update({
      is_online: online
    })
    .eq("id", window.currentUser.id);

  if (error) {
    alert(error.message);
    return;
  }

  window.currentDriver.is_online = online;

  setOnlineUI(online);

  if (online) {
    startGPS();
    loadRequests();
  } else {
    stopGPS();
    showNoRequests();
  }
};


function setOnlineUI(online) {

  onlineStatus.textContent =
    online ? "ONLINE" : "OFFLINE";

  onlineBtn.textContent =
    online ? "Go Offline" : "Go Online";
}


/* GPS */

function startGPS() {

  if (!navigator.geolocation) {
    gpsStatus.textContent =
      "GPS is not supported.";
    return;
  }

  if (gpsWatch !== null) return;

  gpsStatus.textContent =
    "Getting live location...";

  gpsWatch = navigator.geolocation.watchPosition(
    updateLocation,
    gpsError,
    {
      enableHighAccuracy: true,
      maximumAge: 5000,
      timeout: 15000
    }
  );
}


async function updateLocation(position) {

  const lat = position.coords.latitude;
  const lng = position.coords.longitude;

  gpsStatus.textContent =
    "GPS active: " +
    lat.toFixed(5) +
    ", " +
    lng.toFixed(5);

  await db
    .from("profiles")
    .update({
      current_latitude: lat,
      current_longitude: lng,
      location_updated_at: new Date().toISOString()
    })
    .eq("id", window.currentUser.id);
}


function gpsError() {
  gpsStatus.textContent =
    "Unable to get GPS location.";
}


function stopGPS() {

  if (gpsWatch !== null) {
    navigator.geolocation.clearWatch(gpsWatch);
    gpsWatch = null;
  }

  gpsStatus.textContent =
    "GPS is not active.";
}


/* LOAD REQUESTS */

refreshBtn.onclick = loadRequests;

async function loadRequests() {

  if (!window.currentDriver?.is_online) {
    showNoRequests();
    return;
  }

  requests.innerHTML =
    "<p>Loading requests...</p>";

  const { data, error } = await db
    .from("rides")
    .select("*")
    .is("driver_id", null)
    .eq("status", "requested")
    .order("created_at", {
      ascending: false
    });

  if (error) {
    requests.innerHTML =
      "<p>Could not load requests.</p>";
    console.error(error);
    return;
  }

  if (!data || data.length === 0) {
    showNoRequests();
    return;
  }

  requests.innerHTML = "";

  data.forEach(ride => {
    requests.appendChild(makeRequest(ride));
  });
}


function showNoRequests() {

  requests.innerHTML =
    "<p>No ride requests available.</p>";
}


/* REQUEST CARD */

function makeRequest(ride) {

  const box = document.createElement("div");

  box.className = "rideRequest";

  box.innerHTML = `
    <h3>${ride.vehicle_type || "Ride"}</h3>

    <p>
      <b>Pickup:</b><br>
      ${safe(ride.pickup_location)}
    </p>

    <p>
      <b>Destination:</b><br>
      ${safe(ride.destination)}
    </p>

    <p>
      <b>Distance:</b>
      ${ride.distance_km || "N/A"} km
    </p>

    <p>
      <b>Fare:</b>
      NPR ${ride.fare || "N/A"}
    </p>

    <button class="primary acceptBtn">
      Accept Ride
    </button>
  `;

  box.querySelector(".acceptBtn").onclick =
    function () {
      acceptRide(ride.id, this);
    };

  return box;
}


/* ACCEPT */

async function acceptRide(id, button) {

  button.disabled = true;
  button.textContent = "Accepting...";

  const { data, error } = await db
    .from("rides")
    .update({
      driver_id: window.currentUser.id,
      status: "accepted"
    })
    .eq("id", id)
    .is("driver_id", null)
    .eq("status", "requested")
    .select()
    .single();

  if (error || !data) {

    alert(
      error?.message ||
      "Ride is no longer available."
    );

    button.disabled = false;
    button.textContent = "Accept Ride";
    return;
  }

  rideId = data.id;

  alert("Ride accepted!");

  showCurrentRide(data);

  loadRequests();
}


/* CURRENT RIDE */

async function loadCurrentRide() {

  const { data } = await db
    .from("rides")
    .select("*")
    .eq("driver_id", window.currentUser.id)
    .in("status", [
      "accepted",
      "in_progress"
    ])
    .order("created_at", {
      ascending: false
    })
    .limit(1)
    .maybeSingle();

  if (!data) {
    currentRideCard.classList.add("hidden");
    return;
  }

  rideId = data.id;
  showCurrentRide(data);
}


function showCurrentRide(ride) {

  currentRideCard.classList.remove("hidden");

  currentRide.innerHTML = `
    <p>
      <b>Pickup:</b><br>
      ${safe(ride.pickup_location)}
    </p>

    <p>
      <b>Destination:</b><br>
      ${safe(ride.destination)}
    </p>

    <p>
      <b>Fare:</b>
      NPR ${ride.fare || "N/A"}
    </p>

    <p>
      <b>Status:</b>
      ${ride.status}
    </p>
  `;

  if (ride.status === "accepted") {

    startRideBtn.classList.remove("hidden");
    completeRideBtn.classList.add("hidden");

  } else {

    startRideBtn.classList.add("hidden");
    completeRideBtn.classList.remove("hidden");
  }
}


/* START RIDE */

startRideBtn.onclick = async function () {

  if (!rideId) return;

  startRideBtn.disabled = true;
  startRideBtn.textContent = "Starting...";

  const { data, error } = await db
    .from("rides")
    .update({
      status: "in_progress"
    })
    .eq("id", rideId)
    .eq("driver_id", window.currentUser.id)
    .eq("status", "accepted")
    .select()
    .single();

  if (error) {
    alert(error.message);
  } else {
    showCurrentRide(data);
  }

  startRideBtn.disabled = false;
  startRideBtn.textContent = "Start Ride";
};


/* COMPLETE RIDE */

completeRideBtn.onclick = async function () {

  if (!rideId) return;

  completeRideBtn.disabled = true;
  completeRideBtn.textContent = "Completing...";

  const { error } = await db
    .from("rides")
    .update({
      status: "completed"
    })
    .eq("id", rideId)
    .eq("driver_id", window.currentUser.id)
    .eq("status", "in_progress");

  if (error) {

    alert(error.message);

  } else {

    alert("Ride completed!");

    rideId = null;

    currentRideCard.classList.add("hidden");

    loadRequests();
  }

  completeRideBtn.disabled = false;
  completeRideBtn.textContent =
    "Complete Ride";
};


/* LOGOUT */

logoutBtn.onclick = async function () {

  stopGPS();

  await db
    .from("profiles")
    .update({
      is_online: false
    })
    .eq("id", window.currentUser.id);

  await db.auth.signOut();

  window.location.reload();
};


/* REFRESH EVERY 10 SECONDS */

setInterval(function () {

  if (
    window.currentDriver &&
    window.currentDriver.is_online
  ) {
    loadRequests();
    loadCurrentRide();
  }

}, 10000);


/* SECURITY */

function safe(value) {

  if (!value) return "N/A";

  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
    }
