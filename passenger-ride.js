document.addEventListener("DOMContentLoaded",function(){

const pickup=document.getElementById("pickup");
const destination=document.getElementById("destination");
const fare=document.getElementById("fare");
const gps=document.getElementById("gps");
const request=document.getElementById("request");
const cancel=document.getElementById("cancel");

let vehicle="Bike";
let pickupMarker=null;
let destinationMarker=null;
let routeLine=null;
let searchTimer=null;
let map;


/* MAP */

map=L.map("map",{
 zoomControl:true,
 attributionControl:false
}).setView([27.7172,85.3240],13);

L.tileLayer(
 "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
 {
  maxZoom:19
 }
).addTo(map);


/* VEHICLES */

document.querySelectorAll(".vehicle").forEach(function(btn){

 btn.addEventListener("click",function(){

  document.querySelectorAll(".vehicle")
   .forEach(function(x){
    x.classList.remove("active");
   });

  btn.classList.add("active");

  vehicle=btn.dataset.type;

  calculateFare();

 });

});


/* GPS */

gps.addEventListener("click",function(){

 if(!navigator.geolocation){

  showStatus("GPS is not supported.");

  return;
 }

 gps.textContent="Getting exact location...";

 navigator.geolocation.getCurrentPosition(

  function(pos){

   const lat=pos.coords.latitude;
   const lon=pos.coords.longitude;

   pickup.value=
    lat.toFixed(6)+", "+lon.toFixed(6);

   setPickup(lat,lon);

   gps.textContent="📍 Pickup selected";

   calculateFare();

   drawRouteIfReady();

  },

  function(){

   gps.textContent=
    "📍 Use my current location";

   showStatus(
    "Please allow location access."
   );

  },

  {
   enableHighAccuracy:true,
   timeout:15000,
   maximumAge:0
  }

 );

});


/* DESTINATION SEARCH */

destination.addEventListener(
 "input",
 function(){

  clearTimeout(searchTimer);

  removeResults();

  const q=destination.value.trim();

  if(q.length<2)return;

  searchTimer=setTimeout(
   function(){
    searchPlaces(q);
   },
   700
  );

 }
);


/* GENERAL NEPAL SEARCH */

async function searchPlaces(q){

 try{

  const url=
   "https://nominatim.openstreetmap.org/search"+
   "?format=jsonv2"+
   "&q="+encodeURIComponent(q)+
   "&countrycodes=np"+
   "&layer=address,poi,natural,manmade,railway"+
   "&limit=10"+
   "&addressdetails=1"+
   "&accept-language=en";

  const r=await fetch(url,{
   headers:{
    "Accept":"application/json"
   }
  });

  if(!r.ok)throw new Error();

  const places=await r.json();

  showResults(places);

 }catch(error){

  showStatus(
   "Destination search unavailable."
  );

 }

}


/* SEARCH RESULTS */

function showResults(places){

 removeResults();

 const box=document.createElement("div");

 box.id="placeResults";

 if(!places.length){

  box.innerHTML=
   "<div class='place-item'>"+
   "No Nepal location found"+
   "</div>";

 }else{

  places.forEach(function(place){

   const button=
    document.createElement("button");

   button.type="button";
   button.className="place-item";

   const name=
    place.name ||
    place.display_name.split(",")[0];

   button.innerHTML=
    getIcon(place)+
    " <b>"+safe(name)+"</b>"+
    "<small>"+
    safe(place.display_name)+
    "</small>";

   button.addEventListener(
    "click",
    function(){

     const lat=parseFloat(place.lat);
     const lon=parseFloat(place.lon);

     destination.value=name;

     setDestination(lat,lon);

     removeResults();

     calculateFare();

     drawRouteIfReady();

    }
   );

   box.appendChild(button);

  });

 }

 destination.parentNode.insertBefore(
  box,
  destination.nextSibling
 );

}


/* PICKUP MARKER */

function setPickup(lat,lon){

 if(pickupMarker){
  map.removeLayer(pickupMarker);
 }

 pickupMarker=L.marker([lat,lon])
  .addTo(map)
  .bindPopup("Pickup location");

 map.setView([lat,lon],16);

}


/* DESTINATION MARKER */

function setDestination(lat,lon){

 if(destinationMarker){
  map.removeLayer(destinationMarker);
 }

 destinationMarker=L.marker([lat,lon])
  .addTo(map)
  .bindPopup("Destination")
  .openPopup();

 map.setView([lat,lon],16);

}


/* ROUTE */

async function drawRouteIfReady(){

 if(!pickupMarker ||
    !destinationMarker){

  return;
 }

 const a=
  pickupMarker.getLatLng();

 const b=
  destinationMarker.getLatLng();

 const url=
  "https://router.project-osrm.org/route/v1/driving/"+
  a.lng+","+a.lat+";"+
  b.lng+","+b.lat+
  "?overview=full&geometries=geojson";

 try{

  showStatus("Calculating route...");

  const response=await fetch(url);

  if(!response.ok)throw new Error();

  const data=await response.json();

  if(!data.routes ||
     !data.routes.length){

   showStatus("Route not found.");

   return;
  }

  const route=data.routes[0];

  if(routeLine){
   map.removeLayer(routeLine);
  }

  routeLine=L.geoJSON(
   route.geometry
  ).addTo(map);

  const distance=
   route.distance/1000;

  const minutes=
   Math.round(route.duration/60);

  updateFare(distance);

  showStatus(
   "Distance: "+
   distance.toFixed(1)+
   " km • ETA: "+
   minutes+
   " min"
  );

  map.fitBounds(
   routeLine.getBounds(),
   {
    padding:[30,30]
   }
  );

 }catch(error){

  showStatus(
   "Unable to calculate route."
  );

 }

}


/* FARE */

function calculateFare(){

 if(!pickup.value ||
    !destination.value){

  fare.textContent="--";

  return;
 }

 const prices={
  Bike:50,
  Car:100,
  "Tuk Tuk":80
 };

 fare.textContent=
  "NPR "+prices[vehicle];

}


/* DISTANCE FARE */

function updateFare(distance){

 const rules={
  Bike:{base:25,km:14},
  Car:{base:60,km:25},
  "Tuk Tuk":{base:45,km:18}
 };

 const r=rules[vehicle];

 const total=
  r.base+(distance*r.km);

 fare.textContent=
  "NPR "+Math.round(total);

}


/* REQUEST */

request.addEventListener(
 "click",
 function(){

  if(!pickup.value){

   showStatus(
    "Please select pickup location."
   );

   return;
  }

  if(!destination.value){

   showStatus(
    "Please select destination."
   );

   return;
  }

  if(!destinationMarker){

   showStatus(
    "Please select a destination from search."
   );

   return;
  }

  showStatus(
   "Ride ready • "+
   vehicle+
   " • "+
   fare.textContent
  );

 }
);


/* CANCEL */

cancel.addEventListener(
 "click",
 function(){

  pickup.value="";
  destination.value="";
  fare.textContent="--";

  removeResults();

  if(pickupMarker){
   map.removeLayer(pickupMarker);
   pickupMarker=null;
  }

  if(destinationMarker){
   map.removeLayer(destinationMarker);
   destinationMarker=null;
  }

  if(routeLine){
   map.removeLayer(routeLine);
   routeLine=null;
  }

  gps.textContent=
   "📍 Use my current location";

  removeStatus();

  map.setView(
   [27.7172,85.3240],
   13
  );

 }
);


/* STATUS */

function showStatus(text){

 let box=
  document.getElementById("rideStatus");

 if(!box){

  box=document.createElement("div");

  box.id="rideStatus";

  request.parentNode.insertBefore(
   box,
   request.nextSibling
  );

 }

 box.textContent=text;

}


function removeStatus(){

 const box=
  document.getElementById("rideStatus");

 if(box)box.remove();

}


/* REMOVE SEARCH */

function removeResults(){

 const box=
  document.getElementById("placeResults");

 if(box)box.remove();

}


/* ICON */

function getIcon(place){

 const text=(
  (place.name||"")+" "+
  (place.display_name||"")+" "+
  (place.type||"")
 ).toLowerCase();

 if(text.includes("hotel")||
    text.includes("motel"))return"🏨";

 if(text.includes("bank")||
    text.includes("atm"))return"🏦";

 if(text.includes("hospital")||
    text.includes("clinic")||
    text.includes("medical")||
    text.includes("pharmacy"))return"🏥";

 if(text.includes("bus")||
    text.includes("terminal")||
    text.includes("station"))return"🚌";

 if(text.includes("mall")||
    text.includes("market")||
    text.includes("shopping"))return"🏬";

 if(text.includes("restaurant")||
    text.includes("cafe"))return"🍽️";

 if(text.includes("government")||
    text.includes("office"))return"🏛️";

 if(text.includes("bridge"))return"🌉";

 if(text.includes("statue")||
    text.includes("monument"))return"🗿";

 if(text.includes("park"))return"🌳";

 if(text.includes("airport"))return"✈️";

 if(text.includes("temple")||
    text.includes("church")||
    text.includes("mosque"))return"🛕";

 return"📍";

}


/* SAFE TEXT */

function safe(text){

 return String(text)
  .replace(/&/g,"&amp;")
  .replace(/</g,"&lt;")
  .replace(/>/g,"&gt;")
  .replace(/"/g,"&quot;")
  .replace(/'/g,"&#039;");

}

});
