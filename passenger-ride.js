document.addEventListener("DOMContentLoaded",function(){

const pickup=document.getElementById("pickup");
const destination=document.getElementById("destination");
const fare=document.getElementById("fare");
const gps=document.getElementById("gps");
const request=document.getElementById("request");
const cancel=document.getElementById("cancel");

let vehicle="Bike";
let marker=null;
let map=null;
let timer=null;


/* MAP */

if(typeof L!=="undefined"){

 map=L.map("map").setView(
  [27.7172,85.3240],
  13
 );

 L.tileLayer(
  "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
  {
   attribution:"© OpenStreetMap contributors"
  }
 ).addTo(map);

}


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

 gps.textContent="Getting location...";

 navigator.geolocation.getCurrentPosition(

  function(pos){

   const lat=pos.coords.latitude;
   const lon=pos.coords.longitude;

   pickup.value=
    lat.toFixed(6)+", "+lon.toFixed(6);

   if(map){

    map.setView([lat,lon],16);

    if(marker){
     map.removeLayer(marker);
    }

    marker=L.marker([lat,lon])
     .addTo(map)
     .bindPopup("Pickup location")
     .openPopup();

   }

   gps.textContent="📍 Location selected";

   calculateFare();

  },

  function(){

   gps.textContent="📍 Use my current location";

   showStatus(
    "Location permission was denied."
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

  clearTimeout(timer);

  removeResults();

  const q=
   destination.value.trim();

  if(q.length<2)return;

  timer=setTimeout(
   function(){
    searchPlaces(q);
   },
   700
  );

 }
);


/* SEARCH ANY LOCATION IN NEPAL */

async function searchPlaces(q){

 try{

  const url=
   "https://nominatim.openstreetmap.org/search"+
   "?format=jsonv2"+
   "&q="+encodeURIComponent(q)+
   "&countrycodes=np"+
   "&limit=8"+
   "&addressdetails=1";

  const r=await fetch(url);

  if(!r.ok)throw new Error();

  const places=await r.json();

  showResults(places);

 }catch(e){

  showStatus(
   "Destination search unavailable."
  );

 }

}


/* RESULTS */

function showResults(places){

 removeResults();

 const box=
  document.createElement("div");

 box.id="placeResults";

 if(!places.length){

  box.innerHTML=
   "<div class='place-item'>"+
   "No location found"+
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
    " <b>"+escapeText(name)+"</b>"+
    "<small>"+
    escapeText(place.display_name)+
    "</small>";

   button.addEventListener(
    "click",
    function(){

     destination.value=name;

     const lat=
      parseFloat(place.lat);

     const lon=
      parseFloat(place.lon);

     if(map){

      map.setView(
       [lat,lon],
       16
      );

      if(marker){
       map.removeLayer(marker);
      }

      marker=L.marker([lat,lon])
       .addTo(map)
       .bindPopup(
        escapeText(name)
       )
       .openPopup();

     }

     removeResults();

     calculateFare();

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


/* ICONS */

function getIcon(place){

 const text=(
  (place.name||"")+" "+
  (place.display_name||"")+" "+
  (place.type||"")
 ).toLowerCase();

 if(text.includes("hotel")||
    text.includes("motel"))
  return "🏨";

 if(text.includes("bank")||
    text.includes("atm"))
  return "🏦";

 if(text.includes("hospital")||
    text.includes("clinic")||
    text.includes("medical")||
    text.includes("pharmacy"))
  return "🏥";

 if(text.includes("bus")||
    text.includes("terminal")||
    text.includes("station"))
  return "🚌";

 if(text.includes("mall")||
    text.includes("market")||
    text.includes("shopping"))
  return "🏬";

 if(text.includes("restaurant")||
    text.includes("cafe"))
  return "🍽️";

 if(text.includes("government")||
    text.includes("office"))
  return "🏛️";

 if(text.includes("bridge"))
  return "🌉";

 if(text.includes("statue")||
    text.includes("monument"))
  return "🗿";

 if(text.includes("park"))
  return "🌳";

 if(text.includes("airport"))
  return "✈️";

 if(text.includes("temple")||
    text.includes("church")||
    text.includes("mosque"))
  return "🛕";

 return "📍";

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


/* REQUEST */

request.addEventListener(
 "click",
 function(){

  if(!pickup.value){

   showStatus(
    "Please select your pickup location."
   );

   return;
  }

  if(!destination.value){

   showStatus(
    "Please select a destination."
   );

   return;
  }

  showStatus(
   "Ride request ready • "+
   vehicle+" • "+
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

  if(marker && map){

   map.removeLayer(marker);
   marker=null;

  }

  gps.textContent=
   "📍 Use my current location";

  const status=
   document.getElementById(
    "rideStatus"
   );

  if(status)status.remove();

 }
);


/* REMOVE SEARCH */

function removeResults(){

 const box=
  document.getElementById(
   "placeResults"
  );

 if(box)box.remove();

}


/* SAFE TEXT */

function escapeText(text){

 return String(text)
  .replace(/&/g,"&amp;")
  .replace(/</g,"&lt;")
  .replace(/>/g,"&gt;")
  .replace(/"/g,"&quot;")
  .replace(/'/g,"&#039;");

}

});
