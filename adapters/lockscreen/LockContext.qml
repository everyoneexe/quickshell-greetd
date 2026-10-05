// Substitute for a lockscreen's own LockContext.
//
// Most Quickshell lockscreens declare `required property LockContext context`
// - a *typed* property. A greeter cannot satisfy that with a foreign type:
//
//     Cannot assign QObject* to LockContext_QMLTYPE_434*
//
// So qsgreet-theme-prepare installs this file over the shell's own context
// file, keeping the original as <name>.qml.qsgreet-orig. The file name is
// the type name, so the surface's typed property is satisfied and
// `LockContext.ActionEnum.Poweroff` keeps resolving.
//
// Substituting exactly this one file is deliberate: it is the PAM boundary,
// the single place a lockscreen does something a greeter cannot. Everything
// else in the tree is untouched.

import QsGreet

GreeterLockContext {
    // Must match GreeterLockContext.ActionEnum, which the base class uses
    // internally; the surfaces reference these through the file name.
    enum ActionEnum {
        Unlock = 0,
        Poweroff = 1,
        Reboot = 2
    }
}
