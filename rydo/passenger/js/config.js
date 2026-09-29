/**
 * RYDO Passenger Portal - Configuration Module
 * 
 * This module provides safe frontend configuration for the RYDO passenger application.
 * 
 * IMPORTANT SECURITY NOTES:
 * - This file is visible to all users; do NOT include secrets.
 * - Private keys, credentials, and tokens must be on the backend only.
 * - Configuration values marked as "TODO" must be set before production use.
 * - Only public keys (Supabase anon key, public map keys) are safe here.
 */

// ===================================================================
// APPLICATION METADATA
// ===================================================================

export const APP_CONFIG = {
  name: 'RYDO',
  tagline: 'Move your way.',
  version: '1.0.0',
  environment: 'development', // development, staging, production
};

// ===================================================================
// SUPABASE CONFIGURATION
// ===================================================================

// TODO: Replace these with your actual Supabase credentials
// Get these values from: https://app.supabase.com/project/_/settings/api
// - URL: Under "Project URL"
// - ANON_KEY: Under "Project API keys" > "anon public"
// 
// SECURITY: Only the public anon key goes here, never the service-role key.

export const SUPABASE_CONFIG = {
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_SUPABASE_ANON_KEY',
};

// ===================================================================
// MAP PROVIDER CONFIGURATION
// ===================================================================

// TODO: Configure your map provider (Mapbox, Leaflet, Google Maps, etc.)
// Update the provider name and public API key as needed.

export const MAP_CONFIG = {
  provider: 'mapbox', // 'mapbox', 'leaflet', 'google-maps', etc.
  apiKey: 'YOUR_MAP_PUBLIC_API_KEY', // Public key only, never the secret key
  
  // Default map center (Kathmandu, Nepal)
  defaultCenter: {
    latitude: 27.7172,
    longitude: 85.3240,
  },
  
  // Default zoom level
  defaultZoom: 13,
  
  // Map style (Mapbox style URL or provider-specific identifier)
  style: 'mapbox://styles/mapbox/dark-v11',
  
  // Map container settings
  container: {
    id: 'passenger-map',
    minHeight: 300, // pixels
  },
};

// ===================================================================
// GEOCODING CONFIGURATION
// ===================================================================

// TODO: Configure geocoding endpoints
// These should point to your backend service that handles geocoding
// for privacy and to avoid exposing API keys to the frontend.

export const GEOCODING_CONFIG = {
  // Forward geocoding: address string -> coordinates
  forwardEndpoint: '/api/geocoding/forward',
  
  // Reverse geocoding: coordinates -> address
  reverseEndpoint: '/api/geocoding/reverse',
  
  // Timeout in milliseconds
  timeout: 5000,
};

// ===================================================================
// ROUTING CONFIGURATION
// ===================================================================

// TODO: Configure routing endpoints
// These should point to your backend service (never expose routing API keys).

export const ROUTING_CONFIG = {
  // Route calculation endpoint
  routeEndpoint: '/api/routing/route',
  
  // Routing provider backend uses
  provider: 'osrm', // 'osrm', 'google-maps', 'mapbox', etc.
  
  // Supported travel modes
  travelModes: {
    bike: 'bike',
    car: 'car',
    tuktuk: 'car', // Tuk tuk typically uses car routing
  },
  
  // Timeout in milliseconds
  timeout: 8000,
};

// ===================================================================
// VEHICLE TYPES
// ===================================================================

export const VEHICLE_TYPES = {
  BIKE: 'bike',
  CAR: 'car',
  TUK_TUK: 'tuk_tuk',
};

// List of all vehicle types for iteration
export const VEHICLE_TYPES_LIST = [
  { id: VEHICLE_TYPES.BIKE, name: 'Bike', icon: '🏍️' },
  { id: VEHICLE_TYPES.CAR, name: 'Car', icon: '🚗' },
  { id: VEHICLE_TYPES.TUK_TUK, name: 'Tuk Tuk', icon: '🛺' },
];

