```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="theme-color" content="#08111b">
<title>Rryd Admin</title>

<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>

<style>
:root{
 --bg:#08111b;--panel:#142638;--panel2:#192f43;
 --text:#f1f5f9;--muted:#9aafc3;--border:#2b4053;
 --orange:#ff7417;--green:#20b77a;--red:#ff5366;
 --blue:#5b9cff;--shadow:0 10px 30px #0002
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);
 font:14px/1.5 system-ui,-apple-system,Segoe UI,sans-serif}
button,input,select{font:inherit}
button{cursor:pointer;border:0;border-radius:9px;padding:10px 13px;
 background:var(--orange);color:#fff;font-weight:650}
button:disabled{opacity:.5;cursor:not-allowed}
button.secondary{background:var(--panel2);border:1px solid var(--border)}
button.danger{background:#51232d;border:1px solid #79303d}
button.success{background:#15563e}
input,select{width:100%;background:var(--bg);color:var(--text);
 border:1px solid var(--border);border-radius:9px;padding:11px}
label{display:block;color:var(--muted);font-size:12px;margin-bottom:5px}
h1,h2,h3,p{margin-top:0}
h1{font-size:25px;margin-bottom:3px}
h2{font-size:18px}
small,.muted{color:var(--muted)}
.hidden{display:none!important}
#loginPage{min-height:100vh;display:grid;place-items:center;padding:20px}
.login-card{width:min(420px,100%);background:var(--panel);
 border:1px solid var(--border);border-radius:20px;padding:28px;box-shadow:var(--shadow)}
.brand{display:flex;align-items:center;gap:12px;margin-bottom:25px}
.logo{width:46px;height:46px;border-radius:13px;background:var(--orange);
 display:grid;place-items:center;font-size:22px;font-weight:900}
.brand h1{font-size:23px}
.field{margin:14px 0}
#app{min-height:100vh}
.topbar{height:66px;position:sticky;top:0;z-index:5;
 background:var(--panel);border-bottom:1px solid var(--border);
 display:flex;align-items:center;justify-content:space-between;padding:0 20px;gap:12px}
.top-brand{display:flex;align-items:center;gap:10px;font-size:19px;font-weight:800}
.top-brand span{color:var(--orange)}
.layout{display:grid;grid-template-columns:225px minmax(0,1fr);min-height:calc(100vh - 66px)}
.sidebar{padding:16px 12px;border-right:1px solid var(--border);background:var(--bg)}
.navbtn{display:flex;gap:11px;align-items:center;width:100%;text-align:left;
 background:transparent;color:var(--muted);margin-bottom:5px}
.navbtn.active{background:var(--orange);color:white}
.main{padding:24px;min-width:0;max-width:1600px;width:100%;margin:0 auto}
.pagehead{display:flex;justify-content:space-between;align-items:center;gap:12px;margin-bottom:22px}
.grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px;margin-bottom:20px}
.card{background:var(--panel);border:1px solid var(--border);border-radius:14px;padding:17px;min-width:0}
.stat-label{color:var(--muted);font-size:12px}
.stat-value{font-size:25px;font-weight:800;margin-top:8px;overflow-wrap:anywhere}
.stat-icon{color:var(--orange);font-size:20px}
.row{display:flex;gap:10px;align-items:center;flex-wrap:wrap}
.between{display:flex;justify-content:space-between;align-items:center;gap:12px}
.filters{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px;align-items:end}
.table-wrap{overflow:auto;width:100%;border:1px solid var(--border);border-radius:12px}
table{width:100%;border-collapse:collapse;white-space:nowrap}
th,td{text-align:left;padding:12px;border-bottom:1px solid var(--border)}
th{background:var(--panel2);color:var(--muted);font-size:12px}
td{max-width:330px;overflow-wrap:anywhere}
tbody tr:last-child td{border-bottom:0}
.badge{display:inline-block;border-radius:30px;padding:4px 9px;
 font-size:11px;font-weight:700;background:#26384a;color:#dce7f2}
.badge.good{background:#164c38;color:#9af0c6}
.badge.warn{background:#5a411d;color:#ffd58b}
.badge.bad{background:#592632;color:#ffabb5}
.notice{padding:12px 14px;border:1px solid var(--border);background:var(--panel2);
 border-radius:10px;margin-bottom:16px;white-space:pre-wrap}
.notice.error{border-color:#a53d4c;color:#ffb5bf}
.notice.ok{border-color:#257c5a;color:#a6f0cb}
.section{margin-bottom:18px}
.section h2{margin-bottom:13px}
.chart{width:100%;height:260px;display:block}
.chart-legend{display:flex;gap:15px;flex-wrap:wrap;color:var(--muted);font-size:12px}
.dot{display:inline-block;width:9px;height:9px;border-radius:50%;background:var(--orange);margin-right:5px}
.actions{display:flex;gap:7px;align-items:center;flex-wrap:wrap}
.empty{text-align:center;color:var(--muted);padding:28px}
.mobile-menu{display:none}
hr{border:0;border-top:1px solid var(--border);margin:18px 0}
@media(max-width:1000px){
 .grid{grid-template-columns:repeat(2,minmax(0,1fr))}
 .filters{grid-template-columns:repeat(2,minmax(0,1fr))}
 .layout{grid-template-columns:190px minmax(0,1fr)}
 .main{padding:17px}
}
@media(max-width:680px){
 .topbar{padding:0 12px}
 .mobile-menu{display:inline-block}
 .layout{display:block}
 .sidebar{display:none;border-right:0;border-bottom:1px solid var(--border)}
 .sidebar.open{display:block}
 .main{padding:14px}
 .grid{gap:9px}
 .card{padding:12px}
 .stat-value{font-size:21px}
 .filters{grid-template-columns:1fr}
 .pagehead{align-items:flex-start}
}
@media print{
 body{background:#fff!important;color:#111!important}
 .topbar,.sidebar,.no-print,#loginPage{display:none!important}
 .layout{display:block}
 .main{padding:0;max-width:none}
 .card,.table-wrap{background:#fff!important;border:1px solid #bbb!important;
  color:#111!important;break-inside:avoid}
 .muted,.stat-label,th{color:#444!important}
 th{background:#eee!important}
 input,select,button{display:none!important}
 .grid{grid-template-columns:repeat(3,1fr)}
 #reportTable{font-size:10px;white-space:normal}
 #reportTable td,#reportTable th{padding:5px;white-space:normal}
}
</style>
</head>

<body>
<section id="loginPage">
 <div class="login-card">
  <div class="brand">
   <div class="logo">R</div>
   <div><h1>Rryd Admin</h1><div class="muted">Platform control center</div></div>
  </div>
  <h2>Administrator sign in</h2>
  <p class="muted">Sign in using your authorized Rryd admin account.</p>
  <form id="loginForm">
   <div class="field"><label for="email">Email address</label>
    <input id="email" type="email" autocomplete="username" required></div>
   <div class="field"><label for="password">Password</label>
    <input id="password" type="password" autocomplete="current-password" required></div>
   <button id="loginBtn" type="submit" style="width:100%">Sign in securely</button>
  </form>
  <p style="margin-top:15px"><button id="forgotBtn" class="secondary" style="width:100%">Forgot password?</button></p>
  <div id="loginMessage" class="notice hidden"></div>
  <p class="muted" style="font-size:11px;margin-bottom:0">Access is restricted to accounts whose database profile has the admin role. Registration is not available here.</p>
 </div>
</section>

<section id="app" class="hidden">
 <header class="topbar">
  <div class="row">
   <button id="menuBtn" class="secondary mobile-menu" aria-label="Toggle navigation">☰</button>
   <div class="top-brand"><div class="logo" style="width:36px;height:36px">R</div>Rryd <span>Admin</span></div>
  </div>
  <div class="row">
   <span id="adminEmail" class="muted"></span>
   <button id="refreshBtn" class="secondary">↻ Refresh</button>
   <button id="logoutBtn" class="danger">Sign out</button>
  </div>
 </header>

 <div class="layout">
  <aside id="sidebar" class="sidebar">
   <button class="navbtn active" data-page="Overview">▦ Overview</button>
   <button class="navbtn" data-page="Reports">▤ Reports & analytics</button>
   <button class="navbtn" data-page="Drivers">♙ Drivers</button>
   <button class="navbtn" data-page="Passengers">♧ Passengers</button>
   <button class="navbtn" data-page="Vehicles">▣ Vehicles</button>
   <button class="navbtn" data-page="Rides">↗ Rides</button>
   <button class="navbtn" data-page="Fare Rules">＄ Fare rules</button>
  </aside>
  <main id="main" class="main">
   <div class="empty">Loading admin dashboard…</div>
  </main>
 </div>
</section>

<script>
(() => {
"use strict";

/* Rryd Supabase configuration */
const SUPABASE_URL = "https://kqtvuorasqyzjbnlkkxs.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_zZFJiy0YWZgOXFesVuAQcA_wd7rleMb";

const $ = id => document.getElementById(id);
const esc = value => String(value ?? "").replace(/[&<>"']/g, c => ({
 "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"
})[c]);
const money = n => "NPR " + Number(n || 0).toLocaleString("en-IN", {
 minimumFractionDigits:2,maximumFractionDigits:2
});
const fmtDate = v => {
 if (!v) return "—";
 const d = new Date(v);
 return Number.isNaN(d.getTime()) ? String(v) : d.toLocaleString();
};
const statusBadge = s => {
 const v = String(s || "unknown").toLowerCase();
 const cls = ["completed","approved","active","online"].includes(v) ? "good"
  : ["requested","pending","accepted","arriving","started","offline"].includes(v) ? "warn"
  : ["cancelled","rejected","suspended","failed"].includes(v) ? "bad" : "";
 return `<span class="badge ${cls}">${esc(s || "Unknown")}</span>`;
};
const {createClient} = window.supabase;
const db = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
 auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}
});

let currentUser = null;
let profile = null;
let currentPage = "Overview";
let cache = {profiles:[],rides:[],vehicles:[],fares:[]};
let reportRows = [];
let reportLabel = "";
let reportChartData = [];
let reportSearch = "";
let reportKind = "All reports";
let chartMetric = "Revenue";
let chartInterval = "Daily";
let reportFrom = "";
let reportTo = "";
let reportLoaded = false;

function showMessage(target, message, type="") {
 const el = $(target);
 el.textContent = message;
 el.className = "notice" + (type ? " " + type : "");
 el.classList.remove("hidden");
}
function loginMessage(message,type="error") {
 showMessage("loginMessage",message,type);
}
function showLogin() {
 $("app").classList.add("hidden");
 $("loginPage").classList.remove("hidden");
}
function showApp() {
 $("loginPage").classList.add("hidden");
 $("app").classList.remove("hidden");
 $("adminEmail").textContent = currentUser?.email || "";
}
function errText(error) {
 return error?.message || String(error || "Unknown error");
}
function setBusy(button,busy,label) {
 if (!button) return;
 if (busy) {
  button.dataset.originalText = button.textContent;
  button.textContent = label || "Please wait…";
  button.disabled = true;
 } else {
  button.textContent = button.dataset.originalText || button.textContent;
  button.disabled = false;
 }
}

/* Never trust a local role flag: recheck the authenticated profile. */
async function checkAdmin(user) {
 const {data,error} = await db.from("profiles").select("*").eq("id",user.id).maybeSingle();
 if (error) throw new Error("Could not verify admin profile: " + error.message);
 if (!data || String(data.role || "").toLowerCase() !== "admin") {
  await db.auth.signOut();
  throw new Error("Access denied. This account's profiles.role is not admin. Ask the database administrator to verify the correct admin profile.");
 }
 if (data.is_suspended === true) {
  await db.auth.signOut();
  throw new Error("This admin account is suspended.");
 }
 profile = data;
 currentUser = user;
 showApp();
 await navigate("Overview");
}

async function loadTable(table, options={}) {
 let q = db.from(table).select("*");
 if (options.order) q = q.order(options.order,{ascending:options.ascending ?? false});
 if (options.from) q = q.gte(options.dateField || "created_at",options.from);
 if (options.toExclusive) q = q.lt(options.dateField || "created_at",options.toExclusive);
 if (options.limit) q = q.limit(options.limit);
 const {data,error} = await q;
 if (error) throw new Error(table + ": " + error.message);
 return data || [];
}
async function loadBaseData() {
 const results = await Promise.allSettled([
  loadTable("profiles",{order:"created_at",limit:5000}),
  loadTable("rides",{order:"created_at",limit:10000}),
  loadTable("vehicles",{order:"id",limit:5000}),
  loadTable("fare_rules",{order:"id",ascending:true,limit:100})
 ]);
 cache.profiles = results[0].status==="fulfilled" ? results[0].value : [];
 cache.rides = results[1].status==="fulfilled" ? results[1].value : [];
 cache.vehicles = results[2].status==="fulfilled" ? results[2].value : [];
 cache.fares = results[3].status==="fulfilled" ? results[3].value : [];
 return results.map((r,i)=>({name:["profiles","rides","vehicles","fare_rules"][i],
  error:r.status==="rejected" ? errText(r.reason) : null}));
}
function renderLoadWarnings(warnings) {
 const failed = warnings.filter(x=>x.error);
 if (!failed.length) return "";
 return `<div class="notice error">Some data could not be loaded. Check table permissions, names and RLS policies:\n${failed.map(x=>esc(x.name+": "+x.error)).join("\n")}</div>`;
}
function statCard(label,value,icon="•") {
 return `<div class="card"><div class="between"><span class="stat-label">${esc(label)}</span><span class="stat-icon">${icon}</span></div><div class="stat-value">${esc(value)}</div></div>`;
}
function pageHead(title,sub="") {
 return `<div class="pagehead"><div><h1>${esc(title)}</h1><div class="muted">${esc(sub)}</div></div></div>`;
}
function tableHTML(headers,rows,empty="No records found.") {
 return `<div class="table-wrap"><table><thead><tr>${headers.map(h=>`<th>${esc(h)}</th>`).join("")}</tr></thead><tbody>${
 rows.length ? rows.map(row=>`<tr>${row.map(cell=>`<td>${cell ?? ""}</td>`).join("")}</tr>`).join("")
 : `<tr><td colspan="${headers.length}" class="empty">${esc(empty)}</td></tr>`
 }</tbody></table></div>`;
}
function searchableBar(placeholder="Search records…") {
 return `<div class="field no-print"><label>Search</label><input id="tableSearch" placeholder="${esc(placeholder)}" value="${esc(reportSearch)}"></div>`;
}
function filterRows(rows) {
 const q = reportSearch.trim().toLowerCase();
 return q ? rows.filter(r=>JSON.stringify(r).toLowerCase().includes(q)) : rows;
}

async function navigate(page) {
 currentPage = page;
 document.querySelectorAll(".navbtn").forEach(b=>b.classList.toggle("active",b.dataset.page===page));
 $("sidebar").classList.remove("open");
 $("main").innerHTML = `<div class="empty">Loading ${esc(page)}…</div>`;
 try {
  if (page==="Overview") await renderOverview();
  else if (page==="Reports") renderReports();
  else if (page==="Drivers") renderDrivers();
  else if (page==="Passengers") renderPassengers();
  else if (page==="Vehicles") renderVehicles();
  else if (page==="Rides") renderRides();
  else if (page==="Fare Rules") renderFareRules();
 } catch(e) {
  $("main").innerHTML = `<div class="notice error">${esc(errText(e))}</div><button id="pageRetry">Try again</button>`;
  $("pageRetry")?.addEventListener("click",()=>navigate(currentPage));
 }
}

async function renderOverview() {
 const warnings = await loadBaseData();
 const drivers = cache.profiles.filter(p=>p.role==="driver");
 const passengers = cache.profiles.filter(p=>p.role==="passenger");
 const completed = cache.rides.filter(r=>r.status==="completed");
 const active = cache.rides.filter(r=>["requested","accepted","arriving","started"].includes(String(r.status).toLowerCase()));
 const gross = completed.reduce((s,r)=>s+Number(r.final_fare ?? r.actual_fare ?? r.fare ?? 0),0);
 $("main").innerHTML = pageHead("Dashboard","Live records from your Rryd Supabase database")+
  renderLoadWarnings(warnings)+
  `<div class="grid">${statCard("Total rides",cache.rides.length,"↗")}${statCard("Drivers",drivers.length,"♙")}${statCard("Passengers",passengers.length,"♧")}${statCard("Completed ride fares",money(gross),"＄")}</div>`+
  `<div class="grid">${statCard("Active / requested rides",active.length,"◷")}${statCard("Pending drivers",drivers.filter(p=>p.is_verified!==true).length,"!")}${statCard("Vehicles loaded",cache.vehicles.length,"▣")}${statCard("Fare rule types",cache.fares.length,"＄")}</div>`+
  `<div class="card section"><div class="between"><h2>Recent rides</h2><button class="secondary" id="goRides">View rides</button></div>`+
  tableHTML(["Ride ID","Status","Vehicle","Fare","Created"],cache.rides.slice(0,10).map(r=>[
   esc(r.id),statusBadge(r.status),esc(r.vehicle_type),esc(money(r.final_fare ?? r.actual_fare ?? r.fare)),esc(fmtDate(r.created_at))
  ]))+"</div>";
 $("goRides").onclick=()=>navigate("Rides");
}

function renderDrivers() {
 const drivers = filterRows(cache.profiles.filter(p=>p.role==="driver"));
 $("main").innerHTML = pageHead("Drivers","Review driver profiles and verification status")+
  `<div class="grid">${statCard("Total drivers",drivers.length)}${statCard("Verified",drivers.filter(p=>p.is_verified===true).length)}${statCard("Pending",drivers.filter(p=>p.is_verified!==true).length)}${statCard("Suspended",drivers.filter(p=>p.is_suspended===true).length)}</div>`+
  searchableBar("Search name, phone, email or profile ID")+
  tableHTML(["Name","Phone","Verified","Online","Suspended","Created","Actions"],drivers.map(p=>{
   const verified=p.is_verified===true;
   const suspended=p.is_suspended===true;
   return [esc(p.full_name||"—"),esc(p.phone||"—"),statusBadge(verified?"Verified":"Pending"),
    statusBadge(p.is_online?"Online":"Offline"),statusBadge(suspended?"Suspended":"Active"),
    esc(fmtDate(p.created_at)),
    `<div class="actions">${!verified?`<button data-action="approve-driver" data-id="${esc(p.id)}">Approve</button>`:""}
     <button class="${suspended?"success":"danger"}" data-action="suspend-profile" data-id="${esc(p.id)}" data-value="${suspended?"false":"true"}">${suspended?"Restore":"Suspend"}</button></div>`];
  }));
 bindSearch();
}
function renderPassengers() {
 const rows=filterRows(cache.profiles.filter(p=>p.role==="passenger"));
 $("main").innerHTML=pageHead("Passengers","Passenger profiles from Supabase")+
  `<div class="grid">${statCard("Passengers",rows.length)}${statCard("Suspended",rows.filter(p=>p.is_suspended===true).length)}</div>`+
  searchableBar("Search passenger name, phone or ID")+
  tableHTML(["Name","Phone","Status","Created","Account ID","Actions"],rows.map(p=>[
   esc(p.full_name||"—"),esc(p.phone||"—"),statusBadge(p.is_suspended?"Suspended":"Active"),
   esc(fmtDate(p.created_at)),esc(p.id),
   `<button class="${p.is_suspended?"success":"danger"}" data-action="suspend-profile" data-id="${esc(p.id)}" data-value="${p.is_suspended?"false":"true"}">${p.is_suspended?"Restore":"Suspend"}</button>`
  ]));
 bindSearch();
}
function renderVehicles() {
 const rows=filterRows(cache.vehicles);
 $("main").innerHTML=pageHead("Vehicles","Vehicle records and approval actions")+
  `<div class="notice">Approval actions use the existing approve_vehicle database function. If your vehicle table or function differs, the database error will be shown.</div>`+
  searchableBar("Search vehicle number, type, model or driver")+
  tableHTML(["Vehicle ID","Driver ID","Type","Number","Model","Approval","Actions"],rows.map(v=>{
   const approved= v.is_approved===true || v.approved===true || v.status==="approved";
   const id=v.id;
   return [esc(id),esc(v.driver_id||v.user_id||"—"),esc(v.vehicle_type||v.type||"—"),
    esc(v.vehicle_number||v.registration_number||v.plate_number||"—"),
    esc(v.model||"—"),statusBadge(approved?"Approved":"Pending"),
    !approved?`<button data-action="approve-vehicle" data-id="${esc(id)}">Approve</button>`:"—"];
  }));
 bindSearch();
}
function renderRides() {
 const rows=filterRows(cache.rides);
 $("main").innerHTML=pageHead("Rides","Review ride history and current statuses")+
  `<div class="grid">${statCard("All rides",cache.rides.length)}${statCard("Completed",cache.rides.filter(r=>r.status==="completed").length)}${statCard("Cancelled",cache.rides.filter(r=>r.status==="cancelled").length)}${statCard("Requested",cache.rides.filter(r=>r.status==="requested").length)}</div>`+
  searchableBar("Search ride ID, passenger ID, driver ID or status")+
  tableHTML(["Ride ID","Passenger ID","Driver ID","Vehicle","Status","Fare","Payment","Created"],rows.map(r=>[
   esc(r.id),esc(r.passenger_id||"—"),esc(r.driver_id||"—"),esc(r.vehicle_type||"—"),statusBadge(r.status),
   esc(money(r.final_fare ?? r.actual_fare ?? r.fare)),esc(r.payment_method||"—"),esc(fmtDate(r.created_at))
  ]));
 bindSearch();
}

function renderFareRules() {
 $("main").innerHTML=pageHead("Fare rules","Edit the live fare_rules table")+
  `<div class="notice">Changes are saved to Supabase. Confirm your database RLS policy permits this admin account to update fare_rules. Commission is a percentage.</div>`+
  (cache.fares.length ? cache.fares.map(f=>`
   <form class="card section fare-form" data-id="${esc(f.id)}">
    <h2>${esc(f.vehicle_type||f.type||("Fare rule "+f.id))}</h2>
    <div class="filters">
     <div><label>Base fare (NPR)</label><input name="base_fare" type="number" step=".01" min="0" value="${esc(f.base_fare??"0")}" required></div>
     <div><label>Fare per km (NPR)</label><input name="per_km_fare" type="number" step=".01" min="0" value="${esc(f.per_km_fare??"0")}" required></div>
     <div><label>Commission (%)</label><input name="platform_commission_percent" type="number" step=".01" min="0" max="100" value="${esc(f.platform_commission_percent??"15")}" required></div>
     <div><label>Rule active</label><select name="is_active"><option value="true" ${f.is_active!==false?"selected":""}>Active</option><option value="false" ${f.is_active===false?"selected":""}>Inactive</option></select></div>
    </div>
    <div class="row" style="margin-top:13px"><button type="submit">Save ${esc(f.vehicle_type||f.type||"fare rule")}</button><span class="muted" data-form-message></span></div>
   </form>`).join(""):`<div class="empty">No fare rules returned. Check the fare_rules table and permissions.</div>`);
 document.querySelectorAll(".fare-form").forEach(form=>form.addEventListener("submit",saveFareRule));
}

function validDateInput(value) {
 const m=/^(\d{4})\/(\d{2})\/(\d{2})$/.exec(value.trim());
 if(!m) return null;
 const d=new Date(Date.UTC(+m[1],+m[2]-1,+m[3]));
 if(d.getUTCFullYear()!==+m[1]||d.getUTCMonth()!==+m[2]-1||d.getUTCDate()!==+m[3]) return null;
 return d;
}
function dateText(d) {
 return d.getUTCFullYear()+"/"+String(d.getUTCMonth()+1).padStart(2,"0")+"/"+String(d.getUTCDate()).padStart(2,"0");
}
function isoDay(d) {return d.toISOString().slice(0,10);}
function addDays(d,n) {const x=new Date(d);x.setUTCDate(x.getUTCDate()+n);return x;}
function presetRange(kind) {
 const end=new Date();
 const today=new Date(Date.UTC(end.getFullYear(),end.getMonth(),end.getDate()));
 let start=new Date(today);
 if(kind==="Week") start=addDays(today,-6);
 if(kind==="15 days") start=addDays(today,-14);
 if(kind==="Month") start=new Date(Date.UTC(today.getUTCFullYear(),today.getUTCMonth(),1));
 if(kind==="Year") start=new Date(Date.UTC(today.getUTCFullYear(),0,1));
 if(kind==="Day") start=new Date(today);
 reportFrom=dateText(start);reportTo=dateText(today);
}
function renderReports() {
 if(!reportFrom||!reportTo) presetRange("Month");
 $("main").innerHTML=pageHead("Reports & analytics","Filter real records by date, compare growth and export results")+
 `<div class="card section no-print">
  <h2>Search by date</h2>
  <div class="row" style="margin-bottom:14px">
   ${["Day","Week","15 days","Month","Year"].map(k=>`<button class="secondary preset" data-period="${k}">${k}</button>`).join("")}
  </div>
  <form id="reportForm">
   <div class="filters">
    <div><label for="fromDate">From date (YYYY/MM/DD)</label><input id="fromDate" value="${esc(reportFrom)}" placeholder="2026/11/20" required pattern="\\d{4}/\\d{2}/\\d{2}"></div>
    <div><label for="toDate">To date (YYYY/MM/DD)</label><input id="toDate" value="${esc(reportTo)}" placeholder="2026/11/21" required pattern="\\d{4}/\\d{2}/\\d{2}"></div>
    <div><label for="reportKind">Report category</label><select id="reportKind">
     ${["All reports","Rides","Revenue","Drivers","Passengers","Vehicles"].map(k=>`<option ${reportKind===k?"selected":""}>${k}</option>`).join("")}
    </select></div>
    <div><label for="reportSearch">Search records</label><input id="reportSearch" value="${esc(reportSearch)}" placeholder="ID, name, status…"></div>
   </div>
   <div class="row" style="margin-top:14px">
    <button type="submit">Search reports</button>
    <button type="button" class="secondary" id="csvBtn">Download CSV</button>
    <button type="button" class="secondary" id="printBtn">Print / Save PDF</button>
   </div>
  </form>
 </div>
 <div id="reportContent"><div class="empty">Select a date range and press Search reports.</div></div>`;
 document.querySelectorAll(".preset").forEach(b=>b.addEventListener("click",()=>{
  presetRange(b.dataset.period);$("fromDate").value=reportFrom;$("toDate").value=reportTo;
 }));
 $("reportForm").addEventListener("submit",async e=>{
  e.preventDefault();
  const from=validDateInput($("fromDate").value),to=validDateInput($("toDate").value);
  if(!from||!to){alert("Enter valid dates in YYYY/MM/DD format, for example 2026/11/20.");return;}
  if(to<from){alert("To date must be on or after From date.");return;}
  reportFrom=dateText(from);reportTo=dateText(to);
  reportKind=$("reportKind").value;reportSearch=$("reportSearch").value.trim();
  await runReport();
 });
 $("csvBtn").onclick=downloadCSV;
 $("printBtn").onclick=()=>window.print();
}
function inRange(value,from,toExclusive) {
 if(!value)return false;
 const d=new Date(value);
 return !Number.isNaN(d.getTime()) && d>=from && d<toExclusive;
}
function selectDateRange(rows,from,toExclusive) {
 return rows.filter(r=>inRange(r.created_at,from,toExclusive));
}
function amountForRide(r) {return Number(r.final_fare ?? r.actual_fare ?? r.fare ?? 0)||0;}
function rideRevenue(r) {
 return amountForRide(r);
}
function getPeriodKey(value,interval) {
 const d=new Date(value);
 if(Number.isNaN(d.getTime()))return "Unknown";
 if(interval==="Yearly")return String(d.getFullYear());
 if(interval==="Monthly")return d.getFullYear()+"-"+String(d.getMonth()+1).padStart(2,"0");
 return d.getFullYear()+"-"+String(d.getMonth()+1).padStart(2,"0")+"-"+String(d.getDate()).padStart(2,"0");
}
function chartValue(row,metric) {
 if(metric==="Revenue") return row.status==="completed"?rideRevenue(row):0;
 if(metric==="Rides") return 1;
 if(metric==="Drivers"||metric==="Passengers") return 1;
 return 0;
}
function chartCanvas(data,metric,interval) {
 if(!data.length)return `<div class="empty">No records in this date range for the selected chart.</div>`;
 const w=900,h=260,left=55,right=20,top=20,bottom=45;
 const vals=data.map(x=>x.value),max=Math.max(...vals,1);
 const points=data.map((d,i)=>{
  const x=left+(data.length===1?0:i*(w-left-right)/(data.length-1));
  const y=h-bottom-(d.value/max)*(h-top-bottom);
  return {x,y,label:d.label,value:d.value};
 });
 const path=points.map((p,i)=>(i?"L":"M")+p.x.toFixed(1)+" "+p.y.toFixed(1)).join(" ");
 const bars=data.length<=18?points.map((p,i)=>{
  const slot=(w-left-right)/data.length;
  const bh=h-bottom-p.y;
  return `<rect x="${(left+i*slot+slot*.15).toFixed(1)}" y="${p.y.toFixed(1)}" width="${(slot*.7).toFixed(1)}" height="${bh.toFixed(1)}" rx="3" fill="#ff7417"><title>${esc(p.label)}: ${esc(p.value)}</title></rect>`;
 }).join(""):"";
 const labels=points.filter((p,i)=>data.length<=12||i===0||i===points.length-1||i%Math.ceil(data.length/6)===0).map(p=>
  `<text x="${p.x}" y="${h-17}" fill="currentColor" font-size="11" text-anchor="middle">${esc(p.label)}</text>`).join("");
 const grid=[0,.25,.5,.75,1].map(fr=>{
  const y=h-bottom-fr*(h-top-bottom);
  return `<line x1="${left}" y1="${y}" x2="${w-right}" y2="${y}" stroke="currentColor" opacity=".13"/><text x="${left-8}" y="${y+4}" fill="currentColor" font-size="10" text-anchor="end">${Math.round(max*fr).toLocaleString()}</text>`;
 }).join("");
 return `<svg class="chart" viewBox="0 0 ${w} ${h}" role="img" aria-label="${esc(metric)} growth chart">
  ${grid}${bars?bars:`<path d="${path}" fill="none" stroke="#ff7417" stroke-width="3"/>${points.map(p=>`<circle cx="${p.x}" cy="${p.y}" r="4" fill="#ff7417"><title>${esc(p.label)}: ${esc(p.value)}</title></circle>`).join("")}`}
  ${labels}</svg>`;
}
function buildGrowth(rows,metric,interval,from,toExclusive) {
 const keys=new Map();
 if(metric==="Revenue"||metric==="Rides"){
  rows.forEach(r=>{
   const key=getPeriodKey(r.created_at,interval);
   if(key==="Unknown")return;
   keys.set(key,(keys.get(key)||0)+chartValue(r,metric));
  });
 } else {
  rows.forEach(r=>{
   const role=String(r.role||"").toLowerCase();
   if(metric==="Drivers"&&role!=="driver")return;
   if(metric==="Passengers"&&role!=="passenger")return;
   const key=getPeriodKey(r.created_at,interval);
   if(key==="Unknown")return;
   keys.set(key,(keys.get(key)||0)+1);
  });
 }
 const result=[...keys.entries()].sort((a,b)=>a[0].localeCompare(b[0])).map(([label,value])=>({label,value}));
 return result;
}
function growthPct(current,previous) {
 if(previous===0)return current===0?"0.0%":"N/A (previous period was zero)";
 return ((current-previous)/Math.abs(previous)*100).toFixed(1)+"%";
}
function periodSum(rows,from,toExclusive,metric) {
 return rows.filter(r=>inRange(r.created_at,from,toExclusive)).reduce((s,r)=>{
  if(metric==="Revenue")return s+(r.status==="completed"?rideRevenue(r):0);
  if(metric==="Completed rides")return s+(r.status==="completed"?1:0);
  if(metric==="Cancelled rides")return s+(r.status==="cancelled"?1:0);
  return s+1;
 },0);
}
async function runReport() {
 const content=$("reportContent");
 content.innerHTML='<div class="empty">Searching Supabase records…</div>';
 const fromDate=validDateInput(reportFrom),toDate=validDateInput(reportTo);
 const from=fromDate,toExclusive=addDays(toDate,1);
 const startISO=isoDay(from),endISO=isoDay(toExclusive);
 const tasks=[];
 const needRides=["All reports","Rides","Revenue"].includes(reportKind);
 const needProfiles=["All reports","Drivers","Passengers"].includes(reportKind);
 const needVehicles=["All reports","Vehicles"].includes(reportKind);
 if(needRides)tasks.push(["rides",db.from("rides").select("*").gte("created_at",startISO).lt("created_at",endISO).order("created_at",{ascending:false}).limit(10000)]);
 if(needProfiles)tasks.push(["profiles",db.from("profiles").select("*").gte("created_at",startISO).lt("created_at",endISO).order("created_at",{ascending:false}).limit(10000)]);
 if(needVehicles)tasks.push(["vehicles",db.from("vehicles").select("*").gte("created_at",startISO).lt("created_at",endISO).order("created_at",{ascending:false}).limit(10000)]);
 const results=await Promise.all(tasks.map(async ([name,promise])=>({name,...await promise})));
 const errors=results.filter(r=>r.error);
 const selected={rides:[],profiles:[],vehicles:[]};
 results.forEach(r=>{if(!r.error)selected[r.name]=r.data||[];});
 reportRows=[];
 if(["All reports","Rides"].includes(reportKind))reportRows=selected.rides.map(r=>({type:"Ride",id:r.id,date:r.created_at,status:r.status,vehicle:r.vehicle_type,passenger:r.passenger_id,driver:r.driver_id,amount:amountForRide(r),raw:r}));
 else if(reportKind==="Revenue")reportRows=selected.rides.filter(r=>r.status==="completed").map(r=>({type:"Revenue",id:r.id,date:r.created_at,status:r.status,vehicle:r.vehicle_type,passenger:r.passenger_id,driver:r.driver_id,amount:amountForRide(r),raw:r}));
 else if(reportKind==="Drivers"||reportKind==="Passengers")reportRows=selected.profiles.filter(p=>p.role===reportKind.slice(0,-1).toLowerCase()||p.role===reportKind.toLowerCase().replace(/s$/,"")).map(p=>({type:p.role,id:p.id,date:p.created_at,status:p.is_suspended?"suspended":p.is_verified?"verified":"pending",vehicle:"",passenger:p.full_name||p.phone||p.id,driver:"",amount:0,raw:p}));
 else if(reportKind==="Vehicles")reportRows=selected.vehicles.map(v=>({type:"Vehicle",id:v.id,date:v.created_at,status:v.is_approved?"approved":v.status||"pending",vehicle:v.vehicle_type||v.type,passenger:"",driver:v.driver_id,amount:0,raw:v}));
 else reportRows=[
  ...selected.rides.map(r=>({type:"Ride",id:r.id,date:r.created_at,status:r.status,vehicle:r.vehicle_type,passenger:r.passenger_id,driver:r.driver_id,amount:amountForRide(r),raw:r})),
  ...selected.profiles.map(p=>({type:p.role,id:p.id,date:p.created_at,status:p.is_suspended?"suspended":p.is_verified?"verified":"pending",vehicle:"",passenger:p.full_name||p.phone||p.id,driver:"",amount:0,raw:p})),
  ...selected.vehicles.map(v=>({type:"Vehicle",id:v.id,date:v.created_at,status:v.is_approved?"approved":v.status||"pending",vehicle:v.vehicle_type||v.type,passenger:"",driver:v.driver_id,amount:0,raw:v}))
 ];
 if(reportSearch){
  const q=reportSearch.toLowerCase();
  reportRows=reportRows.filter(r=>JSON.stringify(r.raw).toLowerCase().includes(q));
 }
 reportLabel=`${reportKind} · ${reportFrom} to ${reportTo}`;
 reportLoaded=true;

 const rides=selected.rides;
 const completed= rides.filter(r=>r.status==="completed");
 const cancelled= rides.filter(r=>r.status==="cancelled");
 const revenue=completed.reduce((s,r)=>s+amountForRide(r),0);
 const prevDays=Math.max(1,Math.round((toDate-fromDate)/86400000)+1);
 const prevFrom=addDays(fromDate,-prevDays);
 const prevTo=fromDate;
 const previousRides=cache.rides.filter(r=>inRange(r.created_at,prevFrom,prevTo));
 const previousRevenue=previousRides.filter(r=>r.status==="completed").reduce((s,r)=>s+amountForRide(r),0);
 const currentGrowthMetric=chartMetric;
 const chartRows=currentGrowthMetric==="Drivers"||currentGrowthMetric==="Passengers"?selected.profiles:rides;
 reportChartData=buildGrowth(chartRows,currentGrowthMetric,chartInterval,fromDate,toExclusive);
 const totalMetric=currentGrowthMetric==="Revenue"?revenue:currentGrowthMetric==="Rides"?rides.length:
  currentGrowthMetric==="Drivers"?selected.profiles.filter(p=>p.role==="driver").length:
  selected.profiles.filter(p=>p.role==="passenger").length;
 const previousMetric=currentGrowthMetric==="Revenue"?previousRevenue:currentGrowthMetric==="Rides"?previousRides.length:0;

 const warning=errors.length?`<div class="notice error">Some report data could not be loaded:\n${errors.map(e=>esc(e.name+": "+e.error.message)).join("\n")}\nCheck table permissions and RLS policies.</div>`:"";
 const summary=`<div class="grid">
 ${statCard("Records in range",reportRows.length)}
 ${statCard("Completed rides",completed.length)}
 ${statCard("Cancelled rides",cancelled.length)}
 ${statCard("Completed ride fares",money(revenue))}
 </div>`;
 const growth=`<div class="card section">
  <div class="between"><h2>Growth over time</h2><span class="muted">${esc(chartMetric)} · ${esc(chartInterval)}</span></div>
  <div class="row no-print" style="margin-bottom:12px">
   <label style="margin:0">Metric</label><select id="chartMetric" style="width:auto">
    ${["Revenue","Rides","Drivers","Passengers"].map(m=>`<option ${chartMetric===m?"selected":""}>${m}</option>`).join("")}
   </select>
   <label style="margin:0">Interval</label><select id="chartInterval" style="width:auto">
    ${["Daily","Monthly","Yearly"].map(m=>`<option ${chartInterval===m?"selected":""}>${m}</option>`).join("")}
   </select>
  </div>
  ${chartCanvas(reportChartData,chartMetric,chartInterval)}
  <div class="chart-legend"><span><i class="dot"></i>${esc(chartMetric)}</span><span>Values are grouped by record creation date; revenue uses completed rides only.</span></div>
  <hr>
  <div class="grid">
   ${statCard("Selected period",chartMetric==="Revenue"?money(totalMetric):Number(totalMetric).toLocaleString())}
   ${statCard("Previous period",chartMetric==="Revenue"?money(previousMetric):Number(previousMetric).toLocaleString())}
   ${statCard("Growth",growthPct(totalMetric,previousMetric))}
  </div>
 </div>`;
 const tableRows=reportRows.map(r=>[
  esc(r.type),esc(r.id),esc(fmtDate(r.date)),statusBadge(r.status),
  esc(r.vehicle||"—"),esc(r.passenger||"—"),esc(r.driver||"—"),
  esc(r.type==="Ride"||r.type==="Revenue"?money(r.amount):"—")
 ]);
 content.innerHTML=warning+summary+growth+
 `<div class="card section"><div class="between"><div><h2>Report results</h2><div class="muted">${esc(reportLabel)} · ${reportRows.length} records</div></div></div>
 ${tableHTML(["Type","ID","Created","Status","Vehicle","Passenger / Name","Driver ID","Amount"],tableRows,"No records match this date range and search.")}</div>`;
 $("chartMetric").addEventListener("change",e=>{chartMetric=e.target.value;runReport();});
 $("chartInterval").addEventListener("change",e=>{chartInterval=e.target.value;runReport();});
}
function downloadCSV() {
 if(!reportLoaded){alert("Search a date range before downloading a report.");return;}
 const headers=["Type","ID","Created","Status","Vehicle","Passenger or name","Driver ID","Amount"];
 const rows=reportRows.map(r=>[r.type,r.id,r.date,r.status,r.vehicle,r.passenger,r.driver,r.amount]);
 const quote=v=>'"'+String(v??"").replace(/"/g,'""')+'"';
 const csv="\uFEFF"+[["Rryd report",reportLabel],[],headers,...rows].map(r=>r.map(quote).join(",")).join("\r\n");
 const blob=new Blob([csv],{type:"text/csv;charset=utf-8"});
 const url=URL.createObjectURL(blob);
 const a=document.createElement("a");
 a.href=url;a.download="rryd-report-"+reportFrom.replaceAll("/","-")+"-to-"+reportTo.replaceAll("/","-")+".csv";
 document.body.appendChild(a);a.click();a.remove();URL.revokeObjectURL(url);
}

async function saveFareRule(e) {
 e.preventDefault();
 const form=e.currentTarget;
 const msg=form.querySelector("[data-form-message]");
 const id=form.dataset.id;
 const payload={
  base_fare:Number(form.elements.base_fare.value),
  per_km_fare:Number(form.elements.per_km_fare.value),
  platform_commission_percent:Number(form.elements.platform_commission_percent.value),
  is_active:form.elements.is_active.value==="true"
 };
 if(payload.base_fare<0||payload.per_km_fare<0||payload.platform_commission_percent<0||payload.platform_commission_percent>100) {
  msg.textContent="Please enter valid non-negative values and commission no greater than 100%.";return;
 }
 try {
  const {error}=await db.from("fare_rules").update(payload).eq("id",id);
  if(error)throw error;
  msg.textContent="Saved successfully.";
  await loadBaseData();
 } catch(err) {
  msg.textContent="Save failed: "+errText(err);
 }
}

async function performAction(action,id,value) {
 if(!confirm("Confirm this admin action? It will send a request to Supabase."))return;
 try {
  if(action==="approve-driver") {
   const {error}=await db.rpc("approve_driver",{p_driver_id:id});
   if(error)throw error;
  } else if(action==="approve-vehicle") {
   const numericId=Number(id);
   if(!Number.isFinite(numericId))throw new Error("Invalid vehicle ID.");
   const {error}=await db.rpc("approve_vehicle",{p_vehicle_id:numericId});
   if(error)throw error;
  } else if(action==="suspend-profile") {
   const {error}=await db.from("profiles").update({is_suspended:value==="true"}).eq("id",id);
   if(error)throw error;
  } else throw new Error("Unsupported action.");
  alert("Supabase accepted the action.");
  await loadBaseData();
  await navigate(currentPage);
 } catch(e) {
  alert("Action failed: "+errText(e)+"\n\nCheck the RPC parameter names and database RLS policies. No success is assumed when Supabase returns an error.");
 }
}

function bindSearch() {
 const input=$("tableSearch");
 if(!input)return;
 input.addEventListener("input",()=>{
  reportSearch=input.value;
  const pos=input.selectionStart;
  if(currentPage==="Drivers")renderDrivers();
  if(currentPage==="Passengers")renderPassengers();
  if(currentPage==="Vehicles")renderVehicles();
  if(currentPage==="Rides")renderRides();
  const next=$("tableSearch");
  if(next){next.focus();try{next.setSelectionRange(pos,pos)}catch(_){}}
 });
}
document.addEventListener("click",e=>{
 const b=e.target.closest("[data-action]");
 if(!b)return;
 performAction(b.dataset.action,b.dataset.id,b.dataset.value);
});
document.querySelectorAll(".navbtn").forEach(b=>b.addEventListener("click",()=>navigate(b.dataset.page)));
$("menuBtn").addEventListener("click",()=>$("sidebar").classList.toggle("open"));
$("refreshBtn").addEventListener("click",async()=>{
 $("refreshBtn").disabled=true;
 try {await loadBaseData();await navigate(currentPage);}
 catch(e){alert(errText(e));}
 finally {$("refreshBtn").disabled=false;}
});
$("logoutBtn").addEventListener("click",async()=>{
 await db.auth.signOut();
 currentUser=null;profile=null;showLogin();
});
$("loginForm").addEventListener("submit",async e=>{
 e.preventDefault();
 const btn=$("loginBtn");setBusy(btn,true,"Signing in…");
 try {
  const {data,error}=await db.auth.signInWithPassword({
   email:$("email").value.trim(),password:$("password").value
  });
  if(error)throw error;
  await checkAdmin(data.user);
 } catch(err) {
  loginMessage(errText(err));
 } finally {setBusy(btn,false);}
});
$("forgotBtn").addEventListener("click",async()=>{
 const email=$("email").value.trim();
 if(!email){loginMessage("Enter your account email first, then click Forgot password.");return;}
 try {
  const {error}=await db.auth.resetPasswordForEmail(email,{
   redirectTo:location.origin+location.pathname
  });
  if(error)throw error;
  loginMessage("If the email is registered, a password reset link has been sent. Check your inbox and spam folder.","ok");
 } catch(e){loginMessage("Password reset failed: "+errText(e));}
});

db.auth.onAuthStateChange((event,session)=>{
 if(event==="PASSWORD_RECOVERY"){
  const newPassword=prompt("Enter a new password (at least 8 characters):");
  if(newPassword && newPassword.length>=8) {
   db.auth.updateUser({password:newPassword}).then(({error})=>{
    alert(error?"Password update failed: "+error.message:"Password updated. You can sign in with your new password.");
   });
  }
 }
});
(async()=>{
 try {
  const {data:{session},error}=await db.auth.getSession();
  if(error)throw error;
  if(session?.user) await checkAdmin(session.user);
  else showLogin();
 } catch(e) {
  showLogin();
  loginMessage(errText(e));
 }
})();
})();
</script>
</body>
</html>
```
