/* RYDO PASSENGER AUTH
Login + Registration + Session + Settings
*/

let currentUser = null;

/* ---------- SCREEN ---------- */

function authScreen(id) {
document.querySelectorAll(".screen").forEach(screen => {
screen.classList.remove("active");
});

const screen = document.getElementById(id);
if (screen) screen.classList.add("active");
}

/* ---------- LOGIN ---------- */

async function passengerLogin() {
const email = document.getElementById("loginEmail")?.value.trim();
const password = document.getElementById("loginPassword")?.value;

if (!email || !password) {
alert("Enter your email and password.");
return;
}

const button = document.getElementById("loginButton");
if (button) button.disabled = true;

const { data, error } = await supabaseClient.auth.signInWithPassword({
email,
password
});

if (button) button.disabled = false;

if (error) {
alert(error.message);
return;
}

currentUser = data.user;

await loadPassengerProfile();

authScreen("rideScreen");
}

/* ---------- REGISTER ---------- */

async function passengerRegister() {
const name = document.getElementById("registerName")?.value.trim();
const phone = document.getElementById("registerPhone")?.value.trim();
const email = document.getElementById("registerEmail")?.value.trim();
const password = document.getElementById("registerPassword")?.value;

if (!name || !phone || !email || !password) {
alert("Please fill in all registration fields.");
return;
}

if (password.length < 6) {
alert("Password must contain at least 6 characters.");
return;
}

const button = document.getElementById("registerButton");
if (button) button.disabled = true;

const { data, error } = await supabaseClient.auth.signUp({
email,
password
});

if (error) {
if (button) button.disabled = false;
alert(error.message);
return;
}

if (!data.user) {
if (button) button.disabled = false;
alert("Registration could not be completed.");
return;
}

const { error: profileError } = await supabaseClient
.from("profiles")
.upsert({
id: data.user.id,
full_name: name,
phone: phone,
role: "passenger"
});

if (button) button.disabled = false;

if (profileError) {
console.error(profileError);
alert("Account created, but profile setup failed.");
return;
}

alert("Account created successfully. Please login.");

showLoginForm();
}

/* ---------- PROFILE ---------- */

async function loadPassengerProfile() {
if (!currentUser) return;

const { data, error } = await supabaseClient
.from("profiles")
.select("*")
.eq("id", currentUser.id)
.single();

if (error) {
console.error("Profile:", error);
return;
}

window.passengerProfile = data;

const name = document.getElementById("accountName");
if (name) {
name.textContent = data.full_name || "Passenger";
}
}

/* ---------- SESSION ---------- */

async function checkPassengerSession() {
const {
data: { session }
} = await supabaseClient.auth.getSession();

if (session?.user) {
currentUser = session.user;
await loadPassengerProfile();
authScreen("rideScreen");
} else {
authScreen("welcomeScreen");
}
}

supabaseClient.auth.onAuthStateChange((event, session) => {
if (session?.user) {
currentUser = session.user;
} else {
currentUser = null;
}
});

/* ---------- LOGIN / REGISTER TABS ---------- */

function showLoginForm() {
const login = document.getElementById("loginForm");
const register = document.getElementById("registerForm");

if (login) login.style.display = "block";
if (register) register.style.display = "none";
}

function showRegisterForm() {
const login = document.getElementById("loginForm");
const register = document.getElementById("registerForm");

if (login) login.style.display = "none";
if (register) register.style.display = "block";
}

/* ---------- LOGOUT ---------- */

async function passengerLogout() {
await supabaseClient.auth.signOut();

currentUser = null;
window.currentRide = null;

authScreen("welcomeScreen");
}

/* ---------- PASSWORD RESET ---------- */

async function resetPassengerPassword() {
const email = document.getElementById("loginEmail")?.value.trim();

if (!email) {
alert("Enter your email address first.");
return;
}

const { error } = await supabaseClient.auth.resetPasswordForEmail(email, {
redirectTo: window.location.origin + window.location.pathname
});

if (error) {
alert(error.message);
return;
}

alert("Password reset instructions have been sent to your email.");
}

/* ---------- SETTINGS ---------- */

function openPassengerSettings() {
authScreen("settingsScreen");
}

function closePassengerSettings() {
authScreen("rideScreen");
}

/* ---------- ACCOUNT DELETE ---------- */

async function deletePassengerAccount() {
if (!currentUser) return;

const confirmed = confirm(
"Delete your Rydo passenger account? This action cannot be undone."
);

if (!confirmed) return;

/*
Client-side Supabase cannot securely delete the Auth user.
A protected Edge Function should handle permanent deletion later.
*/

const { error } = await supabaseClient
.from("profiles")
.delete()
.eq("id", currentUser.id);

if (error) {
alert("Account deletion failed.");
console.error(error);
return;
}

await supabaseClient.auth.signOut();

currentUser = null;
window.currentRide = null;

alert("Your passenger profile has been removed.");
authScreen("welcomeScreen");
}

/* ---------- BUTTONS ---------- */

document.addEventListener("DOMContentLoaded", () => {

const loginButton = document.getElementById("loginButton");
if (loginButton) {
loginButton.addEventListener("click", passengerLogin);
}

const registerButton = document.getElementById("registerButton");
if (registerButton) {
registerButton.addEventListener("click", passengerRegister);
}

const logoutButton = document.getElementById("logoutButton");
if (logoutButton) {
logoutButton.addEventListener("click", passengerLogout);
}

const settingsButton = document.getElementById("settingsButton");
if (settingsButton) {
settingsButton.addEventListener("click", openPassengerSettings);
}

const closeSettings = document.getElementById("closeSettings");
if (closeSettings) {
closeSettings.addEventListener("click", closePassengerSettings);
}

const deleteButton = document.getElementById("deleteAccount");
if (deleteButton) {
deleteButton.addEventListener("click", deletePassengerAccount);
}

const forgotButton = document.getElementById("forgotPassword");
if (forgotButton) {
forgotButton.addEventListener("click", resetPassengerPassword);
}

const loginTab = document.getElementById("loginTab");
if (loginTab) {
loginTab.addEventListener("click", showLoginForm);
}

const registerTab = document.getElementById("registerTab");
if (registerTab) {
registerTab.addEventListener("click", showRegisterForm);
}

checkPassengerSession();
});

/* ---------- PUBLIC ---------- */

window.passengerLogin = passengerLogin;
window.passengerRegister = passengerRegister;
window.passengerLogout = passengerLogout;
window.showLoginForm = showLoginForm;
window.showRegisterForm = showRegisterForm;
window.openPassengerSettings = openPassengerSettings;
window.closePassengerSettings = closePassengerSettings;
window.deletePassengerAccount = deletePassengerAccount;
window.resetPassengerPassword = resetPassengerPassword;
window.checkPassengerSession = checkPassengerSession;


**Important:** your `passenger.html` currently loads only `passenger-ride.js`. After saving this file, we need to add **one script line** for `passenger-auth.js`; otherwise the browser won't load this code.

Don't add it yet if you want to do this step-by-step. Save the file first and tell me **Done**.
