const SUPABASE_URL = "https://kqtvuorasqyzjbnlkkxs.supabase.co";
const SUPABASE_KEY = "sb_publishable_zZFJiy0YWZgOXFesVuAQcA_wd7rleMb";

const supabaseClient = window.supabase.createClient(
  SUPABASE_URL,
  SUPABASE_KEY
);

const $ = (id) => document.getElementById(id);

function message(id, text) {
  $(id).textContent = text;
}

function showLogin() {
  $("registrationScreen").classList.add("hidden");
  $("loginScreen").classList.remove("hidden");
}

function showRegistration() {
  $("loginScreen").classList.add("hidden");
  $("registrationScreen").classList.remove("hidden");
}

$("showRegistrationBtn").addEventListener("click", showRegistration);
$("backToLoginBtn").addEventListener("click", showLogin);

$("toggleLoginPassword").addEventListener("click", () => {
  const input = $("loginPassword");
  input.type = input.type === "password" ? "text" : "password";
  $("toggleLoginPassword").textContent =
    input.type === "password" ? "Show" : "Hide";
});

$("toggleRegisterPassword").addEventListener("click", () => {
  const input = $("registerPassword");
  input.type = input.type === "password" ? "text" : "password";
  $("toggleRegisterPassword").textContent =
    input.type === "password" ? "Show" : "Hide";
});


/* LOGIN */

$("driverLoginForm").addEventListener("submit", async (e) => {
  e.preventDefault();

  const email = $("loginEmail").value.trim();
  const password = $("loginPassword").value;

  message("loginMessage", "Checking account...");

  const { data, error } =
    await supabaseClient.auth.signInWithPassword({
      email,
      password
    });

  if (error) {
    message("loginMessage", error.message);
    return;
  }

  const user = data.user;

  const { data: profile, error: profileError } =
    await supabaseClient
      .from("profiles")
      .select("id, full_name, role, is_verified")
      .eq("id", user.id)
      .single();

  if (profileError || !profile) {
    await supabaseClient.auth.signOut();
    message("loginMessage", "Driver profile not found.");
    return;
  }

  if (profile.role !== "driver") {
    await supabaseClient.auth.signOut();
    message("loginMessage", "This account is not a driver account.");
    return;
  }

  if (!profile.is_verified) {
    await supabaseClient.auth.signOut();
    message(
      "loginMessage",
      "Your driver account is still waiting for verification."
    );
    return;
  }

  window.location.href = "driver-dashboard.html";
});


/* FORGOT PASSWORD */

$("forgotPasswordBtn").addEventListener("click", async () => {
  const email = $("loginEmail").value.trim();

  if (!email) {
    message("loginMessage", "Enter your email first.");
    return;
  }

  message("loginMessage", "Sending password reset...");

  const redirectUrl =
    window.location.origin + window.location.pathname;

  const { error } =
    await supabaseClient.auth.resetPasswordForEmail(email, {
      redirectTo: redirectUrl
    });

  if (error) {
    message("loginMessage", error.message);
    return;
  }

  message(
    "loginMessage",
    "Password reset link sent. Check your email."
  );
});


/* REGISTRATION */

$("driverRegistrationForm").addEventListener("submit", async (e) => {
  e.preventDefault();

  const fullName = $("registerFullName").value.trim();
  const email = $("registerEmail").value.trim();
  const phone = $("registerPhone").value.trim();
  const password = $("registerPassword").value;

  const license = $("driverLicense").files[0];
  const citizenship = $("driverCitizenship").files[0];
  const photo = $("driverPhoto").files[0];

  const vehicleType = $("vehicleType").value;
  const vehicleNumber = $("vehicleNumber").value.trim();
  const vehicleModel = $("vehicleModel").value.trim();
  const vehicleDocument = $("vehicleDocument").files[0];

  if (
    !license ||
    !citizenship ||
    !photo ||
    !vehicleDocument
  ) {
    message(
      "registrationMessage",
      "Please upload all required documents."
    );
    return;
  }

  message("registrationMessage", "Creating driver account...");

  const { data, error } =
    await supabaseClient.auth.signUp({
      email,
      password
    });

  if (error) {
    message("registrationMessage", error.message);
    return;
  }

  const user = data.user;

  if (!user) {
    message(
      "registrationMessage",
      "Account created. Check your email to continue."
    );
    return;
  }

  const { error: profileError } =
    await supabaseClient
      .from("profiles")
      .upsert({
        id: user.id,
        full_name: fullName,
        phone: phone,
        role: "driver",
        is_verified: false,
        driver_license: license.name
      });

  if (profileError) {
    message(
      "registrationMessage",
      "Account created, but profile setup failed."
    );
    return;
  }

  const { error: vehicleError } =
    await supabaseClient
      .from("vehicles")
      .upsert({
        driver_id: user.id,
        vehicle_type: vehicleType,
        vehicle_number: vehicleNumber,
        model: vehicleModel
      });

  if (vehicleError) {
    message(
      "registrationMessage",
      "Profile saved, but vehicle setup failed."
    );
    return;
  }

  message(
    "registrationMessage",
    "Registration submitted. Your account must be verified by Rydo before login."
  );

  $("driverRegistrationForm").reset();

  setTimeout(showLogin, 2500);
});
