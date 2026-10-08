async function loadFares(){

const {data,error}=await db
.from("fare_rules")
.select("*")
.order("vehicle_type");

const box=document.getElementById("fareList");

if(error){
box.innerHTML="<p>"+error.message+"</p>";
return;
}

box.innerHTML=(data||[]).map(f=>`
<div class="item">
<h3>${f.vehicle_type}</h3>

<input id="base_${f.vehicle_type}"
value="${f.base_fare||0}"
placeholder="Base fare">

<input id="km_${f.vehicle_type}"
value="${f.per_km_fare||0}"
placeholder="Per km">

<input id="com_${f.vehicle_type}"
value="${f.platform_commission_percent||0}"
placeholder="Commission %">

<button onclick="saveFare('${f.vehicle_type}')">
SAVE
</button>
</div>
`).join("");
}

async function saveFare(type){

const base=Number(document.getElementById("base_"+type).value);
const km=Number(document.getElementById("km_"+type).value);
const com=Number(document.getElementById("com_"+type).value);

const {error}=await db
.from("fare_rules")
.update({
base_fare:base,
per_km_fare:km,
platform_commission_percent:com
})
.eq("vehicle_type",type);

if(error){
alert(error.message);
return;
}

alert("Fare updated.");
}

window.loadFares=loadFares;
window.saveFare=saveFare;

document.querySelector('[data-open="fares"]')
.onclick=loadFares;
