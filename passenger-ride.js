const pickup=document.getElementById("pickup");
const destination=document.getElementById("destination");
const fare=document.getElementById("fare");
let vehicle="Bike";

document.querySelectorAll(".vehicle").forEach(btn=>{
 btn.onclick=()=>{
  document.querySelectorAll(".vehicle")
  .forEach(x=>x.classList.remove("active"));

  btn.classList.add("active");
  vehicle=btn.dataset.type;
  calculateFare();
 };
});

function calculateFare(){
 if(!pickup.value||!destination.value){
  fare.textContent="--";
  return;
 }

 const rates={
  Bike:50,
  Car:100,
  "Tuk Tuk":80
 };

 fare.textContent="NPR "+rates[vehicle];
}

pickup.oninput=calculateFare;
destination.oninput=calculateFare;

document.getElementById("gps").onclick=()=>{
 if(!navigator.geolocation){
  alert("GPS is not supported.");
  return;
 }

 navigator.geolocation.getCurrentPosition(
  p=>{
   pickup.value=
   p.coords.latitude.toFixed(6)+", "+
   p.coords.longitude.toFixed(6);

   calculateFare();
  },
  ()=>{
   alert("Unable to get your location.");
  }
 );
};

document.getElementById("request").onclick=()=>{
 if(!pickup.value||!destination.value){
  alert("Please enter pickup and destination.");
  return;
 }

 alert(
  "Ride request created.\n"+
  "Vehicle: "+vehicle+
  "\nFare: "+fare.textContent
 );
};

document.getElementById("cancel").onclick=()=>{
 pickup.value="";
 destination.value="";
 fare.textContent="--";
};
