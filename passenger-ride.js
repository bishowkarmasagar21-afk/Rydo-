document.addEventListener("DOMContentLoaded", async () => {

const SUPABASE_URL="https://kqtvuorasqyzjbnlkkxs.supabase.co";
const SUPABASE_KEY="sb_publishable_zZFJiy0YWZgOXFesVuAQcA_wd7rleMb";

const s=document.createElement("script");
s.src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2";
document.head.appendChild(s);
await new Promise(r=>s.onload=r);

const db=window.supabase.createClient(SUPABASE_URL,SUPABASE_KEY);

const map=L.map("map").setView([27.7172,85.3240],13);

L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",{
 maxZoom:19,
 attribution:"© OpenStreetMap"
}).addTo(map);

let pickupCoords=null;
let destinationCoords=null;
let routeDistance=0;
let routeLine=null;
let pickupMarker=null;
let destinationMarker=null;
let selectedVehicle="Bike";
let searchTimer=null;
let searchNumber=0;

const pickup=document.getElementById("pickup");
const destination=document.getElementById("destination");
const fare=document.getElementById("fare");
const request=document.getElementById("request");
const cancel=document.getElementById("cancel");

function status(t){
 let box=document.getElementById("rideStatus");
 if(!box){
  box=document.createElement("div");
  box.id="rideStatus";
  request.parentNode.insertBefore(box,request);
 }
 box.textContent=t;
}

function resultsBox(){
 let box=document.getElementById("placeResults");
 if(!box){
  box=document.createElement("div");
  box.id="placeResults";
  destination.parentNode.insertBefore(box,destination.nextSibling);
 }
 return box;
}

function pickupBox(){
 let box=document.getElementById("pickupResults");
 if(!box){
  box=document.createElement("div");
  box.id="pickupResults";
  pickup.parentNode.insertBefore(box,pickup.nextSibling);
 }
 return box;
}

/* Common Nepal places for instant recommendations */
const popular=[
 ["New Baneshwor","New Baneshwor, Kathmandu, Nepal","📍"],
 ["Thamel","Thamel, Kathmandu, Nepal","📍"],
 ["Kathmandu Durbar Square","Kathmandu Durbar Square, Kathmandu, Nepal","🛕"],
 ["Pashupatinath Temple","Pashupatinath Temple, Kathmandu, Nepal","🛕"],
 ["Boudhanath Stupa","Boudhanath Stupa, Kathmandu, Nepal","🛕"],
 ["Swayambhunath","Swayambhunath, Kathmandu, Nepal","🛕"],
 ["Tribhuvan International Airport","Tribhuvan International Airport, Kathmandu, Nepal","✈️"],
 ["Civil Service Hospital","Civil Service Hospital, Minbhawan, Kathmandu, Nepal","🏥"],
 ["Bir Hospital","Bir Hospital, Kathmandu, Nepal","🏥"],
 ["Teaching Hospital","Tribhuvan University Teaching Hospital, Kathmandu, Nepal","🏥"],
 ["Norvic Hospital","Norvic International Hospital, Kathmandu, Nepal","🏥"],
 ["Grande International Hospital","Grande International Hospital, Kathmandu, Nepal","🏥"],
 ["Bhat-Bhateni","Bhat-Bhateni Supermarket, Kathmandu, Nepal","🛍️"],
 ["City Centre","City Centre, Kamalpokhari, Kathmandu, Nepal","🛍️"],
 ["Civil Mall","Civil Mall, Kathmandu, Nepal","🛍️"],
 ["Ratna Park","Ratna Park, Kathmandu, Nepal","📍"],
 ["Kalanki","Kalanki, Kathmandu, Nepal","📍"],
 ["Koteshwor","Koteshwor, Kathmandu, Nepal","📍"],
 ["Maitighar","Maitighar, Kathmandu, Nepal","📍"],
 ["Lazimpat","Lazimpat, Kathmandu, Nepal","📍"],
 ["Pulchowk","Pulchowk, Lalitpur, Nepal","📍"],
 ["Patan Durbar Square","Patan Durbar Square, Lalitpur, Nepal","🛕"],
 ["Bhaktapur Durbar Square","Bhaktapur Durbar Square, Bhaktapur, Nepal","🛕"],
 ["Pokhara Lakeside","Lakeside, Pokhara, Nepal","📍"],
 ["Pokhara Airport","Pokhara International Airport, Pokhara, Nepal","✈️"],
 ["Butwal","Butwal, Rupandehi, Nepal","📍"],
 ["Bharatpur","Bharatpur, Chitwan, Nepal","📍"],
 ["Biratnagar","Biratnagar, Nepal","📍"],
 ["Dharan","Dharan, Nepal","📍"],
 ["Nepalgunj","Nepalgunj, Nepal","📍"],
 ["Hetauda","Hetauda, Nepal","📍"],
 ["Tansen","Tansen, Palpa, Nepal","📍"],
 ["Lumbini","Lumbini, Nepal","🛕"]
];

