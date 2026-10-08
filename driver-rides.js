const SUPABASE_URL = "https://kqtvuorasqyzjbnlkkxs.supabase.co";
const SUPABASE_KEY = "sb_publishable_zZFJiy0YWZgOXFesVuAQcA_wd7rleMb";

const db = window.supabase.createClient(
  SUPABASE_URL,
  SUPABASE_KEY
);

let driverUser = null;
let driverProfile = null;
let requestTimer = null;

const el = id => document.getElementById(id);

async function getDriver() {
  const { data, error } = await db.auth.getUser();

  if (error || !data.user) {
    location.href = "driver.html";
    return null;
  }

  driverUser = data.user;

  const { data: profile, error: pError } = await db
    .from("profiles")
    .select("id,full_name,phone,role,is_verified,is_online")
    .eq("id", driverUser.id)
    .maybeSingle();

  if (pError || !profile) {
    showMessage("Driver profile not found.");
    return null;
  }

  if (profile.role !== "driver") {
    showMessage("This account is not a driver account.");
    await db.auth.signOut();
    location.href = "driver.html";
    return null;
  }

  if (profile.is_verified !== true) {
    showMessage("Your driver account is not verified yet.");
    return null;
  }

  driverProfile = profile;
  return profile;
}

function showMessage(text) {
  const box =
    el("driverMsg") ||
    el("rideMsg") ||
    el("message");

  if (box) box.textContent = text;
  else console.log(text);
}

function renderRequests(rides) {
  const box =
    el("rideRequests") ||
    el("requests") ||
    el("requestList");

  if (!box) return;

  if (!rides.length) {
    box.innerHTML =
      '<div class="notice">No ride requests right now.</div>';
    return;
  }

  box.innerHTML = rides.map(ride => `
    <div class="ride-card" data-id="${ride.id}">
      <div class="ride-head">
        <b>🚕 New Ride</b>
        <span>NPR ${Math.round(Number(ride.fare || 0)).toLocaleString()}</span>
      </div>

      <div class="ride-info">
        <div>📍 <b>Pickup</b><br>${escapeHtml(ride.pickup_location || "—")}</div>
        <div>🏁 <b>Destination</b><br>${escapeHtml(ride.destination || "—")}</div>
      </div>

      <div class="ride-meta">
        ${escapeHtml(ride.vehicle_type || "Vehicle")}
        · ${Number(ride.distance_km || 0).toFixed(1)} km
        · ${escapeHtml(ride.payment_method || "cash")}
      </div>

      <button class="acceptRide" data-id="${ride.id}">
        Accept Ride
      </button>
    </div>
  `).join("");

  box.querySelectorAll(".acceptRide").forEach(btn => {
    btn.onclick = () => acceptRide(btn.dataset.id);
  });
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

async function loadRideRequests() {
  if (!driverProfile) return;

  const { data, error } = await db
    .from("rides")
    .select(`
      id,
      passenger_id,
      pickup_location,
      destination,
      vehicle_type,
      distance_km,
      fare,
      payment_method,
      status,
      created_at
    `)
    .eq("status", "requested")
    .is("driver_id", null)
    .order("created_at", { ascending: true });

  if (error) {
    showMessage(error.message);
    return;
  }

  renderRequests(data || []);
}

async function acceptRide(rideId) {
  if (!driverUser) return;

  const buttons = document.querySelectorAll(
    `.acceptRide[data-id="${rideId}"]`
  );

  buttons.forEach(b => {
    b.disabled = true;
    b.textContent = "Accepting...";
  });

  /*
    The status + driver_id conditions make this safer:
    if another driver accepts first, this update won't
    overwrite that driver's ride.
  */
  const { data, error } = await db
    .from("rides")
    .update({
      driver_id: driverUser.id,
      status: "accepted"
    })
    .eq("id", rideId)
    .eq("status", "requested")
    .is("driver_id", null)
    .select()
    .maybeSingle();

  if (error) {
    showMessage(error.message);
    loadRideRequests();
    return;
  }

  if (!data) {
    showMessage("This ride was already accepted by another driver.");
    loadRideRequests();
    return;
  }

  showMessage("Ride accepted successfully.");

  openAcceptedRide(data);
}

function openAcceptedRide(ride) {
  const box =
    el("acceptedRide") ||
    el("currentRide");

  if (!box) {
    loadRideRequests();
    return;
  }

  box.classList.remove("hidden");

  box.innerHTML = `
    <div class="ride-card">
      <h3>🚕 Active Ride</h3>

      <p>
        <b>Pickup:</b><br>
        ${escapeHtml(ride.pickup_location || "—")}
      </p>

      <p>
        <b>Destination:</b><br>
        ${escapeHtml(ride.destination || "—")}
      </p>

      <p>
        <b>Fare:</b>
        NPR ${Math.round(Number(ride.fare || 0)).toLocaleString()}
      </p>

      <button id="startRideBtn" class="orange">
        Start Ride
      </button>
    </div>
  `;

  const start = el("startRideBtn");

  if (start) {
    start.onclick = () => startRide(ride.id);
  }
}

async function startRide(rideId) {
  const { data, error } = await db
    .from("rides")
    .update({ status: "started" })
    .eq("id", rideId)
    .eq("driver_id", driverUser.id)
    .eq("status", "accepted")
    .select()
    .maybeSingle();

  if (error) {
    showMessage(error.message);
    return;
  }

  if (!data) {
    showMessage("Ride could not be started.");
    return;
  }

  showMessage("Ride started.");

  const box =
    el("acceptedRide") ||
    el("currentRide");

  if (box) {
    box.innerHTML += `
      <button id="completeRideBtn" class="blue">
        Complete Ride
      </button>
    `;

    el("completeRideBtn").onclick =
      () => completeRide(rideId);
  }
}

async function completeRide(rideId) {
  const { data, error } = await db
    .from("rides")
    .update({ status: "completed" })
    .eq("id", rideId)
    .eq("driver_id", driverUser.id)
    .eq("status", "started")
    .select()
    .maybeSingle();

  if (error) {
    showMessage(error.message);
    return;
  }

  if (!data) {
    showMessage("Ride could not be completed.");
    return;
  }

  showMessage("Ride completed successfully.");

  const box =
    el("acceptedRide") ||
    el("currentRide");

  if (box) {
    box.innerHTML =
      '<div class="notice">Ride completed successfully.</div>';
  }

  loadRideRequests();
}

async function startDriverRideSystem() {
  const driver = await getDriver();

  if (!driver) return;

  if (driver.is_online === false) {
    showMessage("You are offline. Turn online to receive rides.");
    return;
  }

  await loadRideRequests();

  clearInterval(requestTimer);

  /*
    Polling keeps this working even if Supabase Realtime
    has not yet been enabled for the rides table.
  */
  requestTimer = setInterval(loadRideRequests, 3000);
}

document.addEventListener("DOMContentLoaded", () => {
  startDriverRideSystem();
});
