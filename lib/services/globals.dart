library my_app.globals;

String loggedInUserId = "";

// Base URL for API (Windows localhost). Include path prefix if your API is under /api or /api/v1
String apiBaseUrl = "http://localhost:8080/api";

// Optional overrides for auth endpoint paths (relative to apiBaseUrl)
// Leave empty to let the client try common defaults.
String overrideAuthLoginPath = "";        // e.g., "auth/authenticate" or "login"
String overrideAuthStaffLoginPath = "";   // e.g., "staff/login" or "auth/staff/login"

// WebSocket/STOMP configuration (adjust to match your server)
String wsEndpointPath = "/ws"; // Confirm exact STOMP endpoint path on server
String appDestinationPrefix = "/app"; // Confirm setApplicationDestinationPrefixes
String topicDestinationPrefix = "/topic"; // Typically '/topic'
