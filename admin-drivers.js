async function loadDrivers(){

const {data,error}=await db
.from("profiles")
.select("id,full_name,phone,driver_license,is_verified,is_online,created_at")
.eq("role","driver")
.order("created_at",{ascending:false});

const box=document.getElementById("driverList");

if(error){
box.innerHTML="<p>"+error.message+"</p>";
return;
}

if(!data.length){
box.innerHTML="<p>No drivers found.</p>";
return;
}

box.innerHTML=data.map(d=>`
<div class="item">
<b>${d.full_name||"Driver"}</b>
<p>Phone: ${d.phone||"-"}</p>
<p>License: ${d.driver_license||"-"}</p>
<p>Status: ${d.is_verified?"Verified":"Pending"}</p>
<p>Online: ${d.is_online?"Yes":"No"}</p>
<button class="approve"
onclick="verifyDriver('${d.id}',true)">
APPROVE
</button>
<button class="reject"
onclick="verifyDriver('${d.id}',false)">
REJECT
</button>
</div>
`).join("");
}

async function verifyDriver(id,status){

const {error}=await db
.from("profiles")
.update({is_verified:status})
.eq("id",id);

if(error){
alert(error.message);
return;
}

loadDrivers();
loadAdminDashboard();
}

window.loadDrivers=loadDrivers;
window.verifyDriver=verifyDriver;

document.addEventListener("DOMContentLoaded",loadDrivers);
