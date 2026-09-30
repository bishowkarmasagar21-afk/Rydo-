/* RYDO DRIVER CONTROLLER */

(function () {

  function start() {

    if (!window.currentUser || !window.currentDriver) {
      return;
    }

    const authPage =
      document.getElementById("authPage");

    const driverPage =
      document.getElementById("driverPage");

    if (authPage && driverPage) {
      authPage.classList.add("hidden");
      driverPage.classList.remove("hidden");
    }

    if (typeof window.startDriverApp === "function") {
      window.startDriverApp();
    }
  }


  /* WAIT UNTIL ALL DRIVER FILES ARE LOADED */

  window.addEventListener("load", function () {

    setTimeout(start, 100);

  });


  /* AUTH STATE */

  if (typeof db !== "undefined") {

    db.auth.onAuthStateChange(function (
      event,
      session
    ) {

      if (
        session &&
        window.currentDriver
      ) {
        setTimeout(start, 100);
      }

    });

  }

})();