/* Extra category words make searches such as
   "hospital Kathmandu", "bank Baneshwor", etc. work better. */
const categories=[
 "hospital","bank","hotel","restaurant","school","college",
 "university","mall","shopping","shop","airport","temple",
 "bus park","office","pharmacy","clinic","police","petrol",
 "supermarket","cafe"
];

function showItem(box,name,address,icon,lat,lon){

 const b=document.createElement("button");
 b.type="button";
 b.className="place-item";

 b.innerHTML=
   `<b>${icon} ${escapeHTML(name)}</b>`+
   `<small>${escapeHTML(address)}</small>`;

 b.onclick=()=>selectDestination(
   name,address,lat,lon,box
 );

 box.appendChild(b);
}

function showPickupItem(box,name,address,lat,lon){

 const b=document.createElement("button");
 b.type="button";
 b.className="place-item";

 b.innerHTML=
   `<b>📍 ${escapeHTML(name)}</b>`+
   `<small>${escapeHTML(address)}</small>`;

 b.onclick=()=>{

   pickup.value=address;
   pickupCoords={lat:Number(lat),lon:Number(lon)};
   box.innerHTML="";

   setMarker("pickup",pickupCoords,"Pickup");

   map.setView([pickupCoords.lat,pickupCoords.lon],16);

   if(destinationCoords) drawRoute();
 };

 box.appendChild(b);
}

function selectDestination(name,address,lat,lon,box){

 destination.value=address;

 destinationCoords={
  lat:Number(lat),
  lon:Number(lon)
 };

 box.innerHTML="";

 setMarker(
  "destination",
  destinationCoords,
  name
 );

 map.setView(
  [destinationCoords.lat,destinationCoords.lon],
  16
 );

 if(pickupCoords) drawRoute();
}

function escapeHTML(value){
 return String(value||"")
  .replaceAll("&","&amp;")
  .replaceAll("<","&lt;")
  .replaceAll(">","&gt;")
  .replaceAll('"',"&quot;")
  .replaceAll("'","&#039;");
}

function setMarker(type,coords,title){

 const marker=L.marker([coords.lat,coords.lon])
  .addTo(map)
  .bindPopup(title);

 if(type==="pickup"){
  if(pickupMarker) map.removeLayer(pickupMarker);
  pickupMarker=marker;
 }else{
  if(destinationMarker) map.removeLayer(destinationMarker);
  destinationMarker=marker;
 }
}

/* Show instant recommendations before/while online search loads */
function localSuggestions(text,box,mode){

 const q=text.toLowerCase().trim();

 if(mode==="destination" && q.length===0){
  box.innerHTML="";
  popular.slice(0,8).forEach(p=>{
   showItem(box,p[0],p[1],p[2],0,0);
  });
  return;
 }

 if(q.length<2) return;

 const matches=popular.filter(p=>
   p[0].toLowerCase().includes(q) ||
   p[1].toLowerCase().includes(q)
 ).slice(0,6);

 box.innerHTML="";

 matches.forEach(p=>{
  showItem(box,p[0],p[1],p[2],0,0);
 });

 /* Replace coordinates of local recommendation by geocoding
    when selected. */
 Array.from(box.children).forEach((button,i)=>{
  const p=matches[i];
  if(!p) return;

  button.onclick=async()=>{
   box.innerHTML="";
   destination.value=p[1];
   status("Finding exact location...");

   const place=await geocode(p[1]);

   if(place){
    destinationCoords={
     lat:Number(place.lat),
     lon:Number(place.lon)
    };

    setMarker("destination",destinationCoords,p[0]);
    map.setView(
     [destinationCoords.lat,destinationCoords.lon],
     16
    );

    status("Destination selected.");

    if(pickupCoords) drawRoute();
   }else{
    status("Could not find that place.");
   }
  };
 });
}

async function geocode(query){

 try{

  const url=
   "https://nominatim.openstreetmap.org/search?"+
   new URLSearchParams({
    q:query,
    format:"jsonv2",
    addressdetails:"1",
    namedetails:"1",
    limit:"1",
    countrycodes:"np",
    "accept-language":"en"
   });

  const r=await fetch(url);
  const d=await r.json();

  return d[0]||null;

 }catch(e){
  console.error(e);
  return null;
 }
}

