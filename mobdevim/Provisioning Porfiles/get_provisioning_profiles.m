//
//  get_provisioning_profiles.m
//  mobdevim
//
//  Created by Derek Selander
//  Copyright © 2017 Selander. All rights reserved.
//

@import Security;
#import "get_provisioning_profiles.h"

NSString * const kProvisioningProfilesCopyDeveloperCertificates =  @"com.selander.provisioningprofiles.copydevelopercertificates";

NSString * const kProvisioningProfilesFilteredByDevice =  @"com.selander.provisioningprofiles.filteredbydevice";

int get_provisioning_profiles(AMDeviceRef d, NSDictionary *options) {
  
  NSString *deviceIdentifier = AMDeviceGetName(d);
  NSArray *profiles = AMDeviceCopyProvisioningProfiles(d);
  
  BOOL copyDeveloperCertificates = [[options objectForKey:kProvisioningProfilesCopyDeveloperCertificates] boolValue];
  
  NSString* filterProvisioninProfilesThatOnlyFitDevice = [options objectForKey:kProvisioningProfilesFilteredByDevice];
  
  
  
  NSArray *filteredProfiles = [profiles filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
    
    if (filterProvisioninProfilesThatOnlyFitDevice) {
      return [[MISProfileCopyPayload(evaluatedObject) objectForKey:@"UUID"] containsString:filterProvisioninProfilesThatOnlyFitDevice];
    }
    
    return (BOOL)[MISProfileCopyPayload(evaluatedObject) objectForKey:@"Name"];
  }]];
  
  dsprintf(stdout, "Dumping provisioning profiles\n\n");
  
  
  NSString *appName = AMDeviceCopyDeviceIdentifier(d);
  
  NSString *directory = [NSString stringWithFormat:@"/tmp/%@_certificates", appName];
  
  for (id i in filteredProfiles) {
    NSDictionary *dict = MISProfileCopyPayload(i);
    NSString *teamName = dict[@"TeamName"];
    NSString *appIDName = dict[@"AppIDName"];
    NSString *appID = dict[@"Entitlements"][@"application-identifier"];
    NSString *apsEnv = dict[@"Entitlements"][@"aps-environment"];
    NSString *uuid = dict[@"UUID"];
    NSString *name = dict[@"Name"];
    NSArray *certs = dict[@"DeveloperCertificates"];
      NSMutableArray *certificateNames = [NSMutableArray new];
      for (int i = 0; i < [certs count]; i++) {
          NSData *data = certs[i];
          CFDataRef dataRef = CFDataCreate(NULL, [data bytes], [data length]);
          SecCertificateRef secref = SecCertificateCreateWithData(nil, dataRef);
          
          
          // Common name
          CFStringRef commonNameRef = NULL;
          SecCertificateCopyCommonName(secref, &commonNameRef);
          NSString *commonName = CFBridgingRelease(commonNameRef);
          
//          NSString* objectSummary = CFBridgingRelease(SecCertificateCopySubjectSummary(secref));
          
          CFArrayRef keysRef = NULL;
          NSDictionary* certDict =  CFBridgingRelease(SecCertificateCopyValues(secref, keysRef, nil));
          
          NSNumber *validBefore = nil;
          NSNumber *validAfter = nil;
          NSString *serialValue = nil;
          for (NSDictionary *key in certDict) {
               if ([certDict[key][@"label"] isEqualToString:@"Serial Number"]) {
                   serialValue = certDict[key][@"value"];
                   continue;
               } else if ([certDict[key][@"label"] isEqualToString:@"Not Valid Before"]) {
                  validBefore = certDict[key][@"value"];
                  continue;
              } else if ([certDict[key][@"label"] isEqualToString:@"Not Valid After"]) {
                  validAfter = certDict[key][@"value"];
                  continue;
              }
          }
          
          [certificateNames addObject:@{@"Common Name"  : commonName,
                                        @"Serial Number": serialValue ? serialValue : @"NULL",
                                        @"Valid Before" : (validBefore ? [NSDate dateWithTimeIntervalSinceReferenceDate:[validBefore doubleValue]] : @"NULL"),
                                        @"Valid After"  : (validAfter ? [NSDate dateWithTimeIntervalSinceReferenceDate:[validAfter doubleValue]] : @"NULL"),
                                        }];

      }

    if (filterProvisioninProfilesThatOnlyFitDevice) {
      NSArray *provisionedDevices = dict[@"ProvisionedDevices"];
      if(![provisionedDevices containsObject:deviceIdentifier]) {
        continue;
      }
    }
    
    if (copyDeveloperCertificates) {
      NSFileManager *fileManager= [NSFileManager defaultManager];
      
      if(![fileManager fileExistsAtPath:directory isDirectory:NULL]) {
        [fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
      }
      for (NSData *data in dict[@"DeveloperCertificates"]) {
        NSString *certPath = [NSString stringWithFormat:@"%@/%@_%@.cer", directory, appID, uuid];
        [data writeToFile:certPath atomically:YES];
      }
      continue;
    }
    
    
    NSMutableString *outputString = [NSMutableString stringWithFormat:@"\n%s**************************************%s\nApplication-identifier: %s%@%s\nTeamName: %s%@%s\nAppIDName: %s%@%s\nProvisioning Profile: %s%@%s\nAps-Environment: %s%@%s\nUUID: %s%@%s",
                                     dcolor("yellow"), colorEnd(),
                                     dcolor("bold"), appID, colorEnd(),
                                     dcolor("bold"), teamName, colorEnd(),
                                     dcolor("bold"), appIDName, colorEnd(),
                                     dcolor("bold"), name, colorEnd(),
                                     dcolor("bold"), apsEnv ? apsEnv : @"[NONE]", colorEnd(),
                                     dcolor("bold"), uuid, colorEnd()];
    if (filterProvisioninProfilesThatOnlyFitDevice) {
        NSMutableDictionary *outputDict = [NSMutableDictionary dictionaryWithDictionary:dict];
        [outputDict removeObjectForKey:@"DeveloperCertificates"];
        [outputDict setObject:certificateNames forKey:@"DeveloperCertificates"];
      dsprintf(stdout, "Dumping Provisioning Profile info for UDID \"%s%s%s\"...\n%s\n", dcolor("cyan"), [filterProvisioninProfilesThatOnlyFitDevice UTF8String], colorEnd(), [[outputDict debugDescription] UTF8String]);
    } else {
      dsprintf(stdout, "%s\n", [outputString UTF8String]);
    }
  }
  
  
  if (copyDeveloperCertificates) {
    dsprintf(stdout, "Opening directory containing dev certificates from device...\n");
    [[NSWorkspace sharedWorkspace] openFile:directory];
  }
  
  return 0;
}
