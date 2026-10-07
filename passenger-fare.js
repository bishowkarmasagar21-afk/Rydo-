/* RYDO FAST FARE ENGINE */

window.RydoFare = {

  rules: {},

  async load(supabase) {

    const { data, error } = await supabase
      .from("fare_rules")
      .select(
        "vehicle_type,base_fare,per_km_fare,platform_commission_percent"
      )
      .eq("is_active", true);

    if (error) {
      console.error("Fare rules error:", error);
      throw error;
    }

    this.rules = {};

    (data || []).forEach(rule => {
      this.rules[rule.vehicle_type] = {
        base: Number(rule.base_fare),
        perKm: Number(rule.per_km_fare),
        commission: Number(
          rule.platform_commission_percent || 15
        )
      };
    });

    console.log("RYDO fare rules loaded:", this.rules);

    return this.rules;
  },

  calculate(vehicle, distanceKm) {

    const type = vehicle
      .toLowerCase()
      .replace(/\s+/g, "_");

    const rule = this.rules[type];

    if (!rule || !distanceKm) {
      return null;
    }

    const estimatedFare = Math.round(
      rule.base +
      (rule.perKm * Number(distanceKm))
    );

    return {
      vehicle_type: type,
      distance_km: Number(distanceKm),
      estimated_fare: estimatedFare,
      commission_percent: rule.commission
    };
  }

};
