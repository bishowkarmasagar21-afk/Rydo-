async function loadAdminDashboard(){

const {data:p}=await db
.from("profiles")
.select("role,is_verified,is_online");

if(p){
let passengers=0;
let drivers=0;
let pending=0;
let online=0;

p.forEach(x=>{
if(x.role==="passenger")passengers++;

if(x.role==="driver"){
drivers++;
if(x.is_verified===false)pending++;
if(x.is_online===true)online++;
}
});

document.getElementById("passengers").textContent=passengers;
document.getElementById("drivers").textContent=drivers;
document.getElementById("pending").textContent=pending;
document.getElementById("online").textContent=online;
}

const {data:r}=await db
.from("rides")
.select("status,admin_earnings");

if(r){
let active=0,completed=0,cancelled=0,earnings=0;

r.forEach(x=>{
if(["requested","accepted","started"].includes(x.status))
active++;

if(x.status==="completed"){
completed++;
earnings+=Number(x.admin_earnings||0);
}

if(x.status==="cancelled")cancelled++;
});

document.getElementById("active").textContent=active;
document.getElementById("completed").textContent=completed;
document.getElementById("cancelled").textContent=cancelled;
document.getElementById("earnings").textContent="Rs. "+earnings;
}
}

window.loadAdminDashboard=loadAdminDashboard;

document.querySelectorAll("[data-open]").forEach(btn=>{
btn.onclick=()=>{
document.querySelectorAll(".panel")
.forEach(x=>x.classList.add("hide"));

document.getElementById(btn.dataset.open)
.classList.remove("hide");
};
});
