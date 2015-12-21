//
//  SKYSendPushNotificationOperation.m
//  SKYKit
//
//  Copyright 2015 Oursky Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "SKYSendPushNotificationOperation.h"
#import "SKYOperationSubclass.h"
#import "SKYRequest.h"
#import "SKYRecordSerialization.h"
#import "SKYDataSerialization.h"
#import "SKYError.h"
#import "SKYResultArrayResponse.h"
#import "SKYNotificationInfo.h"
#import "SKYNotificationInfoSerializer.h"

@implementation SKYSendPushNotificationOperation

- (instancetype)initWithNotificationInfo:(SKYNotificationInfo *)notificationInfo
                              pushTarget:(SKYPushTarget)pushTarget
                               IDsToSend:(NSArray *)IDsToSend
{
    self = [super init];
    if (self) {
        _notificationInfo = [notificationInfo copy];
        _IDsToSend = [IDsToSend copy];
        _pushTarget = pushTarget;

        [_IDsToSend enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if (![obj isKindOfClass:[NSString class]]) {
                NSString *reason = [NSString stringWithFormat:@"User ID must be NSString. Got %@",
                                                              NSStringFromClass([obj class])];
                @throw [NSException exceptionWithName:NSInvalidArgumentException
                                               reason:reason
                                             userInfo:nil];
            }
        }];
    }
    return self;
}

+ (instancetype)operationWithNotificationInfo:(SKYNotificationInfo *)noteInfo
                                userIDsToSend:(NSArray *)userIDsToSend
{
    return [[self alloc] initWithNotificationInfo:noteInfo
                                       pushTarget:SKYPushTargetIsUser
                                        IDsToSend:userIDsToSend];
}

+ (instancetype)operationWithNotificationInfo:(SKYNotificationInfo *)noteInfo
                              deviceIDsToSend:(NSArray *)deviceIDsToSend
{
    return [[self alloc] initWithNotificationInfo:noteInfo
                                       pushTarget:SKYPushTargetIsDevice
                                        IDsToSend:deviceIDsToSend];
}

+ (Class)responseClass
{
    return [SKYResultArrayResponse class];
}

- (void)prepareForRequest
{
    NSString *action;
    NSMutableDictionary *payload;

    SKYNotificationInfoSerializer *serializer = [SKYNotificationInfoSerializer serializer];
    NSDictionary *serializedNotification =
        [serializer dictionaryWithNotificationInfo:self.notificationInfo];

    switch (self.pushTarget) {
        case SKYPushTargetIsUser:
            action = @"push:user";
            payload = [@{
                @"user_ids" : self.IDsToSend,
                @"notification" : serializedNotification,
            } mutableCopy];
            break;
        case SKYPushTargetIsDevice:
            action = @"push:device";
            payload = [@{
                @"device_ids" : self.IDsToSend,
                @"notification" : serializedNotification,
            } mutableCopy];
            break;
        default: {
            NSString *reason =
                [NSString stringWithFormat:@"unexpected push target %d", (int)self.pushTarget];
            @throw [NSException exceptionWithName:NSInvalidArgumentException
                                           reason:reason
                                         userInfo:nil];
        }
    }
    self.request = [[SKYRequest alloc] initWithAction:action payload:payload];
    self.request.APIKey = self.container.APIKey;
}

- (void)handleRequestError:(NSError *)error
{
    if (self.sendCompletionHandler) {
        self.sendCompletionHandler(nil, error);
    }
}

- (void)handleResponse:(SKYResultArrayResponse *)response
{
    NSMutableArray *successIDs = nil;
    NSError *error = nil;
    if (response.error) {
        error = response.error;
    } else {
        successIDs = [NSMutableArray array];
        NSMutableDictionary *errorsByID = [NSMutableDictionary dictionary];
        [response enumerateResultsUsingBlock:^(NSString *resultKey, NSDictionary *result,
                                               NSError *error, NSUInteger idx, BOOL *stop) {

            if (error && resultKey) {
                errorsByID[resultKey] = error;
            } else {
                [successIDs addObject:resultKey];
            }
            if (self.perSendCompletionHandler) {
                self.perSendCompletionHandler(resultKey, error);
            }
        }];

        if ([errorsByID count] > 0) {
            error = [self.errorCreator partialErrorWithPerItemDictionary:errorsByID];
        }
    }

    if (self.sendCompletionHandler) {
        self.sendCompletionHandler(successIDs, error);
    }
}

@end