// ===================================================================
// PAYMENT METHODS
// ===================================================================

export const PAYMENT_METHODS = {
  CASH: 'cash',
  ONLINE: 'online',
};

// List of all payment methods for iteration
export const PAYMENT_METHODS_LIST = [
  { id: PAYMENT_METHODS.CASH, name: 'Cash', icon: '💵' },
  { id: PAYMENT_METHODS.ONLINE, name: 'Online', icon: '💳' },
];

// ===================================================================
// RIDE STATUS CONSTANTS
// ===================================================================

export const RIDE_STATUS = {
  SEARCHING: 'searching',           // Looking for available drivers
  DRIVER_ASSIGNED: 'driver_assigned', // Driver has accepted the ride
  DRIVER_ARRIVING: 'driver_arriving', // Driver is on the way to pickup
  DRIVER_ARRIVED: 'driver_arrived',   // Driver has arrived at pickup
  TRIP_STARTED: 'trip_started',       // Passenger is in the vehicle
  COMPLETED: 'completed',             // Ride finished successfully
  CANCELLED: 'cancelled',             // Ride was cancelled
};

// ===================================================================
// APPLICATION SETTINGS
// ===================================================================

export const APP_SETTINGS = {
  // Default currency for fare display
  defaultCurrency: 'NPR',
  
  // Default timezone
  timezone: 'Asia/Kathmandu',
  
  // Language
  language: 'en',
  
  // Location precision (decimal places for coordinates)
  locationPrecision: 6,
  
  // Ride request timeout in seconds
  rideRequestTimeout: 300,
  
  // Driver search timeout in seconds
  driverSearchTimeout: 60,
  
  // Location update interval in milliseconds
  locationUpdateInterval: 5000,
  
  // Minimum distance to calculate route (meters)
  minRouteDistance: 100,
  
  // Maximum distance for a ride (meters)
  maxRouteDistance: 100000,
};

// ===================================================================
// API ENDPOINTS
// ===================================================================

// TODO: Update base URL if using a different backend domain
const API_BASE_URL = '/api'; // Relative path or full URL to backend

export const API_ENDPOINTS = {
  // Authentication
  auth: {
    login: `${API_BASE_URL}/auth/login`,
    logout: `${API_BASE_URL}/auth/logout`,
    signup: `${API_BASE_URL}/auth/signup`,
    refresh: `${API_BASE_URL}/auth/refresh`,
  },
  
  // Passenger profile
  passenger: {
    profile: `${API_BASE_URL}/passenger/profile`,
    updateProfile: `${API_BASE_URL}/passenger/profile`,
  },
  
  // Ride management
  rides: {
    request: `${API_BASE_URL}/rides/request`,
    list: `${API_BASE_URL}/rides`,
    detail: (rideId) => `${API_BASE_URL}/rides/${rideId}`,
    cancel: (rideId) => `${API_BASE_URL}/rides/${rideId}/cancel`,
    status: (rideId) => `${API_BASE_URL}/rides/${rideId}/status`,
  },
  
  // Notifications
  notifications: {
    list: `${API_BASE_URL}/notifications`,
    mark_as_read: (notificationId) => `${API_BASE_URL}/notifications/${notificationId}/read`,
  },
  
  // Emergency
  sos: {
    alert: `${API_BASE_URL}/sos/alert`,
  },
};

// ===================================================================
// HTTP CONFIGURATION
// ===================================================================

export const HTTP_CONFIG = {
  // Default timeout for all requests (milliseconds)
  timeout: 10000,
  
  // Retry configuration
  retry: {
    maxAttempts: 3,
    backoffMs: 1000,
    backoffMultiplier: 2,
  },
  
  // Headers to include in all requests
  headers: {
    'Content-Type': 'application/json',
  },
};

