/*
 * Copyright 2010 Facebook
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "AppDelegate.h"

#import "ViewController.h"

// Your Facebook APP Id must be set before running this example
// See http://developers.facebook.com/apps
// Also, your application must bind to the fb[app_id]:// URL
// scheme (substitue [app_id] for your real Facebook app id).
static NSString *kAppId = @"374038142615411";

@implementation AppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;
@synthesize facebook;

- (void)dealloc
{
    [facebook release];
    [_window release];
    [_viewController release];
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    // Override point for customization after application launch.
    self.viewController = [[[ViewController alloc] initWithNibName:@"ViewController" bundle:nil] autorelease];
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    
    // Initialize Facebook
    facebook = [[Facebook alloc] initWithAppId:kAppId andDelegate:self];
    
    // Check and retrieve authorization information
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:@"FBAccessTokenKey"] 
        && [defaults objectForKey:@"FBExpirationDateKey"]) {
        facebook.accessToken = [defaults objectForKey:@"FBAccessTokenKey"];
        facebook.expirationDate = [defaults objectForKey:@"FBExpirationDateKey"];
    }
    
    // After retrieving any authorization data, make an additional
    // check to see if it is still valid.
    if ([facebook isSessionValid]) {
        // Show logged in state
        [self fbDidLogin];
    } else {
        // Show logged out state
        [self fbDidLogout];
    }
    
    return YES;
}

#pragma mark - Helper Functions
/**
 * A helper function for parsing URL parameters.
 */
- (NSDictionary*)parseURLParams:(NSString *)query {
	NSArray *pairs = [query componentsSeparatedByString:@"&"];
	NSMutableDictionary *params = [[[NSMutableDictionary alloc] init] autorelease];
	for (NSString *pair in pairs) {
		NSArray *kv = [pair componentsSeparatedByString:@"="];
		NSString *val =
        [[kv objectAtIndex:1]
         stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
		[params setObject:val forKey:[kv objectAtIndex:0]];
	}
    return params;
}

// Deep Link Check
- (void) checkDeepLink: (NSURL *) url {
    // To check for a deep link, first parse the incoming URL
    // to look for a target_url parameter
    NSString *query = [url fragment];
    NSDictionary *params = [self parseURLParams:query];
    // Check if target URL exists
    NSString *targetURLString = [params valueForKey:@"target_url"];
    if (targetURLString) {
        UIAlertView *alert = [[UIAlertView alloc] 
                              initWithTitle:@"Deep Link!" 
                              message:[NSString stringWithFormat:@"Incoming: %@", targetURLString]
                              delegate:nil 
                              cancelButtonTitle:@"OK" 
                              otherButtonTitles:nil, 
                              nil];
        [alert show];
        [alert release];
    }
}

#pragma mark - Incoming URL Handlers
// Add for Facebook SSO support (pre 4.2)
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    [self checkDeepLink:url];
    return [facebook handleOpenURL:url]; 
}

// Add for Facebook SSO support (4.2+)
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    [self checkDeepLink:url];
    return [facebook handleOpenURL:url]; 
}

#pragma mark - Facebook User Authorization
/*
 * This method calls the Facebook API to authorize the user
 */
- (void) login {
    [facebook authorize:nil];
}

/*
 * This method calls the Facebook to log out the user
 */
- (void) logout {
    [facebook logout];
}

#pragma mark - Facebook Graph API 
/*
 * Graph API: Get the user's basic information, picking the name field.
 */
- (void)apiGraphMe {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   @"name",  @"fields",
                                   nil];
    [facebook requestWithGraphPath:@"me" 
                         andParams:params 
                       andDelegate:self];
}

#pragma mark - FBRequestDelegate Methods
/**
 * Called when a request returns and its response has been parsed into
 * an object. The resulting object may be a dictionary, an array, a string,
 * or a number, depending on the format of the API response. If you need access
 * to the raw response, use:
 *
 * (void)request:(FBRequest *)request
 *      didReceiveResponse:(NSURLResponse *)response
 */
