async function loadPayments(){

const {data,error}=await db
.from("rides")
.select(`
id,
fare,
driver_earnings,
admin_earnings,
payment_method,
status,
created_at
`)
.order("created_at",{ascending:false})
.limit(100);

const box=document.getElementById("paymentList");

if(error){
box.innerHTML="<p>"+error.message+"</p>";
return;
}

if(!data.length){
box.innerHTML="<p>No payment records.</p>";
return;
}

box.innerHTML=data.map(r=>`
<div class="item">
<b>Ride #${r.id}</b>
<p>Fare: Rs. ${r.fare||0}</p>
<p>Driver: Rs. ${r.driver_earnings||0}</p>
<p>Rydo: Rs. ${r.admin_earnings||0}</p>
<p>Method: ${r.payment_method||"-"}</p>
<p>Status: ${r.status}</p>
</div>
`).join("");
}

window.loadPayments=loadPayments;

document.querySelector('[data-open="payments"]')
.onclick=loadPayments;