// ===================================================================
// REALTIME & WEBSOCKET CONFIGURATION
// ===================================================================

// TODO: Configure WebSocket endpoint for real-time updates
// This should connect to your backend service

export const REALTIME_CONFIG = {
  // WebSocket URL for real-time updates
  wsEndpoint: 'wss://YOUR_REALTIME_SERVICE_URL',
  
  // Fallback to polling if WebSocket is unavailable
  fallbackPolling: true,
  
  // Polling interval in milliseconds
  pollingInterval: 3000,
  
  // Channels to subscribe to
  channels: {
    rideUpdates: 'ride_updates',
    driverLocation: 'driver_location',
    notifications: 'notifications',
  },
};

// ===================================================================
// VALIDATION HELPERS
// ===================================================================

/**
 * Check if required Supabase configuration is provided
 * @returns {Object} Validation result
 */
export function validateSupabaseConfig() {
  const isValid =
    SUPABASE_CONFIG.url &&
    SUPABASE_CONFIG.url !== 'YOUR_SUPABASE_URL' &&
    SUPABASE_CONFIG.anonKey &&
    SUPABASE_CONFIG.anonKey !== 'YOUR_SUPABASE_ANON_KEY';

  return {
    isValid,
    message: isValid ? 'Supabase configured' : 'Supabase configuration required',
  };
}

/**
 * Check if required map configuration is provided
 * @returns {Object} Validation result
 */
export function validateMapConfig() {
  const isValid =
    MAP_CONFIG.provider &&
    MAP_CONFIG.apiKey &&
    MAP_CONFIG.apiKey !== 'YOUR_MAP_PUBLIC_API_KEY';

  return {
    isValid,
    message: isValid ? 'Map configured' : 'Map configuration required',
  };
}

/**
 * Get overall configuration status
 * @returns {Object} Configuration status with validation results
 */
export function getConfigStatus() {
  const supabaseValid = validateSupabaseConfig();
  const mapValid = validateMapConfig();

  return {
    supabase: supabaseValid,
    map: mapValid,
    isReady: supabaseValid.isValid && mapValid.isValid,
    warnings: [
      ...(!supabaseValid.isValid ? ['Supabase not configured'] : []),
      ...(!mapValid.isValid ? ['Map not configured'] : []),
    ],
  };
}

/**
 * Log configuration status to console for debugging
 * Only logs non-sensitive information
 */
export function logConfigStatus() {
  console.log('RYDO Configuration Status:', {
    app: APP_CONFIG.name,
    environment: APP_CONFIG.environment,
    supabase: validateSupabaseConfig().message,
    map: validateMapConfig().message,
    vehicleTypes: Object.keys(VEHICLE_TYPES),
    paymentMethods: Object.keys(PAYMENT_METHODS),
  });
}

// ===================================================================
// EXPORT NAMESPACE
// ===================================================================

/**
 * Main configuration export
 * Use: import { RYDO_CONFIG } from './config.js'
 */
export const RYDO_CONFIG = {
  app: APP_CONFIG,
  supabase: SUPABASE_CONFIG,
  map: MAP_CONFIG,
  geocoding: GEOCODING_CONFIG,
  routing: ROUTING_CONFIG,
  vehicles: VEHICLE_TYPES,
  vehiclesList: VEHICLE_TYPES_LIST,
  payments: PAYMENT_METHODS,
  paymentsList: PAYMENT_METHODS_LIST,
  rideStatus: RIDE_STATUS,
  settings: APP_SETTINGS,
  api: API_ENDPOINTS,
  http: HTTP_CONFIG,
  realtime: REALTIME_CONFIG,
  validate: {
    supabase: validateSupabaseConfig,
    map: validateMapConfig,
    status: getConfigStatus,
  },
};

// Initialize and log configuration on load
if (typeof window !== 'undefined') {
  window.addEventListener('load', () => {
    logConfigStatus();
  });
}