- (void)request:(FBRequest *)request didLoad:(id)result {
    if ([result isKindOfClass:[NSArray class]] && ([result count] > 0)) {
        result = [result objectAtIndex:0];
    }
    if ([result objectForKey:@"name"]) {
        // Personal information API return callback
        self.viewController.welcomeLabel.text = 
          [NSString stringWithFormat:@"Welcome %@", [result objectForKey:@"name"]];
    }
}

#pragma mark - Facebook Dialogs
/*
 * Dialog: Feed for the user
 */
- (void) post {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   @"I'm using the Mobile Hack iOS app", @"name",
                                   @"Mobile Hack for iOS.", @"caption",
                                   @"Check out Mobile Hack for iOS to learn how you can make your iOS apps social using Facebook Platform.", @"description",
                                   @"http://www.tunedon.com/texto", @"link",
                                   nil];
    
    
    [facebook dialog:@"feed" andParams:params andDelegate:self];
}


#pragma mark - FBSessionDelegate Methods
/**
 * Called when the user has logged in successfully.
 */
- (void)fbDidLogin {
    self.viewController.welcomeLabel.text = @"Welcome ...";
    [self.viewController.authButton 
     setImage:[UIImage imageNamed:@"FBConnect.bundle/images/LogoutNormal.png"] 
     forState:UIControlStateNormal];

    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[facebook accessToken] forKey:@"FBAccessTokenKey"];
    [defaults setObject:[facebook expirationDate] forKey:@"FBExpirationDateKey"];
    [defaults synchronize];
    
    // Personalize
    [self apiGraphMe];
    
    // Show the post button
    [self.viewController.postButton setHidden:NO];
    
}

/**
 * Called when the request logout has succeeded.
 */
- (void)fbDidLogout {
    self.viewController.welcomeLabel.text = @"Login to Continue";
    [self.viewController.authButton 
     setImage:[UIImage imageNamed:@"FBConnect.bundle/images/LoginWithFacebookNormal.png"] 
     forState:UIControlStateNormal];

    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"FBAccessTokenKey"];
    [defaults removeObjectForKey:@"FBExpirationDateKey"];
    [defaults synchronize];
    
    // Hide the post button
    [self.viewController.postButton setHidden:YES];
}

/**
 * Called when the user canceled the authorization dialog.
 */
- (void)fbDidNotLogin:(BOOL)cancelled {
}

/**
 * Called when the access token has been extended
 */
- (void)fbDidExtendToken:(NSString*)accessToken
               expiresAt:(NSDate*)expiresAt {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:accessToken forKey:@"FBAccessTokenKey"];
    [defaults setObject:expiresAt forKey:@"FBExpirationDateKey"];
    [defaults synchronize];
}

/**
 * Called when the session is found to be invalid during an API call
 */
- (void)fbSessionInvalidated {
    UIAlertView *alertView = [[UIAlertView alloc]
                              initWithTitle:@"Auth Exception"
                              message:@"Your session has expired."
                              delegate:nil
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil,
                              nil];
    [alertView show];
    [alertView release];
    [self fbDidLogout];
}

#pragma mark - FBDialogDelegate Methods

/**
 * Called when a UIServer Dialog successfully return. Using this callback
 * instead of dialogDidComplete: to properly handle successful shares/sends
 * that return ID data back.
 */
- (void)dialogCompleteWithUrl:(NSURL *)url {
    if (![url query]) {
        NSLog(@"User canceled dialog or there was an error");
        return;
    }
    
    NSDictionary *params = [self parseURLParams:[url query]];
    if ([params valueForKey:@"post_id"]) {
        // Successful feed posts will return a post_id parameter
        NSLog(@"Feed post ID: %@", [params valueForKey:@"post_id"]);
    }
}

#pragma mark -
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    [facebook extendAccessTokenIfNeeded];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
