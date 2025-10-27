library my_app.globals;

import 'package:flutter/widgets.dart';

String loggedInUserId = "";

// Base URL for API
String apiBaseUrl = "http://localhost:8080/api";

// Auth token (Bearer) updated by AuthProvider when available
String authToken = "";

// Refresh token (if backend provides) - used for token refresh flows
String refreshToken = "";

// Optional path for token refresh endpoint (relative to apiBaseUrl). Leave empty if not supported.
String authRefreshPath = "auth/refresh"; // set to empty string if backend does not support refresh

// Global navigator key so services can navigate to login on auth failures
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Optional overrides for auth endpoint paths (relative to apiBaseUrl)
// Leave empty to let the client try common defaults.
String overrideAuthLoginPath = "";        // e.g., "auth/authenticate" or "login"
String overrideAuthStaffLoginPath = "";   // e.g., "staff/login" or "auth/staff/login"

// WebSocket/STOMP configuration (adjust to match your server)
String wsEndpointPath = "/ws"; // Confirm exact STOMP endpoint path on server
String appDestinationPrefix = "/app"; // Confirm setApplicationDestinationPrefixes
String topicDestinationPrefix = "/topic"; // Typically '/topic'
