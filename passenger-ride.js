const pickup=document.getElementById("pickup");
const destination=document.getElementById("destination");
const fare=document.getElementById("fare");
const gps=document.getElementById("gps");
const request=document.getElementById("request");
const cancel=document.getElementById("cancel");

let vehicle="Bike";
let marker=null;
let map=null;
let searchTimer=null;

/* MAP */

if(typeof L!=="undefined"){

 map=L.map("map").setView([27.7172,85.3240],13);

 L.tileLayer(
  "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
  {
   attribution:"© OpenStreetMap contributors"
  }
 ).addTo(map);

}

/* VEHICLE BUTTONS */

document.querySelectorAll(".vehicle").forEach(btn=>{

 btn.addEventListener("click",function(){

  document.querySelectorAll(".vehicle")
   .forEach(x=>x.classList.remove("active"));

  this.classList.add("active");

  vehicle=this.dataset.type;

  calculateFare();

 });

});


/* CURRENT LOCATION */

if(gps){

 gps.addEventListener("click",function(){

  if(!navigator.geolocation){
   alert("Location is not supported.");
   return;
  }

  gps.textContent="Getting location...";

  navigator.geolocation.getCurrentPosition(

   function(position){

    const lat=position.coords.latitude;
    const lon=position.coords.longitude;

    pickup.value=
     lat.toFixed(6)+", "+lon.toFixed(6);

    if(map){

     map.setView([lat,lon],16);

     if(marker){
      map.removeLayer(marker);
     }

     marker=L.marker([lat,lon])
      .addTo(map)
      .bindPopup("Your pickup location")
      .openPopup();

    }

    gps.textContent="📍 Location selected";

    calculateFare();

   },

   function(){

    gps.textContent="📍 Use my current location";

    alert("Please allow location access.");

   },

   {
    enableHighAccuracy:true,
    timeout:15000,
    maximumAge:0
   }

  );

 });

}


/* GENERAL DESTINATION SEARCH */

if(destination){

 destination.addEventListener("input",function(){

  clearTimeout(searchTimer);

  const q=this.value.trim();

  removeResults();

  if(q.length<2)return;

  searchTimer=setTimeout(function(){

   searchPlaces(q);

  },600);

 });

}


/* SEARCH ANY NEPAL LOCATION */

async function searchPlaces(q){

 try{

  const url=
   "https://nominatim.openstreetmap.org/search"+
   "?format=jsonv2"+
   "&q="+encodeURIComponent(q)+
   "&countrycodes=np"+
   "&limit=8"+
   "&addressdetails=1";

  const response=await fetch(url,{
   headers:{
    "Accept":"application/json"
   }
  });

  if(!response.ok)return;

  const places=await response.json();

  showResults(places);

 }catch(error){

  console.log("Search error:",error);

 }

}


/* SHOW SEARCH RESULTS */

function showResults(places){

 removeResults();

 if(!places.length){

  const box=document.createElement("div");

  box.id="placeResults";

  box.innerHTML=
   "<div class='place-item'>"+
   "No location found"+
   "</div>";

  destination.parentNode.insertBefore(
   box,
   destination.nextSibling
  );

  return;
 }

 const box=document.createElement("div");

 box.id="placeResults";

 places.forEach(function(place){

  const button=document.createElement("button");

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

  button.addEventListener("click",function(){

   destination.value=name;

   const lat=parseFloat(place.lat);
   const lon=parseFloat(place.lon);

   if(map){

    map.setView([lat,lon],16);

    if(marker){
     map.removeLayer(marker);
    }

    marker=L.marker([lat,lon])
     .addTo(map)
     .bindPopup(safe(name))
     .openPopup();

   }

   removeResults();

   calculateFare();

  });

  box.appendChild(button);

 });

 destination.parentNode.insertBefore(
  box,
  destination.nextSibling
 );

}


/* PLACE ICON */

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

 if(text.includes("beach"))
  return "🏖️";

 if(text.includes("temple")||
    text.includes("church")||
    text.includes("mosque"))
  return "🛕";

 if(text.includes("school")||
    text.includes("college")||
    text.includes("university"))
  return "🏫";

 if(text.includes("airport"))
  return "✈️";

 if(text.includes("park"))
  return "🌳";

 return "📍";

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


/* REMOVE RESULTS */

function removeResults(){

 const old=document.getElementById("placeResults");

 if(old){
  old.remove();
 }

}


/* FARE */

function calculateFare(){

 if(!pickup.value||!destination.value){

  fare.textContent="--";

  return;

 }

 const prices={
  Bike:50,
  Car:100,
  "Tuk Tuk":80
 };

 fare.textContent="NPR "+prices[vehicle];

}


pickup.addEventListener(
 "input",
 calculateFare
);


/* REQUEST RIDE */

if(request){

 request.addEventListener("click",function(){

  if(!pickup.value){

   alert("Please select your pickup location.");

   return;

  }

  if(!destination.value){

   alert("Please select a destination.");

   return;

  }

  alert(
   "Ride request ready\n\n"+
   "Vehicle: "+vehicle+
   "\nFare: "+fare.textContent
  );

 });

}


/* CANCEL */

if(cancel){

 cancel.addEventListener("click",function(){

  pickup.value="";
  destination.value="";
  fare.textContent="--";

  removeResults();

  if(marker&&map){

   map.removeLayer(marker);
   marker=null;

  }

  if(gps){

   gps.textContent=
    "📍 Use my current location";

  }

 });

 }
