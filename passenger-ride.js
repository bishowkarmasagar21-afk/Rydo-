/* RYDO PASSENGER RIDE SYSTEM */

let map;
let pickupMarker;
let destinationMarker;
let routeLine;
let pickupCoords;
let destinationCoords;

const vehicleRates={
  bike:{base:25,km:14},
  car:{base:60,km:25},
  tuk_tuk:{base:45,km:18}
};

function loadMap(){
  const box=document.querySelector(".map");
  if(!box)return;

  box.innerHTML="";
  box.id="rydoMap";

  const css=document.createElement("link");
  css.rel="stylesheet";
  css.href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css";
  document.head.appendChild(css);

  const js=document.createElement("script");
  js.src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js";

  js.onload=()=>{
    map=L.map("rydoMap").setView([27.7172,85.3240],13);

    L.tileLayer(
      "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
      {maxZoom:19,attribution:"© OpenStreetMap"}
    ).addTo(map);

    setTimeout(()=>map.invalidateSize(),300);
  };

  document.body.appendChild(js);
}

async function searchPlace(q){
  if(!q||q.length<3)return;

  const url=
    "https://nominatim.openstreetmap.org/search?format=json"+
    "&addressdetails=1&limit=5&countrycodes=np&q="+
    encodeURIComponent(q);

  try{
    const r=await fetch(url,{
      headers:{"Accept":"application/json"}
    });

    const places=await r.json();

    const input=document.getElementById("destination");
    if(!input)return;

    let old=document.getElementById("suggestions");

    if(old)old.remove();

    if(!places.length)return;

    const list=document.createElement("div");
    list.id="suggestions";

    list.style.cssText=
      "background:#fff;color:#111;border-radius:10px;"+
      "margin-top:2px;overflow:hidden;position:relative;z-index:9999";

    places.forEach(p=>{
      const item=document.createElement("div");

      item.textContent=p.display_name;

      item.style.cssText=
        "padding:12px;border-bottom:1px solid #ddd;"+
        "cursor:pointer;font-size:13px";

      item.onclick=()=>{
        input.value=p.display_name;

        destinationCoords=[
          Number(p.lat),
          Number(p.lon)
        ];

        list.remove();

        if(map){
          if(destinationMarker)
            map.removeLayer(destinationMarker);

          destinationMarker=L.marker(destinationCoords)
            .addTo(map)
            .bindPopup("Destination")
            .openPopup();

          map.setView(destinationCoords,15);
        }

        if(pickupCoords)
          drawRoute();
      };

      list.appendChild(item);
    });

    input.parentElement.appendChild(list);

  }catch(e){
    console.log("Search error",e);
  }
}

async function drawRoute(){
  if(!pickupCoords||!destinationCoords)return;

  const url=
    "https://router.project-osrm.org/route/v1/driving/"+
    pickupCoords[1]+","+pickupCoords[0]+";"+
    destinationCoords[1]+","+destinationCoords[0]+
    "?overview=full&geometries=geojson";

  try{
    const r=await fetch(url);
    const data=await r.json();

    if(!data.routes||!data.routes.length)return;

    const route=data.routes[0];

    const km=route.distance/1000;

    if(routeLine)map.removeLayer(routeLine);

    routeLine=L.geoJSON(route.geometry,{
      style:{
        color:"#ff8124",
        weight:6
      }
    }).addTo(map);

    map.fitBounds(routeLine.getBounds(),{
      padding:[25,25]
    });

    showFare(km);

  }catch(e){
    console.log("Route error",e);
  }
}

function showFare(km){
  let type=typeof selectedVehicle==="string"
    ?selectedVehicle
    :"bike";

  const rate=vehicleRates[type]||vehicleRates.bike;

  const fare=Math.round(rate.base+(km*rate.km));

  let box=document.getElementById("fareBox");

  if(!box){
    box=document.createElement("div");
    box.id="fareBox";

    box.style.cssText=
      "margin-top:15px;padding:15px;background:#142638;"+
      "border:1px solid #ff8124;border-radius:12px";

    const rideCard=document.getElementById("ride");

    if(rideCard)
      rideCard.querySelector(".card").appendChild(box);
  }

  box.innerHTML=
    "<b>Estimated fare</b><br>"+
    "<span style='font-size:25px;color:#ff8124'>NPR "+
    fare+"</span><br>"+
    "<small>Distance: "+km.toFixed(1)+" km</small>";

  window.rydoFare=fare;
  window.rydoDistance=km;
}

window.locationGPS=function(){
  if(!navigator.geolocation){
    document.getElementById("rideMsg").textContent=
      "Location is not supported.";
    return;
  }

  document.getElementById("rideMsg").textContent=
    "Finding your location...";

  navigator.geolocation.getCurrentPosition(
    async p=>{
      pickupCoords=[
        p.coords.latitude,
        p.coords.longitude
      ];

      document.getElementById("pickup").value=
        p.coords.latitude.toFixed(6)+", "+
        p.coords.longitude.toFixed(6);

      if(map){
        if(pickupMarker)
          map.removeLayer(pickupMarker);

        pickupMarker=L.marker(pickupCoords)
          .addTo(map)
          .bindPopup("Pickup")
          .openPopup();

        map.setView(pickupCoords,16);
      }

      document.getElementById("rideMsg").textContent=
        "Pickup location found.";

      if(destinationCoords)
        drawRoute();
    },
    ()=>{
      document.getElementById("rideMsg").textContent=
        "Could not get your location.";
    },
    {
      enableHighAccuracy:true,
      timeout:15000,
      maximumAge:5000
    }
  );
};

window.vehicle=function(type,button){
  selectedVehicle=type;

  document.querySelectorAll(".v")
    .forEach(x=>x.classList.remove("active"));

  button.classList.add("active");

  if(window.rydoDistance)
    showFare(window.rydoDistance);
};

window.requestRide=async function(){

  const pickup=document.getElementById("pickup").value.trim();
  const destination=document.getElementById("destination").value.trim();
  const payment=document.getElementById("payment").value;

  const msg=document.getElementById("rideMsg");

  if(!pickup||!destination){
    msg.textContent="Enter pickup and destination.";
    return;
  }

  const {
    data:{user}
  }=await db.auth.getUser();

  if(!user){
    msg.textContent="Please login first.";
    return;
  }

  if(!pickupCoords||!destinationCoords){
    msg.textContent=
      "Please choose your pickup and destination on the map.";
    return;
  }

  msg.textContent="Sending ride request...";

  const {error}=await db.from("rides").insert({
    passenger_id:user.id,
    pickup:pickup,
    destination:destination,
    vehicle_type:selectedVehicle,
    distance_km:window.rydoDistance||0,
    fare:window.rydoFare||0,
    payment_method:payment,
    status:"requested",
    pickup_lat:pickupCoords[0],
    pickup_lon:pickupCoords[1],
    destination_lat:destinationCoords[0],
    destination_lon:destinationCoords[1]
  });

  if(error){
    msg.textContent="Ride request failed: "+error.message;
    return;
  }

  msg.textContent=
    "🚕 Ride requested. Looking for a verified driver...";
};

document.addEventListener("DOMContentLoaded",()=>{

  loadMap();

  const destination=document.getElementById("destination");

  if(destination){

    destination.addEventListener("input",()=>{
      searchPlace(destination.value.trim());
    });

  }

});
