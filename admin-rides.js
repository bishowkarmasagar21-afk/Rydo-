async function loadRides(){

const {data,error}=await db
.from("rides")
.select(`
id,
pickup_location,
destination,
vehicle_type,
distance_km,
fare,
status,
payment_method,
created_at
`)
.order("created_at",{ascending:false})
.limit(100);

const box=document.getElementById("rideList");

if(error){
box.innerHTML="<p>"+error.message+"</p>";
return;
}

if(!data.length){
box.innerHTML="<p>No rides found.</p>";
return;
}

box.innerHTML=data.map(r=>`
<div class="item">
<b>Ride #${r.id}</b>
<p>${r.pickup_location||"-"} → ${r.destination||"-"}</p>
<p>Vehicle: ${r.vehicle_type||"-"}</p>
<p>Distance: ${r.distance_km||0} km</p>
<p>Fare: Rs. ${r.fare||0}</p>
<p>Payment: ${r.payment_method||"-"}</p>
<p>Status: <b>${r.status}</b></p>
</div>
`).join("");
}

window.loadRides=loadRides;

document.querySelector('[data-open="rides"]')
.onclick=loadRides;
