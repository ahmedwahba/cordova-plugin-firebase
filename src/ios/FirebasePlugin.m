#import "FirebasePlugin.h"
#import <Cordova/CDV.h>
#import "AppDelegate.h"
#import "Firebase.h"
@import FirebaseInstanceID;
@import FirebaseMessaging;
@import FirebaseAnalytics;
@import FirebaseRemoteConfig;
@import FirebaseAuth;

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@import UserNotifications;
#endif

#ifndef NSFoundationVersionNumber_iOS_9_x_Max
#define NSFoundationVersionNumber_iOS_9_x_Max 1299
#endif

@implementation FirebasePlugin

@synthesize notificationCallbackId;
@synthesize tokenRefreshCallbackId;
@synthesize notificationStack;

static NSInteger const kNotificationStackSize = 10;
static FirebasePlugin *firebasePlugin;

+ (FirebasePlugin *) firebasePlugin {
    return firebasePlugin;
}

- (void)pluginInitialize {
    NSLog(@"Starting Firebase plugin");
    firebasePlugin = self;
}

// DEPRECATED - alias of getToken
- (void)getInstanceId:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult;

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:
                    [[FIRInstanceID instanceID] token]];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getToken:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult;

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:
                    [[FIRInstanceID instanceID] token]];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}
- (void)hasPermission:(CDVInvokedUrlCommand *)command
{
    BOOL enabled = NO;
    UIApplication *application = [UIApplication sharedApplication];
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        enabled = application.currentUserNotificationSettings.types != UIUserNotificationTypeNone;
    } else {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        enabled = application.enabledRemoteNotificationTypes != UIRemoteNotificationTypeNone;
#pragma GCC diagnostic pop
    }

    NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:1];
    [message setObject:[NSNumber numberWithBool:enabled] forKey:@"isEnabled"];
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
    [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
}
- (void)grantPermission:(CDVInvokedUrlCommand *)command {
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_9_x_Max) {
        if ([[UIApplication sharedApplication]respondsToSelector:@selector(registerUserNotificationSettings:)]) {
            UIUserNotificationType notificationTypes =
            (UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge);
            UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:notificationTypes categories:nil];
            [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
            [[UIApplication sharedApplication] registerForRemoteNotifications];
        } else {
            #pragma GCC diagnostic push
            #pragma GCC diagnostic ignored "-Wdeprecated-declarations"
            [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound)];
            #pragma GCC diagnostic pop
        }
    } else {
        #if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
        // IOS 10
        UNAuthorizationOptions authOptions =
          UNAuthorizationOptionAlert
          | UNAuthorizationOptionSound
          | UNAuthorizationOptionBadge;
        [[UNUserNotificationCenter currentNotificationCenter]
          requestAuthorizationWithOptions:authOptions
          completionHandler:^(BOOL granted, NSError * _Nullable error) {
          }
        ];
        [[UNUserNotificationCenter currentNotificationCenter] setDelegate:self];
        [[FIRMessaging messaging] setRemoteMessageDelegate:self];
        #endif

        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setBadgeNumber:(CDVInvokedUrlCommand *)command {
    int number = [[command.arguments objectAtIndex:0] intValue];

    [self.commandDelegate runInBackground:^{
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:number];

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}


- (void)getVerificationID:(CDVInvokedUrlCommand *)command {
    NSString* number = [command.arguments objectAtIndex:0];

    [[FIRPhoneAuthProvider provider]
    verifyPhoneNumber:number
           completion:^(NSString *_Nullable verificationID,
                        NSError *_Nullable error) {
NSDictionary *message;
  if (error) {

    // Verification code not sent.
    message = @{
                @"code": [NSNumber numberWithInteger:error.code],
                @"description": error.description == nil ? [NSNull null] : error.description
                };

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:message];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

  } else {
    // Successful.
CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:verificationID];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }
}];



}



- (void)verifyPhoneNumberWithCode:(CDVInvokedUrlCommand *)command {
    NSString* verificationId = [command.arguments objectAtIndex:0];
    NSString* code = [command.arguments objectAtIndex:1];

    FIRAuthCredential *credential = [[FIRPhoneAuthProvider provider]
                                     credentialWithVerificationID:verificationId
                                     verificationCode:code];

    [self signInWithPhoneAuthCredential:credential command:command];


}


