document.addEventListener("DOMContentLoaded", async () => {

const SUPABASE_URL = "https://kqtvuorasqyzjbnlkkxs.supabase.co";
const SUPABASE_KEY = "sb_publishable_zZFJiy0YWZgOXFesVuAQcA_wd7rleMb";

const script = document.createElement("script");
script.src = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2";
document.head.appendChild(script);

await new Promise(resolve => script.onload = resolve);

const db = window.supabase.createClient(
  SUPABASE_URL,
  SUPABASE_KEY
);

const map = L.map("map").setView([27.7172,85.3240],13);

L.tileLayer(
  "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
  {maxZoom:19}
).addTo(map);

let pickupCoords = null;
let destinationCoords = null;
let routeDistance = 0;
let routeLine = null;
let selectedVehicle = "Bike";

const pickup = document.getElementById("pickup");
const destination = document.getElementById("destination");
const fare = document.getElementById("fare");
const request = document.getElementById("request");
const cancel = document.getElementById("cancel");

function status(message){
  const box = document.getElementById("rideStatus");
  if(box) box.textContent = message;
}

function addMarker(lat,lon,text){
  return L.marker([lat,lon]).addTo(map).bindPopup(text);
}

async function searchPlace(text,mode){

  if(text.length < 3) return;

  const url =
    "https://nominatim.openstreetmap.org/search?" +
    new URLSearchParams({
      q:text,
      format:"json",
      limit:"6",
      countrycodes:"np",
      addressdetails:"1"
    });

  try{
    const res = await fetch(url,{
      headers:{Accept:"application/json"}
    });

    const data = await res.json();

    const box = document.getElementById(
      mode === "pickup" ? "pickupResults" : "placeResults"
    );

    if(!box) return;

    box.innerHTML = "";

    data.forEach(place => {

      const button = document.createElement("button");
      button.className = "place-item";
      button.type = "button";

      button.innerHTML =
        "<b>📍 " + place.display_name.split(",")[0] + "</b>" +
        "<small>" + place.display_name + "</small>";

      button.onclick = () => {

        const coords = {
          lat:Number(place.lat),
          lon:Number(place.lon)
        };

        if(mode === "pickup"){
          pickup.value = place.display_name;
          pickupCoords = coords;
        }else{
          destination.value = place.display_name;
          destinationCoords = coords;
        }

        box.innerHTML = "";

        map.setView(
          [coords.lat,coords.lon],
          15
        );

        addMarker(
          coords.lat,
          coords.lon,
          place.display_name
        );

        if(pickupCoords && destinationCoords){
          drawRoute();
        }
      };

      box.appendChild(button);
    });

  }catch(error){
    console.error(error);
  }
}

pickup.addEventListener("input",()=>{
  searchPlace(pickup.value,"pickup");
});

destination.addEventListener("input",()=>{
  searchPlace(destination.value,"destination");
});

document.getElementById("gps").addEventListener("click",()=>{

  if(!navigator.geolocation){
    status("GPS is not available on this device.");
    return;
  }

  status("Finding your exact location...");

  navigator.geolocation.getCurrentPosition(
    async position => {

      const lat = position.coords.latitude;
      const lon = position.coords.longitude;

      pickupCoords = {lat,lon};

      try{

        const res = await fetch(
          "https://nominatim.openstreetmap.org/reverse?" +
          new URLSearchParams({
            lat,
            lon,
            format:"json",
            zoom:"18",
            addressdetails:"1"
          })
        );

        const data = await res.json();

        pickup.value =
          data.display_name ||
          `${lat.toFixed(6)}, ${lon.toFixed(6)}`;

      }catch{

        pickup.value =
          `${lat.toFixed(6)}, ${lon.toFixed(6)}`;
      }

      map.setView([lat,lon],17);

      addMarker(lat,lon,"Your pickup location");

      status("Pickup location found.");

      if(destinationCoords){
        drawRoute();
      }
    },

    error => {
      status("Unable to get GPS location. Please allow location access.");
      console.error(error);
    },

    {
      enableHighAccuracy:true,
      timeout:15000,
      maximumAge:0
    }
  );
});

async function drawRoute(){

  if(!pickupCoords || !destinationCoords) return;

  const url =
    `https://router.project-osrm.org/route/v1/driving/` +
    `${pickupCoords.lon},${pickupCoords.lat};` +
    `${destinationCoords.lon},${destinationCoords.lat}` +
    `?overview=full&geometries=geojson`;

  try{

    const res = await fetch(url);
    const data = await res.json();

    if(!data.routes || !data.routes.length){
      status("Route could not be found.");
      return;
    }

    const route = data.routes[0];

    routeDistance = route.distance / 1000;

    if(routeLine){
      map.removeLayer(routeLine);
    }

    routeLine = L.geoJSON(
      route.geometry
    ).addTo(map);

    map.fitBounds(routeLine.getBounds(),{
      padding:[30,30]
    });

    await updateFare();

    status(
      `Route: ${routeDistance.toFixed(1)} km`
    );

  }catch(error){

    console.error(error);
    status("Unable to calculate route.");

  }
}

document.querySelectorAll(".vehicle").forEach(button=>{

  button.addEventListener("click",async ()=>{

    document.querySelectorAll(".vehicle")
      .forEach(b=>b.classList.remove("active"));

    button.classList.add("active");

    selectedVehicle = button.dataset.type;

    await updateFare();
  });
});

async function updateFare(){

  if(!routeDistance){
    fare.textContent = "--";
    return;
  }

  const type =
    selectedVehicle
      .toLowerCase()
      .replace(/\s+/g,"_");

  const {data,error} = await db
    .from("fare_rules")
    .select(
      "base_fare,per_km_fare,platform_commission_percent"
    )
    .eq("vehicle_type",type)
    .eq("is_active",true)
    .maybeSingle();

  if(error){
    console.error(error);
    fare.textContent = "Error";
    status("Unable to load fare rules.");
    return;
  }

  if(!data){
    fare.textContent = "Unavailable";
    status(`No active fare rule for ${selectedVehicle}.`);
    return;
  }

  const total =
    Number(data.base_fare) +
    Number(data.per_km_fare) * routeDistance;

  fare.textContent =
    `NPR ${Math.round(total)}`;
}

request.addEventListener("click",async ()=>{

  if(!pickupCoords){
    status("Please select your pickup location.");
    return;
  }

  if(!destinationCoords){
    status("Please select your destination.");
    return;
  }

  if(!routeDistance){
    status("Please wait for the route and fare.");
    return;
  }

  request.disabled = true;
  status("Creating your ride request...");

  try{

    const {
      data:{user},
      error:authError
    } = await db.auth.getUser();

    if(authError || !user){
      request.disabled = false;
      status("Please login before requesting a ride.");
      return;
    }

    const type =
      selectedVehicle
        .toLowerCase()
        .replace(/\s+/g,"_");

    const {
      data:rule,
      error:ruleError
    } = await db
      .from("fare_rules")
      .select(
        "base_fare,per_km_fare,platform_commission_percent"
      )
      .eq("vehicle_type",type)
      .eq("is_active",true)
      .maybeSingle();

    if(ruleError || !rule){
      request.disabled = false;
      status("Fare rule not available.");
      return;
    }

    const totalFare =
      Math.round(
        Number(rule.base_fare) +
        Number(rule.per_km_fare) * routeDistance
      );

    const commission =
      Number(rule.platform_commission_percent || 15);

    const adminEarnings =
      Math.round(totalFare * commission / 100);

    const driverEarnings =
      totalFare - adminEarnings;

    const ride = {

      passenger_id:user.id,

      pickup:pickup.value,

      destination:destination.value,

      vehicle_type:type,

      distance_km:
        Number(routeDistance.toFixed(2)),

      fare:totalFare,

      driver_earnings:driverEarnings,

      admin_earnings:adminEarnings,

      payment_method:"cash",

      status:"requested",

      pickup_lat:pickupCoords.lat,

      pickup_lon:pickupCoords.lon,

      destination_lat:destinationCoords.lat,

      destination_lon:destinationCoords.lon
    };

    const {
      data,
      error
    } = await db
      .from("rides")
      .insert(ride)
      .select()
      .single();

    if(error){
      console.error(error);
      request.disabled = false;
      status("Ride request failed: " + error.message);
      return;
    }

    fare.textContent =
      `NPR ${totalFare}`;

    status(
      `Ride requested successfully • ${selectedVehicle} • NPR ${totalFare}`
    );

  }catch(error){

    console.error(error);

    request.disabled = false;

    status(
      "Ride request failed. Check your connection."
    );
  }
});

cancel.addEventListener("click",()=>{

  pickup.value = "";
  destination.value = "";

  pickupCoords = null;
  destinationCoords = null;
  routeDistance = 0;

  fare.textContent = "--";

  if(routeLine){
    map.removeLayer(routeLine);
    routeLine = null;
  }

  request.disabled = false;

  status("Ride cancelled.");

  map.setView([27.7172,85.3240],13);
});

});