async function onlineSearch(text,mode,box,mySearch){

 if(mySearch!==searchNumber) return;

 const q=text.trim();

 if(q.length<2) return;

 try{

  let query=q;

  /* Improve category searches */
  if(categories.some(c=>q.toLowerCase()===c)){
   query=q+" Kathmandu Nepal";
  }else if(!q.toLowerCase().includes("nepal")){
   query=q+" Nepal";
  }

  const url=
   "https://nominatim.openstreetmap.org/search?"+
   new URLSearchParams({
    q:query,
    format:"jsonv2",
    addressdetails:"1",
    namedetails:"1",
    extratags:"1",
    limit:"8",
    countrycodes:"np",
    "accept-language":"en"
   });

  const r=await fetch(url,{
   headers:{Accept:"application/json"}
  });

  const data=await r.json();

  if(mySearch!==searchNumber) return;

  /* Keep instant recommendations and add real results */
  const existing=new Set();

  Array.from(box.children).forEach(x=>{
   existing.add(x.textContent.toLowerCase());
  });

  data.forEach(place=>{

   const name=
    place.namedetails?.name ||
    place.address?.amenity ||
    place.address?.shop ||
    place.display_name.split(",")[0];

   const address=place.display_name;

   if(existing.has((name+address).toLowerCase())) return;

   let icon="📍";

   const type=
    `${place.category||""} ${place.type||""}`.toLowerCase();

   if(type.includes("hospital")||type.includes("clinic")) icon="🏥";
   else if(type.includes("bank")) icon="🏦";
   else if(type.includes("hotel")) icon="🏨";
   else if(type.includes("restaurant")||type.includes("cafe")) icon="🍽️";
   else if(type.includes("shop")||type.includes("mall")) icon="🛍️";
   else if(type.includes("place")) icon="📍";
   else if(type.includes("tourism")||type.includes("historic")) icon="🛕";
   else if(type.includes("airport")) icon="✈️";
   else if(type.includes("school")||type.includes("college")) icon="🎓";

   showItem(
    box,
    name,
    address,
    icon,
    place.lat,
    place.lon
   );

  });

 }catch(e){
  console.error("Place search:",e);
 }
}

function searchDestination(){

 const text=destination.value;
 const box=resultsBox();

 searchNumber++;
 const mySearch=searchNumber;

 clearTimeout(searchTimer);

 localSuggestions(text,box,"destination");

 if(text.trim().length<2) return;

 searchTimer=setTimeout(()=>{
  onlineSearch(
   text,
   "destination",
   box,
   mySearch
  );
 },400);
}

function searchPickup(){

 const text=pickup.value;
 const box=pickupBox();

 searchNumber++;
 const mySearch=searchNumber;

 clearTimeout(searchTimer);

 box.innerHTML="";

 if(text.trim().length<2) return;

 searchTimer=setTimeout(async()=>{

  try{

   const url=
    "https://nominatim.openstreetmap.org/search?"+
    new URLSearchParams({
     q:text+" Nepal",
     format:"jsonv2",
     addressdetails:"1",
     namedetails:"1",
     limit:"6",
     countrycodes:"np",
     "accept-language":"en"
    });

   const r=await fetch(url);
   const data=await r.json();

   if(mySearch!==searchNumber) return;

   data.forEach(place=>{

    const name=
     place.namedetails?.name ||
     place.display_name.split(",")[0];

    showPickupItem(
     box,
     name,
     place.display_name,
     place.lat,
     place.lon
    );
   });

  }catch(e){
   console.error(e);
  }

 },400);
}

destination.addEventListener("input",searchDestination);

pickup.addEventListener("input",searchPickup);

/* Open recommendations when destination is focused */
destination.addEventListener("focus",()=>{
 if(!destination.value.trim()){
  localSuggestions("",resultsBox(),"destination");
 }
});

/* GPS */
document.getElementById("gps").addEventListener("click",()=>{

 if(!navigator.geolocation){
  status("GPS is not available on this device.");
  return;
 }

 status("Finding your exact location...");

 navigator.geolocation.getCurrentPosition(
 async position=>{

  const lat=position.coords.latitude;
  const lon=position.coords.longitude;

  pickupCoords={lat,lon};

  try{

   const url=
    "https://nominatim.openstreetmap.org/reverse?"+
    new URLSearchParams({
     lat,
     lon,
     format:"jsonv2",
     addressdetails:"1",
     zoom:"18",
     "accept-language":"en"
    });

   const r=await fetch(url);
   const d=await r.json();

   pickup.value=
    d.display_name ||
    `${lat.toFixed(6)}, ${lon.toFixed(6)}`;

  }catch{

   pickup.value=
    `${lat.toFixed(6)}, ${lon.toFixed(6)}`;
  }

  setMarker(
   "pickup",
   pickupCoords,
   "Your current pickup"
  );

  map.setView([lat,lon],17);

  status(
   `Pickup found. Accuracy ±${Math.round(position.coords.accuracy)} m`
  );

  if(destinationCoords) drawRoute();

 },
 error=>{
  console.error(error);
  status("Location access failed. Please allow GPS permission.");
 },
 {
  enableHighAccuracy:true,
  timeout:15000,
  maximumAge:0
 }
);

});

