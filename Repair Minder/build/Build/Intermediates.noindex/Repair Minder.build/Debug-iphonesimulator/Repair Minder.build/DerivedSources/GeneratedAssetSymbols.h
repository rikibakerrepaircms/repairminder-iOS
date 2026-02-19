#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "login_background" asset catalog image resource.
static NSString * const ACImageNameLoginBackground AC_SWIFT_PRIVATE = @"login_background";

/// The "login_logo" asset catalog image resource.
static NSString * const ACImageNameLoginLogo AC_SWIFT_PRIVATE = @"login_logo";

/// The "repairminder_logo" asset catalog image resource.
static NSString * const ACImageNameRepairminderLogo AC_SWIFT_PRIVATE = @"repairminder_logo";

/// The "repairminder_logo_small" asset catalog image resource.
static NSString * const ACImageNameRepairminderLogoSmall AC_SWIFT_PRIVATE = @"repairminder_logo_small";

#undef AC_SWIFT_PRIVATE