-(void) signInWithPhoneAuthCredential:(FIRAuthCredential *) credential command:(CDVInvokedUrlCommand *)command{
    [[FIRAuth auth] signInWithCredential:credential
                              completion:^(FIRUser *user, NSError *error) {
                              __block NSDictionary *message = nil;
                              __block NSDictionary *successResult = nil;
                                  if (error) {
                                      message = @{
                                                @"code": [NSNumber numberWithInteger:error.code],
                                                @"description": error.description == nil ? [NSNull null] : error.description
                                            };

                                      CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:message];

                                      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                                  }
                                  else
                                  {
                                    [user getTokenForcingRefresh:YES
                                        completion:^(NSString *_Nullable idToken,
                                         NSError *_Nullable error) {
                                          if (error) {
                                                    message = @{
                                                    @"code": [NSNumber numberWithInteger:error.code],
                                                    @"description": error.description == nil ? [NSNull null] : error.description
                                                  };

                                                  CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:message];

                                                  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                                                  return;
                                           } else {

                                                    // Send token to your backend via HTTPS
                                                successResult = @{
                                                    @"success": @YES,
                                                    @"credential": idToken
                                                };
                                                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:successResult];
                                                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                                          }

                                             // User successfully signed in. Get user data from the FIRUser object
                                              // ...

                                         }];
                                  }
                                  
                              
    }];
}



- (void)getBadgeNumber:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        long badge = [[UIApplication sharedApplication] applicationIconBadgeNumber];

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:badge];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)subscribe:(CDVInvokedUrlCommand *)command {
    NSString* topic = [NSString stringWithFormat:@"/topics/%@", [command.arguments objectAtIndex:0]];

    [[FIRMessaging messaging] subscribeToTopic: topic];

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)unsubscribe:(CDVInvokedUrlCommand *)command {
    NSString* topic = [NSString stringWithFormat:@"/topics/%@", [command.arguments objectAtIndex:0]];

    [[FIRMessaging messaging] unsubscribeFromTopic: topic];

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)onNotificationOpen:(CDVInvokedUrlCommand *)command {
    self.notificationCallbackId = command.callbackId;

    if (self.notificationStack != nil && [self.notificationStack count]) {
        for (NSDictionary *userInfo in self.notificationStack) {
            [self sendNotification:userInfo];
        }
        [self.notificationStack removeAllObjects];
    }
}

- (void)onTokenRefresh:(CDVInvokedUrlCommand *)command {
    self.tokenRefreshCallbackId = command.callbackId;
    NSString* currentToken = [[FIRInstanceID instanceID] token];
    if (currentToken != nil) {
        [self sendToken:currentToken];
    }
}

- (void)sendNotification:(NSDictionary *)userInfo {
    if (self.notificationCallbackId != nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:userInfo];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.notificationCallbackId];
    } else {
        if (!self.notificationStack) {
            self.notificationStack = [[NSMutableArray alloc] init];
        }

        // stack notifications until a callback has been registered
        [self.notificationStack addObject:userInfo];

        if ([self.notificationStack count] >= kNotificationStackSize) {
            [self.notificationStack removeLastObject];
        }
    }
}

- (void)sendToken:(NSString *)token {
    if (self.tokenRefreshCallbackId != nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:token];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.tokenRefreshCallbackId];
    }
}

- (void)logEvent:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString* name = [command.arguments objectAtIndex:0];
        NSDictionary* parameters = [command.arguments objectAtIndex:1];

        [FIRAnalytics logEventWithName:name parameters:parameters];

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)setScreenName:(CDVInvokedUrlCommand *)command {
    NSString* name = [command.arguments objectAtIndex:0];

    [FIRAnalytics setScreenName:name screenClass:NULL];

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setUserId:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString* id = [command.arguments objectAtIndex:0];

        [FIRAnalytics setUserID:id];

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)setUserProperty:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString* name = [command.arguments objectAtIndex:0];
        NSString* value = [command.arguments objectAtIndex:1];

        [FIRAnalytics setUserPropertyString:value forName:name];

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)fetch:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        FIRRemoteConfig* remoteConfig = [FIRRemoteConfig remoteConfig];

        if ([command.arguments count] > 0){
            int expirationDuration = [[command.arguments objectAtIndex:0] intValue];

            [remoteConfig fetchWithExpirationDuration:expirationDuration completionHandler:^(FIRRemoteConfigFetchStatus status, NSError * _Nullable error) {
                if (status == FIRRemoteConfigFetchStatusSuccess) {
                    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                }
            }];
        } else {
            [remoteConfig fetchWithCompletionHandler:^(FIRRemoteConfigFetchStatus status, NSError * _Nullable error) {
                if (status == FIRRemoteConfigFetchStatusSuccess) {
                    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                }
            }];
        }
    }];
}

- (void)activateFetched:(CDVInvokedUrlCommand *)command {
     [self.commandDelegate runInBackground:^{
        FIRRemoteConfig* remoteConfig = [FIRRemoteConfig remoteConfig];
         BOOL activated = [remoteConfig activateFetched];
         CDVPluginResult *pluginResult;
         if (activated) {
             pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
         } else {
             pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
         }

         [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
     }];
}

- (void)getValue:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString* key = [command.arguments objectAtIndex:0];
        FIRRemoteConfig* remoteConfig = [FIRRemoteConfig remoteConfig];
        NSString* value = remoteConfig[key].stringValue;
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:value];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

@end
