async function loadPassengers(){

const {data,error}=await db
.from("profiles")
.select("id,full_name,phone,created_at")
.eq("role","passenger")
.order("created_at",{ascending:false});

const box=document.getElementById("passengerList");

if(error){
box.innerHTML="<p>"+error.message+"</p>";
return;
}

if(!data.length){
box.innerHTML="<p>No passengers found.</p>";
return;
}

box.innerHTML=data.map(p=>`
<div class="item">
<b>${p.full_name||"Passenger"}</b>
<p>Phone: ${p.phone||"-"}</p>
<p>Joined: ${new Date(p.created_at).toLocaleDateString()}</p>
</div>
`).join("");
}

window.loadPassengers=loadPassengers;

document.querySelector('[data-open="passengers"]')
.onclick=loadPassengers;
