const pickup=document.getElementById("pickup");
const destination=document.getElementById("destination");
const fare=document.getElementById("fare");
const request=document.getElementById("request");
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

 const price={
  Bike:50,
  Car:100,
  "Tuk Tuk":80
 };

 fare.textContent="NPR "+price[vehicle];
}

pickup.oninput=calculateFare;
destination.oninput=calculateFare;

document.getElementById("gps").onclick=()=>{
 navigator.geolocation.getCurrentPosition(
  p=>{
   pickup.value=
    p.coords.latitude.toFixed(6)+", "+
    p.coords.longitude.toFixed(6);

   calculateFare();
  },
  ()=>{
   alert("Please allow location access.");
  }
 );
};

request.onclick=()=>{
 if(!pickup.value||!destination.value){
  alert("Enter pickup and destination first.");
  return;
 }

 alert(
  "Ride request ready\n\n"+
  "Vehicle: "+vehicle+
  "\nFare: "+fare.textContent
 );
};

document.getElementById("cancel").onclick=()=>{
 pickup.value="";
 destination.value="";
 fare.textContent="--";
};
