const pickup=document.getElementById("pickup");
const destination=document.getElementById("destination");
const fare=document.getElementById("fare");

const map=L.map("map").setView([27.7172,85.3240],13);

L.tileLayer(
 "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
 {attribution:"© OpenStreetMap contributors"}
).addTo(map);

let marker=null;
let vehicle="Bike";
let destinationTimer=null;

const placeBox=document.createElement("div");
placeBox.id="placeResults";
destination.parentNode.insertBefore(placeBox,destination.nextSibling);

document.querySelectorAll(".vehicle").forEach(btn=>{
 btn.onclick=()=>{
  document.querySelectorAll(".vehicle")
   .forEach(x=>x.classList.remove("active"));

  btn.classList.add("active");
  vehicle=btn.dataset.type;
  calculateFare();
 };
});

document.getElementById("gps").onclick=()=>{
 navigator.geolocation.getCurrentPosition(
  p=>{
   const lat=p.coords.latitude;
   const lon=p.coords.longitude;

   pickup.value=lat.toFixed(6)+", "+lon.toFixed(6);

   map.setView([lat,lon],16);

   if(marker) map.removeLayer(marker);

   marker=L.marker([lat,lon])
    .addTo(map)
    .bindPopup("Your pickup location")
    .openPopup();

   calculateFare();
  },
  ()=>{
   alert("Please allow location access.");
  },
  {
   enableHighAccuracy:true,
   timeout:10000,
   maximumAge:0
  }
 );

};

destination.addEventListener("input",()=>{
 clearTimeout(destinationTimer);

 const q=destination.value.trim();

 if(q.length<2){
  placeBox.innerHTML="";
  return;
 }

 destinationTimer=setTimeout(()=>{
  searchPlaces(q);
 },500);
});


async function searchPlaces(q){

 placeBox.innerHTML="<div class='place-item'>Searching places...</div>";

 try{

  const url=
   "https://nominatim.openstreetmap.org/search"+
   "?format=jsonv2"+
   "&addressdetails=1"+
   "&namedetails=1"+
   "&limit=8"+
   "&countrycodes=np"+
   "&layer=poi,address,natural,manmade"+
   "&q="+encodeURIComponent(q);

  const r=await fetch(url,{
   headers:{
    "Accept":"application/json"
   }
  });

  const places=await r.json();

  placeBox.innerHTML="";

  if(!places.length){
   placeBox.innerHTML=
    "<div class='place-item'>No places found</div>";
   return;
  }

  places.forEach(place=>{

   const item=document.createElement("button");
   item.type="button";
   item.className="place-item";

   const icon=getIcon(place);

   item.innerHTML=
    "<b>"+icon+" "+escapeHTML(
     place.name || place.display_name.split(",")[0]
    )+"</b>"+
    "<small>"+escapeHTML(
     place.display_name
    )+"</small>";

   item.onclick=()=>{

    destination.value=
     place.name || place.display_name;

    const lat=parseFloat(place.lat);
    const lon=parseFloat(place.lon);

    map.setView([lat,lon],16);

    if(marker) map.removeLayer(marker);

    marker=L.marker([lat,lon])
     .addTo(map)
     .bindPopup(
      escapeHTML(
       place.name || place.display_name
      )
     )
     .openPopup();

    placeBox.innerHTML="";

    calculateFare();
   };

   placeBox.appendChild(item);
  });

 }catch(error){

  placeBox.innerHTML=
   "<div class='place-item'>Place search unavailable</div>";
 }
}


function getIcon(place){

 const text=(
  (place.name||"")+" "+
  (place.type||"")+" "+
  (place.category||"")
 ).toLowerCase();

 if(text.includes("hotel")||text.includes("motel"))
  return "🏨";

 if(text.includes("bank")||text.includes("atm"))
  return "🏦";

 if(
  text.includes("hospital")||
  text.includes("clinic")||
  text.includes("medical")||
  text.includes("pharmacy")
 )
  return "🏥";

 if(
  text.includes("bus")||
  text.includes("station")||
  text.includes("terminal")
 )
  return "🚌";

 if(
  text.includes("mall")||
  text.includes("shopping")||
  text.includes("market")
 )
  return "🏬";

 if(
  text.includes("restaurant")||
  text.includes("cafe")||
  text.includes("food")
 )
  return "🍽️";

 if(
  text.includes("government")||
  text.includes("office")
 )
  return "🏛️";

 if(
  text.includes("bridge")
 )
  return "🌉";

 if(
  text.includes("statue")||
  text.includes("monument")
 )
  return "🗿";

 if(
  text.includes("beach")
 )
  return "🏖️";

 if(
  text.includes("temple")||
  text.includes("church")||
  text.includes("mosque")
 )
  return "🛕";

 if(
  text.includes("school")||
  text.includes("college")||
  text.includes("university")
 )
  return "🏫";

 if(
  text.includes("airport")
 )
  return "✈️";

 return "📍";
}


function escapeHTML(text){

 return String(text)
  .replaceAll("&","&amp;")
  .replaceAll("<","&lt;")
  .replaceAll(">","&gt;")
  .replaceAll('"',"&quot;")
  .replaceAll("'","&#039;");
}


function calculateFare(){

 if(!pickup.value||!destination.value){
  fare.textContent="--";
  return;
 }

 const price={
  Bike:50,
  Car:100,
  "Tuk Tuk":80
 };

 fare.textContent="NPR "+price[vehicle];
}


pickup.oninput=calculateFare;


document.getElementById("request").onclick=()=>{

 if(!pickup.value||!destination.value){
  alert("Enter pickup and destination first.");
  return;
 }

 alert(
  "Ride request ready\n"+
  "Vehicle: "+vehicle+
  "\nFare: "+fare.textContent
 );
};


document.getElementById("cancel").onclick=()=>{

 pickup.value="";
 destination.value="";
 fare.textContent="--";
 placeBox.innerHTML="";

 if(marker){
  map.removeLayer(marker);
  marker=null;
 }
};
