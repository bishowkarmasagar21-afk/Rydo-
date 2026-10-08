let driverWatch=null;

function startDriverLocation(){
 if(!navigator.geolocation)return;

 driverWatch=navigator.geolocation.watchPosition(async pos=>{
  if(!window.driverUser)return;

  const lat=pos.coords.latitude;
  const lon=pos.coords.longitude;

  window.driverLat=lat;
  window.driverLon=lon;

  // Location can later be connected to the active ride.
 },err=>{
  console.log("GPS:",err.message);
 },{
  enableHighAccuracy:true,
  maximumAge:5000,
  timeout:15000
 });
}

function stopDriverLocation(){
 if(driverWatch!==null){
  navigator.geolocation.clearWatch(driverWatch);
  driverWatch=null;
 }
}

window.startDriverLocation=startDriverLocation;
window.stopDriverLocation=stopDriverLocation;