/* Route */
async function drawRoute(){

 if(!pickupCoords||!destinationCoords) return;

 status("Calculating route...");

 const url=
  "https://router.project-osrm.org/route/v1/driving/"+
  `${pickupCoords.lon},${pickupCoords.lat};`+
  `${destinationCoords.lon},${destinationCoords.lat}`+
  "?overview=full&geometries=geojson";

 try{

  const r=await fetch(url);
  const data=await r.json();

  if(!data.routes?.length){
   status("No driving route found.");
   return;
  }

  const route=data.routes[0];

  routeDistance=route.distance/1000;

  if(routeLine){
   map.removeLayer(routeLine);
  }

  routeLine=L.geoJSON(route.geometry).addTo(map);

  map.fitBounds(routeLine.getBounds(),{
   padding:[30,30]
  });

  await updateFare();

  const minutes=Math.round(route.duration/60);

  status(
   `${routeDistance.toFixed(1)} km • About ${minutes} min`
  );

 }catch(e){

  console.error(e);
  status("Unable to calculate route.");

 }
}

/* Vehicle */
document.querySelectorAll(".vehicle").forEach(button=>{

 button.addEventListener("click",async()=>{

  document.querySelectorAll(".vehicle")
   .forEach(b=>b.classList.remove("active"));

  button.classList.add("active");

  selectedVehicle=button.dataset.type;

  await updateFare();
 });
});

function vehicleType(){
 return selectedVehicle
  .toLowerCase()
  .replace(/\s+/g,"_");
}

/* Real fare_rules */
async function getFareRule(){

 const type=vehicleType();

 const {data,error}=await db
  .from("fare_rules")
  .select(
   "base_fare,per_km_fare,platform_commission_percent"
  )
  .eq("vehicle_type",type)
  .eq("is_active",true)
  .maybeSingle();

 if(error){
  console.error("Fare rule:",error);
  return null;
 }

 return data;
}

async function updateFare(){

 if(!routeDistance){
  fare.textContent="--";
  return;
 }

 const rule=await getFareRule();

 if(!rule){
  fare.textContent="Unavailable";
  return;
 }

 const total=
  Number(rule.base_fare)+
  Number(rule.per_km_fare)*routeDistance;

 fare.textContent=`NPR ${Math.round(total)}`;
}

/* Request real ride */
request.addEventListener("click",async()=>{

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

 request.disabled=true;
 status("Creating your ride request...");

 try{

  const {
   data:{user},
   error:authError
  }=await db.auth.getUser();

  if(authError||!user){
   request.disabled=false;
   status("Please login before requesting a ride.");
   return;
  }

  const rule=await getFareRule();

  if(!rule){
   request.disabled=false;
   status("Fare rule not available.");
   return;
  }

  const totalFare=Math.round(
   Number(rule.base_fare)+
   Number(rule.per_km_fare)*routeDistance
  );

  const commission=
   Number(rule.platform_commission_percent||15);

  const adminEarnings=
   Math.round(totalFare*commission/100);

  const driverEarnings=
   totalFare-adminEarnings;

  const ride={
   passenger_id:user.id,
   pickup:pickup.value,
   destination:destination.value,
   vehicle_type:vehicleType(),
   distance_km:Number(routeDistance.toFixed(2)),
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

  const {error}=await db
   .from("rides")
   .insert(ride);

  if(error){

   console.error("Ride insert:",error);

   request.disabled=false;

   status(
    "Ride request failed: "+error.message
   );

   return;
  }

  fare.textContent=`NPR ${totalFare}`;

  status(
   `Ride requested • ${selectedVehicle} • NPR ${totalFare}`
  );

 }catch(e){

  console.error(e);

  request.disabled=false;

  status("Ride request failed. Please try again.");
 }
});

/* Cancel */
cancel.addEventListener("click",()=>{

 pickup.value="";
 destination.value="";

 pickupCoords=null;
 destinationCoords=null;
 routeDistance=0;

 fare.textContent="--";

 resultsBox().innerHTML="";
 pickupBox().innerHTML="";

 if(routeLine){
  map.removeLayer(routeLine);
  routeLine=null;
 }

 if(pickupMarker){
  map.removeLayer(pickupMarker);
  pickupMarker=null;
 }

 if(destinationMarker){
  map.removeLayer(destinationMarker);
  destinationMarker=null;
 }

 request.disabled=false;

 status("Ride cancelled.");

 map.setView([27.7172,85.3240],13);
});

});
