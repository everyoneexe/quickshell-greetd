pragma Singleton

import Quickshell

// Mirrors Quickshell.Services.Pam's PamResult so lockscreen code copied into
// a theme keeps comparing against the same constants.
// Values match quickshell/src/services/pam/conversation.hpp:24-30.
Singleton {
    enum Result {
        Success = 0,
        Failed = 1,
        Error = 2
    }
}
